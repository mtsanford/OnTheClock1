//
//  DataSync.swift
//  OnTheClock1
//
//  Created by Work on 9/18/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation
import Bolts
import Parse

class DataSync {
    
    static var sharedInstance = DataSync()
    
    init() {}
    
    // Create a new local WorkSession with provisional = true.  Use an existing Activity
    // as the WorkSession's activity, or else create a new provisional one.
    //
    // task.result: the newly created WorkSession.
    //
    func newWorkSession(activityName: String, start: NSDate, duration: NSNumber) -> BFTask {    
        let ourTask = BFTaskCompletionSource()

        let ourWorkSession = WorkSession()
        ourWorkSession.start = start
        ourWorkSession.duration = duration
        ourWorkSession.user = PFUser.currentUser()
        ourWorkSession.provisional = true
        
        var ourActivity: Activity! = nil
        let activityQuery: PFQuery! = Activity.query()
        activityQuery.whereKey("name", equalTo: activityName)
        activityQuery.whereKey("user", equalTo: PFUser.currentUser()!)
        activityQuery.fromLocalDatastore()
        activityQuery.getFirstObjectInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil || task.result == nil) {
                // error indicates a match was not found
                ourActivity = Activity()
                ourActivity.name = activityName
                ourActivity.user = PFUser.currentUser()
                ourActivity.provisional = true
                ourActivity.totalTime = 0.0
            } else {
                ourActivity = task.result as! Activity
            }
            ourActivity.last = start  // TODO add duration
            ourActivity.incrementKey("totalTime", byAmount: duration)
            ourWorkSession.activity = ourActivity
            
