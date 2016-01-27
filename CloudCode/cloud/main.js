var moment = require('cloud/moment-timezone-with-data.js');
var _ = require("underscore");

var WorkSession = Parse.Object.extend("WorkSession");
var Activity = Parse.Object.extend("Activity");

var Settings = {
	// How many WorkSessions a client is allowed to send to 'sync'
	maxClientRequest: 50,
	
	// The maxium number of WorkSessions (besides confirmed client adds)
	// to send back to client
	maxUpdateResponse: 50
};

var log = {
	add: function(text) {
		this.theText += text + "\n";
	},
	print: function() {
		console.log(this.theText);
		this.theText = "";
	},
	
	theText: ""
}


// Add new work sessions, then return to the client all WorkSessions and Activities
// with a more recent updatedAt time than the client requested.   Note that these
// returned objects INCLUDE the new work sessions (with a proper objectId), and 
// associated new/existing Activity objects.
Parse.Cloud.define("sync", function(request, response) {
	
	var finalResult = { 
			workSessions: [],
			activities: [], 
			newLastSyncTimestamp: 0,
			newSyncDownTimestamp: 0,
			haveUpdates: false 
		},
		haveUpdates = false,
	    user = request.user,
	    lastSyncTimestamp = request.params.lastSyncTimestamp,
		syncDownTimestamp = request.params.syncDownTimestamp,
	    newLastSyncTimestamp = lastSyncTimestamp,
		newSyncDownTimestamp = 0,
		activityInfo = {},
		workSessionInfo = [],
	    wsQuery = new Parse.Query(WorkSession),
	    aQuery = new Parse.Query(Activity);

		
		function addWorkSessionsResult(workSessions) {
			// Avoid partial results where a query with a limit could include _some_
			// objects with updatedAt = X, but not all.   This could only happen if 
			// the query limit was reached, so if it was, trim off all objects that
			// have the least recent updatedAt.
			if (workSessions.length == Settings.maxUpdateResponse) {
				var leastRecent = results[workSessions.length - 1].updatedAt.getTime();
				while (workSessions.length && workSessions[workSessions.length - 1].updatedAt.getTime() == leastRecent) {
					workSessions.pop();
				}
				newSyncDownTimestamp = workSessions[workSessions.length - 1].updatedAt.getTime();
			}
			_.each(workSessions, function(workSession) {
				workSessionInfo.push({ workSession: workSession });
				var activity = workSession.get("activity");
				if (activityInfo[activity.id] == undefined) {
					activityInfo[activity.id] = { activity: activity };
				}
			});
		}
		

	// first check for WorkSession updates since the client last 
	wsQuery.equalTo("user", user);
	wsQuery.include("activity");
	wsQuery.greaterThan("updatedAt", lastSyncTimestamp);
	wsQuery.descending("updatedAt");
	wsQuery.limit(Settings.maxUpdateResponse);
	wsQuery.find().then(function(workSessions) {
		var activityCheckTime = lastSyncTimestamp;
		if (workSessions.length) {
			haveUpdates = true;
			addWorkSessionsResult(workSessions);
			activityCheckTime = workSessions[workSessions.length - 1].updatedAt.getTime();
			newLastSyncTimestamp = workSessions[0].updatedAt.getTime();
		}
		
		// also check for activity updates in the same time range as WorkSession updates, 
		// since they can be updated by (name change) without any WorkSession change
		aQuery.equalTo("user", user);
		aQuery.greaterThanOrEqualTo("updatedAt", activityCheckTime);
		wsQuery.descending("updatedAt");
		return aQuery.find();
	}).then(function(activites) {
		if (activites.length) { 
			haveUpdates = true;
			newLastSyncTimestamp = activites[0].updatedAt.getTime();
		}
		_.each(activites, function(activity) {
			if (activityInfo[activity.id] == undefined) {
				activityInfo[activity.id] = { activity: activity };
			}
		});
		
		// If there were no updates, we can go ahead and send syncDown updates
		if (!haveUpdates && syncDownTimestamp) {
			var syncDownWorkSessionQuery = new Parse.Query(WorkSession);
			syncDownWorkSessionQuery.equalTo("user", user);
			syncDownWorkSessionQuery.include("activity");
			syncDownWorkSessionQuery.lessThan("updatedAt", syncDownTimestamp);
			syncDownWorkSessionQuery.descending("updatedAt");
			syncDownWorkSessionQuery.limit(Settings.maxUpdateResponse);
			return syncDownWorkSessionQuery.find().then(function(workSessions) {
				var activityCheckTime,
				    done = workSessions.length < Settings.maxUpdateResponse;
				
				addWorkSessionsResult(workSessions);
				if (done) {
					activityCheckTime = 0;
					newSyncDownTimestamp = 0;
				}
				else {
					activityCheckTime = workSessions[workSessions.length - 1].updatedAt.getTime();
					newSyncDownTimestamp = activityCheckTime;
				}
				
				// also check for activity updates 
				var backActivityQuery = new Parse.Query(Activity);
				backActivityQuery.equalTo("user", user);
				syncDownWorkSessionQuery.lessThan("updatedAt", syncDownTimestamp);
				backActivityQuery.greaterThanOrEqualTo("updatedAt", activityCheckTime);
				return backActivityQuery.find();
			}).then(function(activites) {
				_.each(activites, function(activity) {
					if (activityInfo[activity.id] == undefined) {
						activityInfo[activity.id] = { activity: activity };
					}
				});
				return addNewWorkSessions();				
			});
		}
		else {
			return addNewWorkSessions();
		}
	}).then(function() {
		Object.getOwnPropertyNames(activityInfo).forEach(function(id) {
			var info = activityInfo[id];
			var activityResult = {
				parseId: info.activity.id,
				lastTime: info.activity.get("lastTime"),
				totalTime: info.activity.get("totalTime"),
				name: info.activity.get("name")					
			;
			if (info.id) { activityResult.id = info.id; }
			finalResult.activities.push(activityResult);
		});
		workSessionInfo.forEach(function(info) {
			workSessionResult = {
				parseId: info.workSession.id,
				startTime: info.workSession.get("startTime"),
				duration: info.workSession.get("duration"),
				adjustment: info.workSession.get("adjustment"),
				activityId: info.workSession.get("activity").id 
			};
			if (info.id) { workSessionResult.id = info.id; }
			finalResult.workSessions.push(workSessionResult);
		});
		finalResult.newSyncDownTimestamp = newSyncDownTimestamp;
		finalResult.newLastSyncTimestamp = newLastSyncTimestamp;
		finalResult.haveUpdates = haveUpdates;

		response.success(finalResult);
	}, function(error) {
		log.print();
		response.error(error);		
	});


	function addNewWorkSessions() {
		var activityInfoByName = {},
			workSessionsSaveInfo = [],
		    promise = new Parse.Promise.as();
		
			function getActivity(workSessionInfo) {
			    var promise = new Parse.Promise(),
				    aQuery = new Parse.Query(Activity),
				    activityId = workSessionInfo.activityId,
				    activityName = workSessionInfo.activityName;
	
				if (activityId) {
					if (activityInfo[activityId]) {
						log.add("hit activityCacheById " + activityId);
						promise = Parse.Promise.as(activityInfo[activityId].activity);
					}
					else {
						aQuery.get(activityId).then(
							function(activity) {
								log.add("fetched activity by id " + activityId);
								activityInfo[activityId] = { activity: activity };
								promise.resolve(activity);
							},
							function(error) {
								promise.reject("Problem getting the new WorkSession's activity");
							}
						);
					}
				}
				else if (activityName) {
					if (activityInfoByName[activityName]) {
						log.add("hit activityInfoByName " + activityName);
						promise = Parse.Promise.as(activityInfoByName[activityName].activity);
					}
					else {
						aQuery.equalTo("name", activityName);
						aQuery.equalTo("user", user);
						aQuery.first().then(function(activity) {
							if (!activity) {
								activity = new Activity();
								activity.set("name", activityName);
								activity.set("user", user);
								log.add("new activity " + activityName);
							} else {
								log.add("fetched activity by name " + activityName);
							}
							activityInfoByName[activityName] = { activity: activity, id: workSessionInfo.id };
							promise.resolve(activity);
						});
					}
				}
				else {
					promise = Parse.Promise.error("workSession has no Activity name or id");
				}
	
				return promise;
			}

			log.add("newWorkSessions length: " + newWorkSessions.length);

		_.each(request.params.newWorkSessions, function(workSessionInfo) {
		
			promise = promise.then(function() {

				var wsQuery = new Parse.Query(WorkSession),
				    startTime = workSessionInfo.startTime;
			
				wsQuery.equalTo("start", startTime);
				wsQuery.equalTo("user", user);
				return wsQuery.first().then(function(result) {
					if (result) {
						// Worksession for this time already added
						log.add("existing WorkSession " + startTime);
						workSessionInfo.workSession = result;
						return Parse.Promise.as();
					}
				
					workSession = new WorkSession();
					workSession.set("user", user);
					workSession.set("start", startTime);
					workSession.set("duration", workSessionInfo.duration);		
					workSession.set("adjustment", workSessionInfo.adjustment);		
				
					log.add("new WorkSession: " + startTime)
					return getActivity(workSessionInfo).then(function(activity) {
						workSession.set("activity", activity);
						var last = activity.get("lastTime");
						if (!last || startTime.getTime() > last.getTime()) {
							activity.set("lastTime", startTime); 
						}
						var total = activity.get("totalTime") || 0.0;
						activity.set("totalTime", workSessionInfo.duration + total);
						workSessionsSaveInfo.push({
							workSession: workSession,
							id: workSessionInfo.id
						});
					}, function(error) {
					});
				});
			});
		});
	
		promise = promise.then(function() {
			var workSessionsToSave = [],
			workSessionsSaveInfo.forEach(function(saveInfo) {
				workSessionsToSave.push(saveInfo.workSession);				
			});
			return Parse.Object.saveAll(workSessionsToSave);
		}).then(function() {
			
			// Add all the workSessions, and activites to result set
			_.each(workSessionsSaveInfo, function(saveInfo) {
				var workSession = saveInfo.workSession,
				    activity = workSession.get("activity");
				
				workSessionInfo.push({ workSession: workSession, id: saveInfo.id });
				activityInfo[activity.id] = { activity: activity }
				if (workSession.updatedAt.getTime() >  newLastSyncTimestamp) {
					newLastSyncTimestamp = workSession.updatedAt.getTime();
				}
				if (activity.updatedAt.getTime() >  newLastSyncTimestamp) {
					newLastSyncTimestamp = activity.updatedAt.getTime();
				}
			});
			
			// if the client referred to the activity by name and id, mark the activityInfo entry with the id.
			Object.getOwnPropertyNames(activityInfoByName).forEach(function(name) {
				var info = activityInfoByName[name];
				activityInfo[info.activity.id].id = info.id;
			});
		});
	
		return promise;
	}


});



/*
*/
Parse.Cloud.define("summarizeWorkSessions", function(request, response) {
	var user = request.user,
	    unit = request.params.unit,
	    howMany = request.params.howMany,
	    firstUnitDate = request.params.firstUnitDate,
	    locale = request.params.locale,
	    timeZone = request.params.timeZone;
	
	if (!user) {
		response.error("Must be signed in to call summarizeWorkSessions.")
		return;
	}
	if (!unit || typeof unit != "string") {
		response.error("Bad parameter 'unit' (type string)");
		return;
	}
	if (!firstUnitDate || get_type(firstUnitDate) != "[object Date]") {
		response.error("Bad parameter 'firstUnitDate' (type Date)");
		return;
	}
	if (!howMany || typeof howMany != "number") {
		response.error("Bad parameter 'howMany' (type number)");
		return;
	}
	if (!locale || typeof locale != "string") {
		response.error("Bad parameter 'locale' (type string)");
		return;
	}
	if (!timeZone || typeof timeZone != "string") {
		response.error("Bad parameter 'timeZone' (type string)");
		return;
	}
	
	summarizeWorkSessions(user, unit, howMany, firstUnitDate, locale, timeZone).then(
		function(result) { response.success(result); },
		function(error) { response.error(error); }
	);
});


/*
	parameters:

	user			PFUser object
	unit			'day', 'week', or 'month'
	howMany			how many units to summarize, not including empty units.   
	firstUnitDate	Date object.  Most recent unit to summarize. 
	locale			String (locale code.  Used for determining first day of week - e.g. Sun or Mon)
	timeZone		String

	returns: Parse.Promise

	NOTE: The first unit of the returned results will be the unit that firstUnitDate falls in.  So
 	if the unit is 'month', and firstUnitDate is 2015-03-15T13:45:00, then the first unit will be
    2015-03-01 through 2015-03-31, with the unitStart of 2015-03-01T00:00:00 in the timeZone provided.

	result will be an array of AT LEAST howMany *nonempty* summaries of unit size, sorted in decending
	order of unitStart (the start time of the unit).   If there is not enough data, then all remaining
	unit summaries will be returned, and the exhaustedData flag will be true.

    Summaries will include the unit start date, and a list of activity duration totals, orded in descending
	ordr of duration.

	sample result: {
		exhaustedData: false,
		summaries: [
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
	}

*/
function summarizeWorkSessions(user, unit, howMany, firstUnitDate, locale, timeZone) {
	var maxTime, i, j, sortedBucketKeys, sortedActivityKeys,
	    addUnit = { 'day' : 'days', 'week' : 'weeks', 'month' : 'months' }[unit],
	    itemsPerFetch = 100,
	    promise = new Parse.Promise(),
	    exhaustedData = false,
	    buckets = {};

	if (addUnit == undefined) { return Parse.Promise.error("bad unit: " + unit); }
	if (howMany < 1 || howMany > 500) { return Parse.Promise.error("invalid number of units"); }
	
    function fillMeSomeBuckets(maxTime) {
		var done = false,
			fillPromise = new Parse.Promise();
			wsQuery = new Parse.Query(WorkSession);

		wsQuery.equalTo("user", user);
		wsQuery.include("activity");
		wsQuery.limit(itemsPerFetch);
		wsQuery.lessThan("start", maxTime);
		wsQuery.addDescending("start");
  
		wsQuery.find().then(
			function(workSessions) {
			    var b, duration, activityName;
				
				for (i=0; i<workSessions.length; i++) {
					b = moment(workSessions[i].get('start')).tz(timeZone).locale(locale).startOf(unit).valueOf().toString();
					activityName = workSessions[i].get('activity').get('name');
					duration = workSessions[i].get('duration');
				
					if (buckets[b] == undefined) { buckets[b] = {} }
					buckets[b][activityName] = buckets[b][activityName] || 0
					buckets[b][activityName] += duration;
				}
			
				sortedBucketKeys = Object.keys(buckets).sort(function(a,b) { return b-a; });
				exhaustedData = workSessions.length < itemsPerFetch;
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
			var summary, bucket,
			    summaries = [];
			
			// Now munge up all those hashs into sorted arrays for the final result
			sortedBucketKeys = Object.keys(buckets).sort(function(a,b) { return b-a; });
			for (i=0; i<sortedBucketKeys.length; i++) {
				bucket = buckets[sortedBucketKeys[i]];
				summary = { unitStart: moment(parseInt(sortedBucketKeys[i])).tz(timeZone).locale(locale).toDate(), activities: [] };
				sortedActivityKeys = Object.keys(bucket).sort(function(a,b) { return bucket[a] > bucket[b] ? -1 : 1 });
				for (j=0; j<sortedActivityKeys.length; j++) {
					summary.activities.push({ name: sortedActivityKeys[j], duration: bucket[sortedActivityKeys[j]] });
				}
				summaries.push(summary);
			}
			promise.resolve({ exhaustedData: exhaustedData, summaries: summaries });
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
	var workSession, activity, firstTime,
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
			firstTime = user.get("firstTime");
			if (!firstTime || start < firstTime) {
				user.set("firstTime", start);
				console.log("saving first time: " + firstTime)
				return user.save();
			}
		}).then(function(result) {
			response.success("saved");			
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

