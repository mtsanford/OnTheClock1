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
            return ourWorkSession.pinInBackground()
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            print("newWorkSession finished")
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
            return PFObject.pinAllInBackground(task.result as! [PFObject])
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
                    print("calling newWorkSession cloud function")
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


    
}