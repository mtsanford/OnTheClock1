//
//  MonthHistoryTableViewController.swift
//  OnTheClock1
//
//  Created by Work on 12/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//


import UIKit


class MonthHistoryTableViewController: HistoryTableViewController {
    
    private static let sectionHeaderFormatter : NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "MMMM YYYY"
        return dateFormatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // Do the actual fetching of new data to be added to self.summaries, then call the callback
    // if there was an error, set s to nil.   Set d to the next date to query for more data
    // or nil if there is no more data.
    override func loadMore(callback: (newSummaries: [WorkSessionSummary]?, nextLoadDate: NSDate?) -> ()) {
        DataSync.sharedInstance.fetchSummaries(nextLoadDate!, unit: "month", howMany: 12, callback: callback)
    }
    
    
    // MARK: - Table view data source
    

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return MonthHistoryTableViewController.sectionHeaderFormatter.stringFromDate(summaries[section].timePeriod)
    }

}
