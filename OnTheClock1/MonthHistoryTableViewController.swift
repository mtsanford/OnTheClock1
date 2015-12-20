//
//  MonthHistoryTableViewController.swift
//  OnTheClock1
//
//  Created by Work on 12/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//


import UIKit


class MonthHistoryTableViewController: HistoryTableViewController {

    var nextLoadDate: NSDate? = NSDate()
    
    private static let sectionHeaderFormatter : NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "MMMM YYYY"
        return dateFormatter
    }()
    
    override func loadMore(callback: (newSummaries: [WorkSessionSummary]?, exhaustedData: Bool, error: NSError?) -> ()) {
        DataSync.sharedInstance.fetchSummaries(nextLoadDate!, unit: "month", howMany: 12) {
            (newSummaries: [WorkSessionSummary]?, nextStartDate: NSDate?) -> () in
            self.nextLoadDate = nextStartDate
            if newSummaries != nil {
                callback(newSummaries: newSummaries, exhaustedData: (self.nextLoadDate == nil), error: nil)
            }
            else {
                let error = NSError(domain: "fetchSummaries", code: 0, userInfo: nil)
                callback(newSummaries: nil, exhaustedData: true, error: error)
            }
        }
    }
    
    
    // MARK: - Table view data source
    

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return MonthHistoryTableViewController.sectionHeaderFormatter.stringFromDate(summaries[section].timePeriod)
    }

}