            // Activity *MUST* be saved before the WorkSession, or it will lead to corrupt data
            // https://github.com/ParsePlatform/Parse-SDK-iOS-OSX/issues/535
            return ourActivity.pinInBackground()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return ourWorkSession.pinInBackground()
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error == nil) {
                ourTask.setResult(ourWorkSession)
            }
            else {
                ourTask.setError(task.error)
            }
            return nil
        }
        return ourTask.task
    }

    // Save unsaved work sessions, and get updated WorkSession/Activity info from Parse
    func syncToParse() -> BFTask {
        let ourTask = BFTaskCompletionSource()
        var recentWorkSessions : [PFObject]!
        let monthAgo = NSCalendar.currentCalendar().dateByAddingUnit(.Month, value: -1, toDate: NSDate(), options: [])
        
        saveProvisionalWorkSessions().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return self.fetchRecentWorkSessions(monthAgo!)
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            recentWorkSessions = task.result as! [PFObject]
            
            // Now that we have current data with our provisional WorkSessions saved, we can
            // nuke provisional objects.
            // Do it now, before pinning recentWorkSessions, to avoid Parse bug
            return self.unpinOldData(monthAgo!)
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            
            // Go ahead an pin now, just in case fetchRecentActities fails, we'll at least
            // have saved our data set.
            return PFObject.pinAllInBackground(recentWorkSessions)
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return self.fetchRecentActities()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return PFObject.pinAllInBackground(task.result as? [PFObject])
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(nil)
            }
            return nil
        }
        return ourTask.task
    }

    
    // Save all provisional WorkSessions to Parse cloud using newWorkSession cloud function
    func saveProvisionalWorkSessions() -> BFTask {
        var workSessions : [WorkSession]!
        let ourTask = BFTaskCompletionSource()
        let sessionsQuery: PFQuery! = WorkSession.query()
        sessionsQuery.fromLocalDatastore()
        sessionsQuery.whereKey("provisional", equalTo: true)
        sessionsQuery.whereKey("user", equalTo: PFUser.currentUser()!)
        sessionsQuery.includeKey("activity")
        sessionsQuery.findObjectsInBackground().continueWithSuccessBlock {
            (var task: BFTask!) -> AnyObject! in
            workSessions = task.result as! [WorkSession]
            for ws : WorkSession in workSessions {
                task = task.continueWithSuccessBlock {
                    (task: BFTask!) -> AnyObject! in
                    var parameters = Dictionary<NSObject, AnyObject>()
                    parameters["activityName"] = ws.activity.name
                    parameters["start"] = ws.start
                    parameters["duration"] = ws.duration
                    return PFCloud.callFunctionInBackground("newWorkSession", withParameters: parameters)
                }
            }
            return task
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error)
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(nil)
            }
            return nil
        }
        return ourTask.task
    }
    
    // Fetch all recent WorkSessions from Parse
    // TODO: Use modified field to only fetch data we don't already have
    func fetchRecentWorkSessions(afterDate: NSDate) -> BFTask {
        let ourTask = BFTaskCompletionSource()
        
        let sessionsQuery: PFQuery! = WorkSession.query()
        sessionsQuery.orderByDescending("start")
        sessionsQuery.whereKey("start", greaterThan: afterDate)
        sessionsQuery.whereKey("user", equalTo: PFUser.currentUser()!)
        sessionsQuery.includeKey("activity")
        sessionsQuery.findObjectsInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(task.result)
            }
            return nil
        }
        return ourTask.task
    }
    
    // Fetch all recent Activities from Parse   We do this separately because we want knowledge of activites
    // that may have happened before a recent WorkSession, so that they are available in popup menu
    // TODO: Use modified field to only fetch data we don't already have
    func fetchRecentActities() -> BFTask {
        let ourTask = BFTaskCompletionSource()
        let activitiesQuery: PFQuery! = Activity.query()
        activitiesQuery.orderByDescending("last")
        activitiesQuery.limit = 100
        activitiesQuery.whereKey("user", equalTo: PFUser.currentUser()!)
        activitiesQuery.findObjectsInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(task.result)
            }
            return nil
        }
        return ourTask.task
    }
    
    // Unpin old worksessions, and all provisional objects
    // Don't call this unless WorkSessions have been saved successfully, else data loss
    func unpinOldData(beforeDate: NSDate) -> BFTask {
        let ourTask = BFTaskCompletionSource()
        var oldWorkSessions : [PFObject]!
        var provisionalWorkSessions : [PFObject]!
        var provisionalActivities : [PFObject]!

        let oldSessionsQuery: PFQuery! = WorkSession.query()
        oldSessionsQuery.fromLocalDatastore()
        oldSessionsQuery.whereKey("start", lessThan: beforeDate)
        oldSessionsQuery.whereKey("user", equalTo: PFUser.currentUser()!)
        oldSessionsQuery.findObjectsInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            oldWorkSessions = task.result as! [PFObject]
            let provisionalSessionsQuery: PFQuery! = WorkSession.query()
            provisionalSessionsQuery.fromLocalDatastore()
            provisionalSessionsQuery.whereKey("provisional", equalTo: true)
            provisionalSessionsQuery.whereKey("user", equalTo: PFUser.currentUser()!)
            return provisionalSessionsQuery.findObjectsInBackground()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            provisionalWorkSessions = task.result as! [PFObject]
            let provisionalActivitiesQuery: PFQuery! = Activity.query()
            provisionalActivitiesQuery.fromLocalDatastore()
            provisionalActivitiesQuery.whereKey("provisional", equalTo: true)
            provisionalActivitiesQuery.whereKey("user", equalTo: PFUser.currentUser()!)
            return provisionalActivitiesQuery.findObjectsInBackground()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            provisionalActivities = task.result as! [PFObject]
            return PFObject.unpinAllInBackground(oldWorkSessions + provisionalActivities + provisionalWorkSessions)
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error)
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(nil)
            }
            return nil
        }
        return ourTask.task
    }

    // Convert any unsaved data anonymous to the current user
    func convertAnonymousData(anonUser: PFUser) -> BFTask {
        let ourTask = BFTaskCompletionSource()
        let wsQuery: PFQuery! = WorkSession.query()
        wsQuery.fromLocalDatastore()
        wsQuery.whereKey("provisional", equalTo: true)
        wsQuery.whereKey("user", equalTo: anonUser)
        wsQuery.findObjectsInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            let workSessions: [WorkSession]! = task.result as? [WorkSession]
            for (_, element) in workSessions.enumerate() {
                element.user = PFUser.currentUser()
            }
            return PFObject.pinAllInBackground(workSessions)
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            let aQuery: PFQuery! = Activity.query()
            aQuery.fromLocalDatastore()
            aQuery.whereKey("provisional", equalTo: true)
            aQuery.whereKey("user", equalTo: anonUser)
            return aQuery.findObjectsInBackground()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            let activities: [Activity]! = task.result as? [Activity]
            for (_, element) in activities.enumerate() {
                element.user = PFUser.currentUser()
            }
            return PFObject.pinAllInBackground(activities)
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error)
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(task.result)
            }
            return nil
        }
        return ourTask.task
    }
    
    
    // Fetch recent activities from LOCAL DATASTORE
    func getRecentActivities() -> BFTask {
        let ourTask = BFTaskCompletionSource()
        let query: PFQuery! = Activity.query()
        query.fromLocalDatastore()
        query.whereKey("user", equalTo: PFUser.currentUser()!)
        query.orderByDescending("last")
        query?.findObjectsInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error)
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(task.result)
            }
            return nil
        }
        return ourTask.task
    }
    
    // Fetch recent activities from LOCAL DATASTORE
    func getRecentWorkSessions() -> BFTask {
        let ourTask = BFTaskCompletionSource()
        let query: PFQuery! = WorkSession.query()
        query.fromLocalDatastore()
        query.whereKey("user", equalTo: PFUser.currentUser()!)
        query.orderByDescending("last")
        query.includeKey("activity")
        query?.findObjectsInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error != nil {
                print(task.error)
                ourTask.setError(task.error)
            } else {
                ourTask.setResult(task.result)
            }
            return nil
        }
        return ourTask.task
    }
    

    struct ActivitySummary {
        var name: String
        var duration: NSTimeInterval
    }
    
    struct WorkSessionSummary {
        var timePeriod: NSDate
        var activities: [ActivitySummary]
        var workSessions: [WorkSession]
    }
    
    /*
        From an array of WorkSession objects, return summaries by day, week, and month
    
        sample input:
    
        [
            { activityName: 'Wash car',   startDate: Nov 24 11:00, duration: 00:45 }
            { activityName: 'Eat Cheese', startDate: Nov 24 13:12, duration: 00:20 }
            { activityName: 'Eat Cheese', startDate: Nov 24 14:30, duration: 00:15 }
            { activityName: 'Eat Cheese', startDate: Nov 25 08:12, duration: 00:40 }
            { activityName: 'Eat Cheese', startDate: Dec 01 10:12, duration: 01:05 }
        ]
    
        sample return value for calendarUnit == NSCalendarUnit.Day
    
        [
            {
                timePeriod: Nov 24 00:00
                activities [
                    { name: 'Wash car',   duration: 00:45 }
                    { name: 'Eat cheese', duration: 00:35 }
                ]
                workSessions [   /* Pointers to original objects in workSessions argument */
                    { activityName: 'Wash car',   startDate: Nov 24 11:00, duration: 00:45 }
                    { activityName: 'Eat Cheese', startDate: Nov 24 13:12, duration: 00:20 }
                    { activityName: 'Eat Cheese', startDate: Nov 24 14:30, duration: 00:15 }                ]
                ]
            {
                timePeriod: Nov 25 00:00
                activities [
                    { name: 'Eat cheese', duration: 00:40 }
                ]
                workSessions: [
                    { activityName: 'Eat Cheese', startDate: Nov 25 08:12, duration: 00:40 }
                ]
            }
            {
                timePeriod: Dec 01 00:00
                activities [
                    { name: 'Eat cheese', duration: 01:05 }
                ]
                workSessions: [
                    { activityName: 'Eat Cheese', startDate: Dec 01 10:12, duration: 01:05 }
                ]
            }
        ]
    
    */
    
    func summarizeWorkSessions(calendarUnit: NSCalendarUnit, workSessions: [WorkSession]) -> [WorkSessionSummary] {
        var startDate: NSDate?
        var duration: NSTimeInterval = 0
        
        var result = [WorkSessionSummary]()
        
        var buckets = [NSDate:(summaries: [String:Double], workSessions:[WorkSession])]()
        
        for workSession in workSessions {
            
            // Add to a day bucket
            if NSCalendar.currentCalendar().rangeOfUnit(
                calendarUnit,
                startDate: &startDate,
                interval: &duration,
                forDate: workSession.start)
            {
                if (buckets[startDate!] == nil) {
                    buckets[startDate!] = ([String:Double](), [WorkSession]())
                }
                
                if (buckets[startDate!]!.summaries[workSession.activity.name] == nil) {
                    buckets[startDate!]!.summaries[workSession.activity.name] = 0.0
                }
                buckets[startDate!]!.summaries[workSession.activity.name]! += workSession.duration.doubleValue
                
                buckets[startDate!]!.workSessions.append(workSession)
            }
        }
        
        let sortedBuckets = buckets.sort {
            ( t1: (NSDate, (summaries: [String : Double], workSessions: [WorkSession])),
              t2: (NSDate, (summaries: [String : Double], workSessions: [WorkSession]))) -> Bool in
            return t1.0.compare(t2.0) == NSComparisonResult.OrderedDescending
        }
        for bucket in sortedBuckets {
            var summary = WorkSessionSummary(timePeriod: bucket.0, activities:[ActivitySummary](), workSessions: [WorkSession]())
            
            // sort summaries by total duration
            let sortedSummaries = bucket.1.summaries.sort({ (t1:(String, Double), t2:(String, Double)) -> Bool in
                t1.1 > t2.1
            })
            for s in sortedSummaries {
                summary.activities.append(ActivitySummary(name: s.0, duration: s.1))
            }
            
            summary.workSessions = bucket.1.workSessions
            summary.workSessions.sortInPlace({ (t1: WorkSession, t2: WorkSession) -> Bool in
                return t1.start.compare(t2.start) == NSComparisonResult.OrderedAscending
            })
            
            result.append(summary)
        }
        
        print("Summaries: \(result.count)")
        for a in result { print ("\(a.timePeriod) activities: \(a.activities.count) workSessions: \(a.workSessions.count)") }
        
        return result
    }
    
    /*
        Fetch WorkSession summaries from Parse
    */
    func fetchSummaries(firstUnitDate: NSDate, unit: String, howMany: Int) -> BFTask {
        var startDate: NSDate?
        var nextStartDate: NSDate?
        var duration: NSTimeInterval = 0
        let ourTask = BFTaskCompletionSource()
        let calendarUnits = [ "day" : NSCalendarUnit.Day, "week" : NSCalendarUnit.WeekOfYear, "month" : NSCalendarUnit.Month]

        if !NSCalendar.currentCalendar().rangeOfUnit(
            calendarUnits[unit]!,
            startDate: &startDate,
            interval: &duration,
            forDate: firstUnitDate)
        {
            return BFTask(error: NSError(domain: "bad date", code: 0, userInfo: nil))
        }

        nextStartDate = NSCalendar.currentCalendar().dateByAddingUnit(calendarUnits[unit]!, value: howMany, toDate: startDate!, options: [])
        
        var parameters = Dictionary<NSObject, AnyObject>()
        parameters["unit"] = unit
        parameters["howMany"] = howMany
        parameters["firstUnitDate"] = firstUnitDate
        parameters["locale"] = NSLocale.currentLocale().localeIdentifier
        parameters["timeZone"] = NSTimeZone.defaultTimeZone().name
        
        PFCloud.callFunctionInBackground("summarizeWorkSessions", withParameters: parameters).continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if let summaries = task.result as? [NSDictionary] {
                for s in summaries {
                    print(s["unitStart"]!)
                    if let activities = s["activities"] as? NSArray {
                        for a in activities {
                            let name = a["name"]
                            let duration = a["duration"]
                            print("\(name) \(duration)");
                        }
                    }
                }
                ourTask.setResult(task.result)
            }
            if let error = task.error {
                ourTask.setError(task.error)
                print(error.description)
            }
            return nil
        }
        return ourTask.task
    }
    


    
}