var moment = require('cloud/moment-timezone-with-data.js');


var WorkSession = Parse.Object.extend("WorkSession");
var Activity = Parse.Object.extend("Activity");

Parse.Cloud.define("testMoment", function(request, response) {
	var now = moment();
	now.locale('be')	
	console.log("weekday " + now.weekday())
	console.log("locale " + now.locale())
	console.log("now in America/Los_Angeles = " + now.tz('America/Los_Angeles').format());
	
	var user = request.user;
	var firstDate = user.get*
	
	response.success()
});

/*
 * newWorkSession
 * 
 * Save a new WorkSession.   In this approach, clients *NEVER* save WorkSession or Activity
 * objects to Parse, only saving local objects with provisional = true if the network is not available.  
 * They just call this function, and this function will create WorkSession
 * and/or Activity objects in Parse cloud as required.
 *
 * Required parameters:
 *   start (Date)
 *   duration (Number)	
 *   activityName (String)
 *
 */
Parse.Cloud.define("newWorkSession", function(request, response) {
	var workSession, activity,
	    user = request.user,
	    start = request.params.start,
	    duration = request.params.duration,
	    activityName = request.params.activityName;
	
	//console.log("request:\n" + JSON.stringify(request));
	
    if (!user) {
       response.error("Must be signed in to call newWorkSession.")
       return;
    }
	if (!start || get_type(start) != "[object Date]") {
		response.error("Parameter 'start' (type Date) missing");
		return;
	}
	if (!duration || typeof duration != "number") {
		response.error("Parameter 'duration' (type number) missing");
		return;
	}
	if (!activityName || typeof activityName != "string") {
		response.error("Parameter 'activityName' (type string) missing");
		return;
	}

    activityName = activityName.trim();

    // If there is already a WorkSession with the same start time, then don't create another one.
	var wsQuery = new Parse.Query(WorkSession);
	wsQuery.equalTo("start", start);
	wsQuery.equalTo("user", user);
	wsQuery.first().then(function(result) {
		if (result) {
			response.success("already exists");
			return;
		}
		
		workSession = new WorkSession();
		workSession.set("user", user);
		workSession.set("start", start);
		workSession.set("duration", duration);		
		workSession.set("provisional", false);
		
		// If there is already an Activity with name = activityName, then re-use that one
		// Otherwise create a new one
		var aQuery = new Parse.Query(Activity);
		aQuery.equalTo("name", activityName);
		aQuery.equalTo("user", user);
		return aQuery.first().then(function(result) {
			if (result) {
				activity = result;
				activity.increment("totalTime", duration);
				if (start > activity.get("last")) {
					activity.set("last", start);				
				} 
			}
			else {
				activity = new Activity();
				activity.set("name", activityName);
				activity.set("totalTime", duration);
				activity.set("user", user);
				activity.set("provisional", false);
				activity.set("last", start);				
			}
		    workSession.set("activity", activity);
			return workSession.save();
		}).then(function(result) {
			response.success("saved!");
		});
	}, function(error) {
		response.error(error);
	});
});


/*
 * fetchSummary
 * 
 * Fetch a summary by day/week/month of activites within a caller specified range.  response.more = false
 * if the end of all WorkSessions for the user was reached.
 *
 * Required parameters:
 *   start    	(Date)
 *   end		(Date)	
 *   timeZone   (String)
 *   unit       (String)   day/week/month
 *
 * Return:
 *   {
 *		summaries: [
 *        {
 *          time: "2015-10-21 00:00 +0000"
 *          activities: [
 *            { activityName: "Make food", duration: 600.0 }
 *            { activityName: "Paint the dog", duration: 300.0 }
 *          ]
 *        }
 *      ]
 *      more: false
 *   }
 *
 */

Parse.Cloud.define("fetchSummary", function(request, response) {
	var workSession, activity,
	    user = request.user,
	    start = request.params.start,
		end = request.params.duration,
		unit = request.parans.unit;
	
	console.log("request:\n" + JSON.stringify(request));
	
    if (!user) {
       response.error("Must be signed in to call fetchSummary.")
       return;
    }
	if (!start || get_type(start) != "[object Date]") {
		response.error("Parameter 'start' (type Date) missing");
		return;
	}
	if (!end || get_type(end) != "[object Date]") {
		response.error("Parameter 'end' (type Date) missing");
		return;
	}
	if (!timeZone || typeof timeZone != "string") {
		response.error("Parameter 'timeZone' (type string) missing");
		return;
	}
	if (!unit || typeof unit != "string"
	        || (unit != "day" && unit != "week" && unit != "month" ) ) {
		response.error("Parameter 'unit' (type string) missing or invalid");
		return;
	}
    
	// Just get ALL of the 
	var queryAllPromise = new Parse.Promise()
	
	var wsQuery = new Parse.Query(WorkSession);
	wsQuery.include(actitity)


});

function getAllWorkSessions() {
	var queryAllPromise = new Parse.Promise()
	
	var wsQuery = new Parse.Query(WorkSession);
	wsQuery.include("actitity");
	wsQuery.limit(1000);
	queryAllPromise = wsQuery.find().then(function(workSessions) {
		queryAllPromise.resolve(workSessions);
	}, function(error) {
		queryAllPromise.reject(error);
	});
	
	return queryAllPromise;	
}

/*
 * Utility functions
 */


/*
    Get WorkSessions for user with startDate <= WS.start < endDate

	return value = [WorkSession] with Activities loaded

 */
function getWorkSessions(user, startDate, endDate) {
	
}

function get_type(thing){
    if(thing===null)return "[object Null]"; // special case
    return Object.prototype.toString.call(thing);
}

