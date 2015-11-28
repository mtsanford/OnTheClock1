//
//  WorkSessionFullTableViewCell.swift
//  OnTheClock1
//
//  Created by Mark Sanford on 11/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class WorkSessionFullTableViewCell: UITableViewCell {
    @IBOutlet weak var activityNameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var startLabel: UILabel!

    func stringFromTimeInterval(interval: NSTimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    var start: NSDate? = nil {
        didSet {
            if let d = start {
                startLabel?.text = "Started at " + WorkSessionFullTableViewCell.dateFormatter.stringFromDate(d)
            }
            else {
                startLabel?.text = ""
            }
        }
    }

    var activityName: String? = nil {
        didSet {
            activityNameLabel?.text = activityName
        }
    }
    
    var duration: NSNumber = 0 {
        didSet {
            durationLabel?.text = stringFromTimeInterval(duration.doubleValue)
        }
    }
    
    
    static let dateFormatter =  {
        () -> NSDateFormatter in
        let localTimeZone = NSTimeZone.localTimeZone()
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = localTimeZone
        dateFormatter.dateFormat = NSDate.is24HoursFormat ? "H:mm" : "h:mm a"
        return dateFormatter
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
