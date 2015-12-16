//
//  DayHistoryTableViewController.swift
//  OnTheClock1
//
//  Created by Work on 12/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit


class DayHistoryTableViewController: HistoryTableViewController {

    @IBOutlet weak var detailButton: UIBarButtonItem!
    var detailInnerButton: UIButton! = nil
    let offImage = UIImage(named: "list-unselected")?.imageWithRenderingMode(.AlwaysTemplate)
    let onImage = UIImage(named: "list-selected")?.imageWithRenderingMode(.AlwaysTemplate)
    var showDetail: Bool = false {
        didSet {
            tableView.reloadData()
        }
    }
    
    private static let sectionHeaderFormatter : NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "E MMMM d"
        return dateFormatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.registerNib(UINib(nibName: "WorkSessionFullCell", bundle: nil), forCellReuseIdentifier: "WorkSessionFullCell")

        detailInnerButton = UIButton()
        detailInnerButton.setImage(offImage, forState: .Normal)
        detailInnerButton.setImage(onImage, forState: .Selected)
        detailInnerButton.tintColor = UIColor.OTCDark()
        detailInnerButton.frame = CGRect(x: 0, y: 0, width: 35, height: 33)
        detailButton.customView = detailInnerButton
        detailInnerButton.addTarget(self, action: "detailPressed:", forControlEvents: .TouchUpInside)
        
        // TODO - Do I really have to hard code this?  tableView.rowHeight = -1 on load
        self.tableView.estimatedRowHeight = 72
    }

    // Do the actual fetching of new data to be added to self.summaries, then call the callback
    // if there was an error, set s to nil.   Set d to the next date to query for more data
    // or nil if there is no more data.
    override func loadMore(callback: (newSummaries: [WorkSessionSummary]?, nextLoadDate: NSDate?) -> ()) {
        DataSync.sharedInstance.getRecentWorkSessions().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.result != nil) {
                if let workSessions = task.result as? [WorkSession] {
                    let summaries = DataSync.sharedInstance.summarizeWorkSessions(NSCalendarUnit.Day, workSessions: workSessions)
                    callback(newSummaries: summaries, nextLoadDate: nil)
                }
            }
            return nil
        }
    }
    
    
    // MARK: - Table view data source
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return showDetail ? summaries[section].workSessions!.count : summaries[section].activities.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if showDetail {
            let cell = tableView.dequeueReusableCellWithIdentifier("WorkSessionFullCell", forIndexPath: indexPath) as! WorkSessionFullCell
            let workSession = (summaries[indexPath.section]).workSessions![indexPath.row]
            cell.activityName = workSession.activity.name
            cell.start = workSession.start
            cell.duration = workSession.duration
            return cell
        }
        else {
            return super.tableView(tableView, cellForRowAtIndexPath: indexPath)
        }
        
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return DayHistoryTableViewController.sectionHeaderFormatter.stringFromDate(summaries[section].timePeriod)
    }

    @IBAction func detailPressed(sender: UIBarButtonItem) {
        showDetail = !detailInnerButton.selected
        detailInnerButton.selected = showDetail
    }
    
    
    
}
