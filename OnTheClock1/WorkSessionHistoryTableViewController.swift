//
//  WorkSessionHistoryTableViewController.swift
//  OnTheClock1
//
//  Created by Mark Sanford on 11/14/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class WorkSessionHistoryTableViewController: UITableViewController {

    @IBOutlet weak var detailButton: UIBarButtonItem!
    var detailInnerButton: UIButton! = nil
    
    let offImage = UIImage(named: "list-unselected")?.imageWithRenderingMode(.AlwaysTemplate)
    let onImage = UIImage(named: "list-selected")?.imageWithRenderingMode(.AlwaysTemplate)

    var workSessions: [WorkSession]?
    var workSessionsSummary: [WorkSessionSummary]?
    var showDetail: Bool = true {
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

        tableView.registerNib(UINib(nibName: "WorkSessionSummaryCell", bundle: nil), forCellReuseIdentifier: "WorkSessionSummaryCell")
        tableView.registerNib(UINib(nibName: "WorkSessionFullCell", bundle: nil), forCellReuseIdentifier: "WorkSessionFullCell")
        
        DataSync.sharedInstance.getRecentWorkSessions().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.result != nil) {
                self.workSessions = task.result as? [WorkSession]
                self.workSessionsSummary = DataSync.sharedInstance.summarizeWorkSessions(NSCalendarUnit.Day, workSessions: self.workSessions!)
                self.tableView.reloadData()
            }
            return nil
        }

        detailInnerButton = UIButton()
        detailInnerButton.setImage(offImage, forState: .Normal)
        detailInnerButton.setImage(onImage, forState: .Selected)
        detailInnerButton.tintColor = UIColor.redColor()
        detailInnerButton.frame = CGRect(x: 0, y: 0, width: 35, height: 33)
        detailButton.customView = detailInnerButton
        detailInnerButton.addTarget(self, action: "detailPressed:", forControlEvents: .TouchUpInside)
        
        // TODO - Do I really have to hard code this?  tableView.rowHeight = -1 on load
        // TODO - Set on view change
        self.tableView.estimatedRowHeight = 72
        
        showProgressIndicator();
        
        //BFCancellationTokenSource
        
    }

    func showProgressIndicator() {
        let spinner: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        spinner.startAnimating()
        spinner.color = UIColor(red: 22.0/255.0, green: 106.0/255.0, blue: 176.0/255.0, alpha: 1.0) // Spinner Colour
        spinner.frame = CGRectMake(0, 0, 320, 44)
        self.tableView.tableFooterView = spinner
    }
    
    @IBAction func detailPressed(sender: UIBarButtonItem) {
        let currentlySelected = detailInnerButton.selected
        detailInnerButton.selected = !currentlySelected
        showDetail = !showDetail
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func summarizeWorkSessions() {
        
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return workSessionsSummary?.count ?? 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if showDetail {
            return (workSessionsSummary?[section])?.workSessions!.count ?? 0
        }
        else {
            return (workSessionsSummary?[section])?.activities.count ?? 0
        }
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let timePeriod = (workSessionsSummary?[section])?.timePeriod {
            return WorkSessionHistoryTableViewController.sectionHeaderFormatter.stringFromDate(timePeriod)
        }
        else {
            return  ""
        }
    }
    
    override func tableView(tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.lightGrayColor()
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        if showDetail {
            //let c = tableView.dequeueReusableCellWithIdentifier("WorkSessionFullTableViewCell", forIndexPath: indexPath) as! WorkSessionFullTableViewCell
            let c = tableView.dequeueReusableCellWithIdentifier("WorkSessionFullCell", forIndexPath: indexPath) as! WorkSessionFullCell
            if let workSession = (workSessionsSummary?[indexPath.section])?.workSessions![indexPath.row] {
                c.activityName = workSession.activity.name
                c.start = workSession.start
                c.duration = workSession.duration
            }
            cell = c
        }
        else {
            let c = tableView.dequeueReusableCellWithIdentifier("WorkSessionSummaryCell", forIndexPath: indexPath) as! WorkSessionSummaryCell
            if let activitySummary = (workSessionsSummary?[indexPath.section])?.activities[indexPath.row] {
                c.activityName = activitySummary.name
                c.duration = activitySummary.duration
            }
            cell = c
        }
        
        return cell
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
