//
//  HistoryTableViewController.swift
//  OnTheClock1
//
//  Created by Work on 12/8/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit


class HistoryTableViewController: UITableViewController {

    var spinner: UIActivityIndicatorView!
    var noDataView: UIView!
    var loadingMore: Bool = false
    
    // subclass should keep update these on loadMore() calls
    var summaries = [WorkSessionSummary]()
    var exhaustedData = false
    
    private static let sectionHeaderFormatter : NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "MMMM d YYYY"
        return dateFormatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(UINib(nibName: "WorkSessionSummaryCell", bundle: nil), forCellReuseIdentifier: "WorkSessionSummaryCell")
        self.tableView.estimatedRowHeight = 44
        
        noDataView = UINib(nibName: "NoHistory", bundle: nil).instantiateWithOwner(nil, options: nil)[0] as! UIView
        
        spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        spinner.startAnimating()
        spinner.frame = CGRectMake(0, 0, 320, 44)
        
        startLoadingMore()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func startLoadingMore() {
        if (loadingMore || exhaustedData) { return }
        loadingMore = true;
        spinner.startAnimating()
        self.tableView.tableFooterView = spinner
        loadMore {
            (newSummaries: [WorkSessionSummary]?, exhaustedData: Bool, error: NSError?) -> () in
            dispatch_async(dispatch_get_main_queue()) {
                let oldCount = self.summaries.count
                if (newSummaries != nil) { self.summaries += newSummaries! }
                self.exhaustedData = exhaustedData

                self.spinner.stopAnimating()
                self.loadingMore = false;
                if (error != nil || self.summaries.count == 0) {
                    self.tableView.backgroundView = self.noDataView
                    self.tableView.tableFooterView = UIView(frame: CGRect.zero)
                }
                else {
                    self.tableView.beginUpdates()
                    let set = NSIndexSet(indexesInRange: NSRange(oldCount...self.summaries.count-1))
                    self.tableView.insertSections(set, withRowAnimation: UITableViewRowAnimation.Fade)
                    self.tableView.endUpdates()
                    self.tableView.tableFooterView = nil
                }
            }
        }
    }
    
    func loadMore(callback: (newSummaries: [WorkSessionSummary]?, exhaustedData: Bool, error: NSError?) -> ()) {
        fatalError("HistoryTableViewController::loadMore must be implemented by subclass!")
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
        fatalError("tableView::titleForHeaderInSection must be implemented by subclass!")
    }
    
    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.OTCLightGray()
    }
    
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.section == summaries.count - 1  && indexPath.row == (summaries[indexPath.section].activities.count - 1) ) {
            startLoadingMore()
        }
    }
    
}
