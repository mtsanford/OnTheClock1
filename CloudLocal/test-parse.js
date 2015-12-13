
$(function() {

Parse.initialize("Mj76sGeuIdpclaGit0TEgWzqwMhHPJyjBFXRF7ml", "wCcNvtvZoPeCnWxdqpcj0SgWgJj6jxiJhwHlioe4");

var WorkSession = Parse.Object.extend("WorkSession");
var Activity = Parse.Object.extend("Activity");
  
if (!Parse.User.current()) {
	Parse.User.logIn("testset@marksanford.me", "mark", {
		success: function(user) {
			log(user.get("username") + " logged in");
			runTests();
		},
		error: function(user, error) {
			log("error logging in... " + error.message)
		}
	});
}
else {
	log(Parse.User.current().get("username") + " already logged in");
	runTests();  	
}
  
function runTests() {
	var user = Parse.User.current();
	var unit = 'week';
	var onOrBeforeDate = moment.utc('2015-12-01 08:00:00').toDate();
	var locale = 'en';
	//var timeZone = 'Europe/Paris';
	var timeZone = 'America/Los_Angeles';
	// America/New_York
	summarizeWorkSessions(user, unit, 50, onOrBeforeDate, locale, timeZone).then(
		function(result) {
			log('ok');
			console.log(result);
		},
		function(error) {
			log('huh?');
			log(error.message);
		}
	);
}
  
$("#test-moment").click(function() {
	var query = new Parse.Cloud.run("testMoment", {}, {}).then(
		function(result) {
			log(result);
		},
		function(error) {
			log(error.message);
		}
	);
});

 
/*
	user			PFUser object
	unit			'day', 'week', or 'month'
	howMany			how many units to summarize, not including empty units.   May
					may be less if data is exhausted, or more if queries fetched extra data.
	firstUnitDate	Date object.   *Most recent* unit. 
	locale			String (locale code.  Used for determining first day of week - e.g. Sun or Mon)
	timeZone		String

	NOTE: The first unit of the returned results will be the unit that firstUnitDate falls in.  So
 	if the unit is 'month', and firstUnitDate is 2015-03-15T13:45:00, then the first unit will be
    2015-03-01 through 2015-03-31, with the index of 2015-03-01T00:00:00 in the timeZone provided.

	result will be an array of howMany *nonempty* summaries of unit size sorted in descending order of unit start date.
    Summaries will include the unit start date, and a list of activity duration totals, sorted in descending
	ordr of duration.

	sample result: [
		{
			unitStart: Date('2015-12-03')
			activities: [ { name: 'make soup', duration: 7200 }, { name: 'paint carpet', duration: 3600}, ... ]
		},
		{
			unitStart: Date('2015-12-02')
			activities: [ { name: 'make soup', duration: 10400 }, { name: 'juggle', duration: 1800}, ... ]
		},
		...
	]

*/
function summarizeWorkSessions(user, unit, howMany, firstUnitDate, locale, timeZone) {
	var i, j,
	    maxTime, summary, bucket, sortedBucketKeys, sortedActivityKeys,
	    addUnit = { 'day' : 'days', 'week' : 'weeks', 'month' : 'months' }[unit],
	    itemsPerFetch = 100,
	    promise = new Parse.Promise(),
	    //firstTime = user.get('firstTime'),
	    buckets = {},
	    result = [];

	if (addUnit == undefined) { return Parse.Promise.error("bad unit: " + unit); }
	
    function fillMeSomeBuckets(maxTime) {
		var done = false,
			fillPromise = new Parse.Promise();
			wsQuery = new Parse.Query(WorkSession);

		wsQuery.equalTo("user", user);
		wsQuery.include("activity");
		wsQuery.limit(itemsPerFetch);
		wsQuery.lessThan("start", maxTime);
		wsQuery.addDescending("start");
  
  	  	console.log("fillMeSomeBuckets!  maxTime = " + maxTime);
  
		wsQuery.find().then(
			function(workSessions) {
			    var b, duration, activityName,
				    //earliest = workSessions[0].get('start'),
				    exhaustedData = workSessions.length < itemsPerFetch;
				    //TODO: I don't think first time is actually needed!
		            //exhaustedData = (!firstTime || earliest <= firstTime || workSessions.length < itemsPerFetch);
			
				console.log("fetched " + workSessions.length + " items");
				if (workSessions.length > 0) { console.log("latest = " + workSessions[0].get('start')); }
				if (workSessions.length > 0) { console.log("eariest = " + workSessions[workSessions.length-1].get('start')); }
			
				for (i=0; i<workSessions.length; i++) {
					b = moment(workSessions[i].get('start')).tz(timeZone).locale(locale).startOf(unit).valueOf().toString();
					activityName = workSessions[i].get('activity').get('name');
					duration = workSessions[i].get('duration');
				
					if (buckets[b] == undefined) { buckets[b] = {} }
					buckets[b][activityName] = buckets[b][activityName] || 0
					buckets[b][activityName] += duration;
				}
			
				sortedBucketKeys = Object.keys(buckets).sort(function(a,b) { return b-a; });
				console.log("" + sortedBucketKeys.length + " buckets so far");
				if (exhaustedData || sortedBucketKeys.length > howMany) {
					// we're done! But unless we've exhaused all the data, assume the last bucket is not complete!
					if (!exhaustedData) { delete buckets[sortedBucketKeys[sortedBucketKeys.length-1]]; }
					fillPromise.resolve();
					return;
				}
				
				fillMeSomeBuckets(workSessions[workSessions.length-1].get('start')).then(
					function() { fillPromise.resolve(); }, function() { fillPromise.reject(); }
				);
			},
			function(error) { fillPromise.reject(error); }
		);
		
		return fillPromise;
	}
	
	// Query maximum time is the start of the unit following the unit firstUnitDate is in
	maxTime = moment(firstUnitDate).tz(timeZone).locale(locale).startOf(unit).add(1, addUnit).toDate();
	
	fillMeSomeBuckets(maxTime).then(
		function() {
			// Now munge up all those hashs into sorted arrays for the final result
			sortedBucketKeys = Object.keys(buckets).sort(function(a,b) { return b-a; });
			console.log("buckets filled at end: " + sortedBucketKeys.length);
			for (i=0; i<sortedBucketKeys.length; i++) {
				bucket = buckets[sortedBucketKeys[i]];
				summary = { unitStart: moment(parseInt(sortedBucketKeys[i])).tz(timeZone).locale(locale).toDate(), activities: [] };
				sortedActivityKeys = Object.keys(bucket).sort(function(a,b) { return bucket[a] > bucket[b] ? -1 : 1 });
				for (j=0; j<sortedActivityKeys.length; j++) {
					summary.activities.push({ name: sortedActivityKeys[j], duration: bucket[sortedActivityKeys[j]] });
				}
				result.push(summary);
			}
			promise.resolve(result);
		},
		function(error) {
			promise.reject(error);		  	
		}			
	);
		
	return promise;
}
  
  /*
  	Fetch all WorkSessions that happened onOrAfterDate >= WS.start > beforeDate
    Also loads activities
  
  	returns Parse.Promise object
  
  */
  function fetchWorkSessions(user, onOrAfterDate, beforeDate) {
	  var itemsPerFetch = 500;
	  var promise = new Parse.Promise();
	  
	  var wsQuery = new Parse.Query(WorkSession);
	  wsQuery.equalTo("user", user);
	  wsQuery.include("activity");
	  wsQuery.limit(itemsPerFetch);
	  if (onOrAfterDate) wsQuery.greaterThanOrEqualTo("start", onOrAfterDate);
	  if (beforeDate) { wsQuery.lessThan("start", beforeDate); }
	  wsQuery.addAscending("start");
	  
	  wsQuery.find().then(
		  function(workSessions) {
			  // if the query got the maximum amount of items, then query again for more
			  if (workSessions.length == itemsPerFetch) {
				  var nextOnOrAfterDate = new Date(workSessions[itemsPerFetch-1].get("start").getTime() + 1);
				  return fetchWorkSessions(user, nextOnOrAfterDate, beforeDate).then(
					  function(tailWorkSessions) {
						  promise.resolve(workSessions.concat(tailWorkSessions));
					  }
				  )
			  }
			  else {
				  promise.resolve(workSessions);
			  }
		  },
		  function(error) {
			  promise.reject(error);
		  }
	  );
	  return promise;
  }
  
  function testFetchWorkSessions() {
	  var now = new Date();
	  var before = new Date('2015-05-31T23:59:59Z');
	  fetchWorkSessions(Parse.User.current(), before).then(
		  function(workSessions) {
		  	  log("fetched " + workSessions.length)
			  for (var i=0; i<workSessions.length; i++) {
				  var activityName = workSessions[i].get("activity").get('name');
				  log(activityName + " " + workSessions[i].get("start"));
			  }		  	
		  },
		  function(error) {
		  	log(error.message)
		  }
	  )
  }
  
  /*
  var delay = function(millis) {
    var promise = new Parse.Promise();
    setTimeout(function() {
      promise.resolve();
    }, millis);
    return promise;
  };
  
  function testPromise() {
	  var promise = new Parse.Promise();
      var thenPromise = promise.then(
		  function(result) {
			  log("success")
			  var delayPromise = delay(1000);
			  delayPromise.then(
				  function(success) { log("delay done"); }
			  );
			  return delayPromise;
		  },
		  function(error) {
			  log("error")
		  }
      );
	  thenPromise.then(
		  function() { log("thenPromise done :)"); }
	  )
	  promise.resolve("ok");
	  
	  var donePromise = new Parse.Promise.as("done").then( function(result) { log("donePromise done.." + result); });
	  
  }
  
  testPromise();
  */
  
  
  /*
  var TestObject = Parse.Object.extend("TestObject");
  var newValue = "Kale";
  $("#change-object").click(function() {
	  var query = new Parse.Query(TestObject);
	  query.get("5Q1aAPe37q", {
	    success: function(row) {
			log("previous value was " + row.get("foo"));
			row.set("foo", newValue);
			row.save(null, {
				success: function(row) {
					log("updated value to " + row.get("foo"));
				}
			});
	    },
	    error: function(object, error) {
	    }
	  });	  
  });
  */
  
  function log(message) {
	  var $line = $("<p>" + message + "</p>");
	  $("#log").append($line);
	  console.log(message);
  }
  
});