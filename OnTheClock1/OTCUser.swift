//
//  WorkSession.swift
//  OnTheClock1
//
//  Created by Work on 9/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation
import Parse

class OTCUser: PFUser {
    
    @NSManaged var firstTime: NSDate
    
    override class func initialize() {
        struct Static {
            static var onceToken : dispatch_once_t = 0;
        }
        dispatch_once(&Static.onceToken) {
            print("registered OTCUser")
            self.registerSubclass()
        }
    }
    
    /*
    static func parseClassName() -> String {
        return "OTCUser"
    }
    */
    
    
}
