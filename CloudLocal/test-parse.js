
$(function() {

  //Parse.initialize("7vGvRyqr3tABuCPnHFHSMu7PlhJKy6F2YF7aL2Wr", "I0w0p4lAZhzZNQdkFJic2qNQsl8xoipuACo89QIo");
  Parse.initialize("Mj76sGeuIdpclaGit0TEgWzqwMhHPJyjBFXRF7ml", "wCcNvtvZoPeCnWxdqpcj0SgWgJj6jxiJhwHlioe4");

  var WorkSession = Parse.Object.extend("WorkSession");
  var Activity = Parse.Object.extend("Activity");
  
  if (!Parse.User.current()) {
	  Parse.User.logIn("testset@marksanford.me", "mark", {
	    success: function(user) {
			log(user.get("username") + " logged in");
			testFetchWorkSessions();
		},
	    error: function(user, error) {
			log("error logging in... " + error.message)
	    }
	  });
  }
  else {
	log(Parse.User.current().get("username") + " already logged in");
	testFetchWorkSessions();  	
  }
  
  $("#test-moment").click(function() {
	  var query = new Parse.Cloud.run("testMoment", {}, {}).then(
		  function(result) {
			  log(result);
		  },
		  function(error) {
			  log(error);
		  }
	  );
  });
  
  /*
  	user			PFUser object
  	unit			'day', 'week', or 'month'
    onOrBeforeDate	Date object
  	afterDate		Date object
    locale			String (locale code used for determining first day of week - e.g. Sun or Mon)
    timeZone		String
  */
function summarizeWorkSessions(user, unit, onOrBeforeDate, afterDate, locale, timeZone) {
	var time, unitTimeString, activityName, duration, i, 
	    promise = new Parse.Promise(),
	    buckets = {},
	    result = [];

	if (moment(onOrBeforeDate).isBefore(moment(afterDate))) {
		return Parse.Promise.error("onOrBeforeDate is before afterDate");
	}
	
	
	fetchWorkSessions(user, onOrBeforeDate, afterDate).then(
		function(workSessions) {
			for (i=0; i<workSessions.length; i++) {
				time = moment(workSessions[i].get('start'));
				time.tz(timeZone);
				time.locale(locale);
				
				// Need to hash as string value of unitTime, since javascript
				// only allows string keys for hash dictionaries
				unitTimeString = unitTime.startOf(unit).valueOf().toString();
				activityName = workSessions[i].get('activity').get('name');
				duration = workSessions[i].get('duration');
				if (buckets[unitTimeString] == undefined) { buckets[unitTimeString] = {} };
				if (buckets[unitTimeString][activityName] == undefined) {
					buckets[unitTimeString][activityName] = duration;
				}
				else {
					buckets[unitTimeString][activityName] += duration;
				}
			}
		},
		function(error) {
			promise.reject(error);		  	
		}
	);
	
	return promise;
}
  
  /*
  	Fetch all WorkSessions that happened on or BEFORE onOrBeforeDate, but
    after afterDate.   i.e.  afterDate > WS.start <= onOrBeforeDate
    Also loads activities
  
    IMPORTANT: afterDate is BEFORE onOrBeforeDate
    afterDate is optional
  
  	returns Parse.Promise object
  
  */
  function fetchWorkSessions(user, onOrBeforeDate, afterDate) {
	  var itemsPerFetch = 500;
	  var promise = new Parse.Promise();
	  
	  var wsQuery = new Parse.Query(WorkSession);
	  wsQuery.equalTo("user", user);
	  wsQuery.include("activity");
	  wsQuery.limit(itemsPerFetch);
	  wsQuery.lessThanOrEqualTo("start", onOrBeforeDate);
	  if (afterDate) { wsQuery.greaterThan("start", afterDate); }
	  wsQuery.addDescending("start");
	  
	  wsQuery.find().then(
		  function(workSessions) {
			  // if the query got the maximum amount of items, then query again
			  // to see if there are more
			  if (workSessions.length == itemsPerFetch) {
				  var nextStartDate = new Date(workSessions[itemsPerFetch-1].get("start").getTime() - 1);
				  log("nextStartDate: " + nextStartDate);
				  return fetchWorkSessions(user, nextStartDate, afterDate).then(
					  function(tailWorkSessions) {
						  promise.resolve(workSessions.concat(tailWorkSessions));
					  }
				  )
			  }
			  else {
				  log("query fetched " + workSessions.length)
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