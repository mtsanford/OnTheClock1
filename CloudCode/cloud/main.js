
var WorkSession = Parse.Object.extend("WorkSession");
var Activity = Parse.Object.extend("Activity");

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
			}
			else {
				activity = new Activity();
				activity.set("name", activityName);
				activity.set("totalTime", duration);
				activity.set("user", user);
				activity.set("provisional", false);
			}
			activity.set("last", start);
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
 * Utility functions
 */

function get_type(thing){
    if(thing===null)return "[object Null]"; // special case
    return Object.prototype.toString.call(thing);
}

