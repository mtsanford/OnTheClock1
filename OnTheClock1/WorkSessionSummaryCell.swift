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

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
