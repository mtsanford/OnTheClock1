//
//  HistoryTableViewController.swift
//  OnTheClock1
//
//  Created by Work on 12/8/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit


class HistoryTableViewController: UITableViewController {

    var loadingMore: Bool = false
    var summaries = [WorkSessionSummary]()
    var nextLoadDate: NSDate? = NSDate()

    private static let sectionHeaderFormatter : NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "MMMM d YYYY"
        return dateFormatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(UINib(nibName: "WorkSessionSummaryCell", bundle: nil), forCellReuseIdentifier: "WorkSessionSummaryCell")

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        loadMore()
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadMore() {
        DataSync.sharedInstance.fetchSummaries(nextLoadDate!, unit: "week", howMany: 12) {
            (s: [WorkSessionSummary]?, d: NSDate?) -> () in
            if (s != nil) {
                self.summaries += s!
                self.nextLoadDate = d
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return summaries.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return summaries[section].activities.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("WorkSessionSummaryCell", forIndexPath: indexPath) as! WorkSessionSummaryCell
        
        let activitySummary = summaries[indexPath.section].activities[indexPath.row];
        cell.activityName = activitySummary.name
        cell.duration = activitySummary.duration
        
        return cell
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let timePeriod = (summaries[section]).timePeriod {
            return "Week of " + HistoryTableViewController.sectionHeaderFormatter.stringFromDate(timePeriod)
        }
        else {
            return  ""
        }
    }
    
    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.lightGrayColor()
    }
    
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
