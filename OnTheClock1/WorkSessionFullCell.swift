//
//  WorkSessionFullCell.swift
//  OnTheClock1
//
//  Created by Work on 12/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class WorkSessionFullCell: UITableViewCell {
    @IBOutlet weak var activityNameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var startTimeLabel: UILabel!
    
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
    
    var start: NSDate? = nil {
        didSet {
            if let d = start {
                startTimeLabel?.text = "Started at " + WorkSessionFullCell.dateFormatter.stringFromDate(d)
            }
            else {
                startTimeLabel?.text = ""
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    func stringFromTimeInterval(interval: NSTimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }

    static let dateFormatter =  {
        () -> NSDateFormatter in
        let localTimeZone = NSTimeZone.localTimeZone()
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = localTimeZone
        dateFormatter.dateFormat = NSDate.is24HoursFormat ? "H:mm" : "h:mm a"
        return dateFormatter
    }()
    
}
