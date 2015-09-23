//
//  WorkSession.swift
//  OnTheClock1
//
//  Created by Work on 9/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation
import Parse

class Activity: PFObject, PFSubclassing {
    
    @NSManaged var name: String
    @NSManaged var last: NSDate
    
    override class func initialize() {
        struct Static {
            static var onceToken : dispatch_once_t = 0;
        }
        dispatch_once(&Static.onceToken) {
            self.registerSubclass()
        }
    }
    
    static func parseClassName() -> String {
        return "Activity"
    }
    
    // get an existing activity, or create a new one
    class func getFromActivityName(fromActivityName activityName: String, cb: (Activity, NSError?) -> Void ) {
        let query: PFQuery! = Activity.query()
        query.fromLocalDatastore()
        query.whereKey("name", equalTo: activityName)
        query.getFirstObjectInBackgroundWithBlock() {
            (result: PFObject?, error: NSError?) -> Void in
            // no result is considered an error
            var activity: Activity
            if (result == nil) {
                activity = Activity()
                activity.name = activityName
                print("creating new activity \(activityName)")
            }
            else {
                activity = result as! Activity
                print("using existing activity \(activityName)")
            }
            cb(activity, nil)
        }
    }
    
    
}
