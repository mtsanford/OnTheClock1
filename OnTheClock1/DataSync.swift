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
    
    // Merge Parse Activiies list with local list, and return result
    func syncActivities(done: ([Activity]) -> Void) {
        let allQuery: PFQuery! = Activity.query()
        if (allQuery == nil) {
            done( [Activity]() )
        }
        allQuery.orderByDescending("last")
        allQuery.findObjectsInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil) {
                if let remoteActivities = task.result as? NSArray {
                    
                }
            }
            return task
        }
    }
    
    
}