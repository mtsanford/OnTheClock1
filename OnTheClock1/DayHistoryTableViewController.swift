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
            let topVisible = tableView.indexPathsForVisibleRows?.sort { $1.section > $0.section }.first
            if (topVisible != nil) {
                self.tableView.estimatedRowHeight = showDetail ? 52 : 44
                tableView.reloadData()
                let topSection = NSIndexPath(forRow: 0, inSection: topVisible!.section)
                tableView.scrollToRowAtIndexPath(topSection, atScrollPosition: UITableViewScrollPosition.Top, animated: false)
            }
        }
    }

    var localLoaded = false;
    var lastDate: NSDate?
    var buckets = [NSDate:(summaries: [String:Double], workSessions:[WorkSession])]()
    
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
    }

    override func loadMore(callback: (newSummaries: [WorkSessionSummary]?, exhaustedData: Bool, error: NSError?) -> ()) {
        let queryLimit = 100
        let loadLocalData = !localLoaded
        let query: PFQuery! = WorkSession.query()
        var exhaustedData = false

        query.whereKey("user", equalTo: PFUser.currentUser()!)
        query.orderByDescending("start")
        query.includeKey("activity")
        if (lastDate != nil) { query.whereKey("start", lessThan: lastDate!) }
        
        if (loadLocalData) {
            query.fromLocalDatastore()
            localLoaded = true;
        }
        else {
            query.limit = queryLimit
        }
        
        query?.findObjectsInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if task.error == nil {
                let newWorkSessions = task.result as! [WorkSession]
                self.addWorkSessionsToBuckets(newWorkSessions)
                var newSummaries = self.makeSummaries()
                
                // If we've not exhaused data, assume last summary is incomplete
                if ( (loadLocalData && newSummaries.count > 1) || (!loadLocalData && newWorkSessions.count == queryLimit)) {
                    newSummaries.removeLast()
                    self.lastDate = newWorkSessions.last!.start
                }
                else {
                    exhaustedData = true;
                }
                callback(newSummaries: newSummaries, exhaustedData: exhaustedData, error: nil)
            }
            else {
                callback(newSummaries: nil, exhaustedData: exhaustedData, error: task.error)
            }
            return nil
        }

    }

    private func addWorkSessionsToBuckets(workSessions: [WorkSession]) {
        var startDate: NSDate?
        var duration: NSTimeInterval = 0
        
        for workSession in workSessions {
            // Add to a day bucket
            if NSCalendar.currentCalendar().rangeOfUnit(.Day, startDate: &startDate, interval: &duration, forDate: workSession.start)
            {
                if (buckets[startDate!] == nil) {
                    buckets[startDate!] = ([String:Double](), [WorkSession]())
                }
                if (buckets[startDate!]!.summaries[workSession.activity.name] == nil) {
                    buckets[startDate!]!.summaries[workSession.activity.name] = 0.0
                }
                buckets[startDate!]!.summaries[workSession.activity.name]! += workSession.duration.doubleValue
                buckets[startDate!]!.workSessions.append(workSession)
            }
        }
    }
    
    // Mark summarise from buckets
    private func makeSummaries() -> [WorkSessionSummary] {
        var result = [WorkSessionSummary]()
        
        let sortedBuckets = buckets.sort {
            ( t1: (NSDate, (summaries: [String : Double], workSessions: [WorkSession])),
            t2: (NSDate, (summaries: [String : Double], workSessions: [WorkSession]))) -> Bool in
            return t1.0.compare(t2.0) == NSComparisonResult.OrderedDescending
        }
        for bucket in sortedBuckets {
            var summary = WorkSessionSummary(timePeriod: bucket.0, activities:[ActivitySummary](), workSessions: nil)
            
            // sort summaries by total duration
            let sortedSummaries = bucket.1.summaries.sort({ (t1:(String, Double), t2:(String, Double)) -> Bool in
                t1.1 > t2.1
            })
            for s in sortedSummaries {
                summary.activities.append(ActivitySummary(name: s.0, duration: s.1))
            }
            
            summary.workSessions = bucket.1.workSessions
            summary.workSessions!.sortInPlace({ (t1: WorkSession, t2: WorkSession) -> Bool in
                return t1.start.compare(t2.start) == NSComparisonResult.OrderedAscending
            })
            
            result.append(summary)
        }
        
        // only return the NEW work sessions, not the ones already summaries
        return [WorkSessionSummary](result[summaries.count..<result.count])
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
