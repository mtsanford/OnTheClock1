
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
	var onOrBeforeDate = moment.utc('2015-11-09 07:00:00').toDate();
	var locale = 'fr';
	var timeZone = 'Europe/Paris';
	summarizeWorkSessions(user, unit, 2, onOrBeforeDate, locale, timeZone).then(
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
	howMany			how many units to summarize
	firstUnitDate	Date object.   *Most recent* unit. 
	locale			String (locale code.  Used for determining first day of week - e.g. Sun or Mon)
	timeZone		String

	NOTE: The first unit of the returned results will be the unit that firstUnitDate falls in.  So
 	if the unit is 'month', and firstUnitDate is 2015-03-15T13:45:00, then the first unit will be
    2015-03-01 through 2015-03-31, with the index of 2015-03-01T00:00:00 in the timeZone provided.

*/
function summarizeWorkSessions(user, unit, howMany, firstUnitDate, locale, timeZone) {
	var m, b, firstUnitMoment, afterDate, activityName, duration, i, 
	    // moment.js uses different unit strings for startOf() and add()... frigin' genius!
	    momentAddUnits = { 'day' : 'days', 'week' : 'weeks', 'month' : 'months' },
	    promise = new Parse.Promise(),
	    buckets = {},
	    result = [];

	if (momentAddUnits[unit] == undefined) {
		return Parse.Promise.error("bad unit");
	}
	
	firstUnitMoment = moment(firstUnitDate).tz(timeZone).locale(locale).startOf(unit);
	
	// Create buckets { '32423523523' : { 'activityname1' : 360.00, ... }, ... }
	m = firstUnitMoment.clone();
	for (i=0; i<howMany; i++) {
		buckets[m.valueOf()] = {}		
		m.subtract(1, momentAddUnits[unit]);
	}
	
	// Need to add one unit, since firstUnitMoment is the START of the unit 
	var maxMoment = firstUnitMoment.clone().add(1, momentAddUnits[unit]);
	var minMoment = maxMoment.clone().subtract(howMany, momentAddUnits[unit]);
	fetchWorkSessions(user, minMoment.toDate(), maxMoment.toDate()).then(
		function(workSessions) {
			for (i=0; i<workSessions.length; i++) {
				b = moment(workSessions[i].get('start')).tz(timeZone).locale(locale).startOf(unit).valueOf().toString();
				activityName = workSessions[i].get('activity').get('name');
				duration = workSessions[i].get('duration');
				if (buckets[b] == undefined) { var s = "BAD bucket: " + b; log(s); promise.reject(s); }
				else {
					if (buckets[b][activityName] == undefined) {
						buckets[b][activityName] = duration;
					}
					else {
						buckets[b][activityName] += duration;
					}
				}
			}
			promise.resolve(buckets);
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