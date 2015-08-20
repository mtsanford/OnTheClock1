//
//  TimeRecord.swift
//  OnTheClock1
//
//  Created by Work on 8/20/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation


class TimeRecord: NSObject, NSCoding {
    
    // MARK: Properties
    
    var activity:   String
    var start:      NSDate
    var duration:   Int         // minutes

    // MARK: Archiving paths
    
    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.URLByAppendingPathComponent("timerecords")
    
    // MARK: Types
    
    struct PropertyKey {
        static let activityKey = "activity"
        static let startKey = "start"
        static let durationKey = "duration"
    }
    
    // MARK: Initialization
    
    init?(activity: String, start: NSDate, duration: Int) {
        self.activity = activity
        self.start = start
        self.duration = duration
        
        super.init()
        
        if activity.isEmpty || duration <= 0 {
            return nil
        }
    }
    
    // MARK: NSCoding
    
    required convenience init?(coder aDecoder: NSCoder) {
        let activity = aDecoder.decodeObjectForKey(PropertyKey.activityKey) as! String
        let start = aDecoder.decodeObjectForKey(PropertyKey.startKey) as! NSDate
        let duration = aDecoder.decodeIntegerForKey(PropertyKey.durationKey)
        self.init(activity: activity, start: start, duration: duration)
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(activity, forKey: PropertyKey.activityKey)
        aCoder.encodeObject(start, forKey: PropertyKey.startKey)
        aCoder.encodeInteger(duration, forKey: PropertyKey.durationKey)
    }
    
}
