//
//  Utils.swift
//  OnTheClock1
//
//  Created by Work on 11/6/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation

class Utils {
    
    static let agoStringSettings: [[String: AnyObject]] = [
        [ "floor" : 0, "unit": 1, "single": "second", "plural": "seconds" ],
        [ "floor" : 60, "unit": 60, "single": "minute", "plural": "minutes" ],
        [ "floor" : 60*60, "unit": 60*60, "single": "hour", "plural": "hours" ],
        [ "floor" : 60*60*24, "unit": 60*60*24, "single": "day", "plural": "days" ],
        [ "floor" : 60*60*24*7, "unit": 60*60*24*7, "single": "week", "plural": "weeks" ],
    ]

    static func agoStringFromDate(date: NSDate) -> String {
        var agoString = ""
        let secondsAgo = -date.timeIntervalSinceNow
        for setting in agoStringSettings {
            if secondsAgo > setting["floor"] as! Double {
                let unit = setting["unit"] as! Double
                let units = Int(floor(secondsAgo / unit))
                let unitName = (units >= 2 ? setting["plural"] : setting["single"]) as! String
                agoString = "\(units) \(unitName) ago"
            }
        }
        return agoString
    }
    
}

extension NSCalendar {
    func startOfWeekForDate(date: NSDate) -> NSDate? {
        return nil
    }
}



extension NSDate {
    
    private static var is24hour: Bool? = nil
    
    class var is24HoursFormat : Bool  {
        if is24hour == nil {
            let dateString = NSDate.test24hourFormatter.stringFromDate(NSDate())
            is24hour = !(dateString.containsString(NSDate.test24hourFormatter.AMSymbol) || dateString.containsString(NSDate.test24hourFormatter.PMSymbol))
        }
        return is24hour!
    }
    
    private static let test24hourFormatter : NSDateFormatter = {
        let formatter = NSDateFormatter()
        
        formatter.locale    = NSLocale.autoupdatingCurrentLocale()
        formatter.timeStyle = .ShortStyle
        formatter.dateStyle = .NoStyle
        
        return formatter
    }()
}