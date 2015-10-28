
// Use Parse.Cloud.define to define as many cloud functions as you want.
// For example:
Parse.Cloud.define("hello", function(request, response) {
  response.success("Hello world! Let's see if I can deploy new code with account key!");
});

var WorkSession = Parse.Object.extend("WorkSession");
var Activity = Parse.Object.extend("Activity");

// Save a new Work Session.   In this approach, clients *NEVER* save WorkSession or Activity
// objects to Parse.  They just call this function, and then fetch to make sure their data is 
// up to date.
//
// request.params : {
//   objectId : objectId of the work session
//   start (Date) :
//   duration (Float)	
//   activityName (String)	
// }
//     
Parse.Cloud.define("newWorkSession", function(request, response) {
	var workSession, activity, startDate,
	    user = request.user,
	    duration = request.params.duration,
	    activityName = request.params.activityName
		objectId = request.params.objectId;
	
    console.log("newWorkSession request:\n" + JSON.stringify(request) + "\n");  

    if (!user) {
       response.error("Must be signed in to call newWorkSession.")
       return;
     }

	// TODO: Need parse start string into Date() object
	startDate = new Date();
	 	
	var wsQuery = new Parse.Query(WorkSession);
	wsQuery.equalTo("objectId", objectId);
	wsQuery.equalTo("user", user);
	wsQuery.first().then(function(result) {
		// If the the WorkSession already exists, assume that the client just didn't
		// get the acknowledgement for some reason.  We're done.
		if (result) {
			workSession = result;
			response.success();
			return;
		}
		
		// otherwise, were going to the create the cloud version of the object, setting
		// the Activity pointer ourselves.
		workSession = WorkSession.createWithoutData(objectId);
		workSession.set("user", user);
		workSession.set("start", startDate);
		workSession.set("duration", duration);		
		
		var aQuery = new Parse.Query(Activity);
		aQuery.equalTo("name", activityName);
		aQuery.equalTo("user", user);
		return aQuery.first();
	}).then(function(result) {
		// If there is already an Activity with name = request.activityName, then use that one
		if (result) {
			activity = result;
			activity.increment("totalTime", duration);
		}
		// Otherwise create a new one
		else {
			activity = new Activity();
			activity.set("name", activityName);
			activity.set("totalTime", duration);
			activity.set("last", startDate);
			activity.set("user", user);
		}
		// TODO: Confirm that activity will also be saved, since workSession points to it 
	    workSession.set("activity", activity);
		return workSession.save();
	}).then(function(result) {
		response.success();
	}, function(error) {
		response.error(error);
	})
});

Parse.Cloud.beforeSave("WorkSession", function(request, response) {
  request.object.set("duration", 666);
  var activity = request.object.get("activity");
  console.log("request:\n" + JSON.stringify(request) + "\n");  
  //console.log("activity:\n" + JSON.stringify(activity) + "\n");
  //console.log("activity.objectId:\n" + activity.objectId + "\n");
  //console.log("activity type:\n" + get_type(activity) + "\n");
  response.success();
});


/*
Parse.Cloud.afterSave("WorkSession", function(request) {
  var activity = request.object.get("activity");
  console.log("aftersave...\n");
  console.log("activity:\n" + JSON.stringify(activity) + "\n");
  console.log("activity.objectId:\n" + activity.objectId + "\n");
  console.log("activity type:\n" + get_type(activity) + "\n");
});
*/


function get_type(thing){
    if(thing===null)return "[object Null]"; // special case
    return Object.prototype.toString.call(thing);
}

