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
    var workSessionsSummary: [DataSync.WorkSessionSummary]?
    var showDetail: Bool = true {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
        self.tableView.estimatedRowHeight = 72
        
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
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if workSessions != nil {
            return workSessions!.count
        }
        else {
            return 0
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("WorkSessionFullTableViewCell", forIndexPath: indexPath)
            as! WorkSessionFullTableViewCell

        cell.activityName = self.workSessions![indexPath.row].activity.name
        cell.start = self.workSessions![indexPath.row].start
        cell.duration = self.workSessions![indexPath.row].duration

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
