//
//  WorkSessionSummaryCell.swift
//  OnTheClock1
//
//  Created by Work on 11/30/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class WorkSessionSummaryCell: UITableViewCell {
    @IBOutlet weak var activityNameLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!

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
    
}
