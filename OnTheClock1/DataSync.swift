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
    
    // Create a new WorkSession, save it eventually, and pin it locally.
    // Try to use existing Activity from the activity name, or create a
    // new one if no match is found.
    //
    // task.result: the newly created WorkSession.
    //
    func newWorkSession(activityName: String, start: NSDate, duration: NSNumber) -> BFTask {
    
        let ourWorkSession = WorkSession()
        var ourActivity: Activity! = nil
        let ourTask = BFTaskCompletionSource()
        
        let activityQuery: PFQuery! = Activity.query()
        activityQuery.whereKey("name", equalTo: activityName)
        activityQuery.fromLocalDatastore()
        activityQuery.getFirstObjectInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil) {
                print("new activity")
                ourActivity = Activity()
                ourActivity.name = activityName
            } else {
                // no error indicates a match was found
                print("existing activity found")
                ourActivity = task.result as! Activity
            }
            return nil
        }.continueWithSuccessBlock {
            (task: BFTask!) -> BFTask in
            print("pinning workSession...")
            ourWorkSession.activity = ourActivity
            ourWorkSession.start = start
            ourWorkSession.duration = duration
            ourWorkSession.user = PFUser.currentUser()
            ourActivity.last = start  // TODO add duration
            ourWorkSession.saveEventually()
            return ourWorkSession.pinInBackground()
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error == nil) {
                ourTask.setResult(ourWorkSession)
            }
            else {
                ourTask.setError(task.error)
            }
            print("newWorkSession finished")
            return nil
        }
        return ourTask.task
    }
    
    // Keep a list of the last months work sessions locally
    func syncWorkSessions() -> BFTask {
        let ourTask = BFTaskCompletionSource()
        let sessionsQuery: PFQuery! = WorkSession.query()
        let monthAgo = NSCalendar.currentCalendar().dateByAddingUnit(.Month, value: -1, toDate: NSDate(), options: [])
        sessionsQuery.orderByDescending("start")
        sessionsQuery.whereKey("start", greaterThan: monthAgo!)
        sessionsQuery.findObjectsInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            let workSessions = task.result as! [PFObject]
            return PFObject.pinAllInBackground(workSessions)
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
    
    // Keep the list of ALL activities locally
    func syncActivities() -> BFTask {
        let ourTask = BFTaskCompletionSource()
        let allQuery: PFQuery! = Activity.query()
        allQuery.orderByDescending("last")
        allQuery.limit = 1000
        allQuery.findObjectsInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            let activities = task.result as! [PFObject]
            return PFObject.pinAllInBackground(activities)
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
    
    
}