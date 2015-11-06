//
//  DebugViewController.swift
//  OnTheClock1
//
//  Created by Work on 11/6/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class DebugViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    //createTestButtons()

    override func viewDidAppear(animated: Bool) {
        createTestButtons()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Development experiment functions
    
    let actions = [
        [ "action": "saveNew", "text": "new local WS"],
        [ "action": "syncToParse", "text": "datasync.syncToParse"],
        [ "action": "saveToParse", "text": "ds.saveProvisionalWorkSessionsToParse"],
        [ "action": "unpinAll", "text": "Unpin all"],
    ]
    
    func createTestButtons() {
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        NSLog("Document Path: %@", documentsPath)
        
        for (i, action) in actions.enumerate() {
            let button   = UIButton(type: UIButtonType.System)
            button.frame = CGRectMake(20, 80.0 + CGFloat(i)*30.0, 300, 30)
            button.backgroundColor = UIColor.greenColor()
            button.setTitle(action["text"], forState: UIControlState.Normal)
            let selector = Selector(action["action"]! + ":")
            button.addTarget(self, action: selector, forControlEvents: UIControlEvents.TouchUpInside)
            self.view.addSubview(button)
        }
        
        
    }
    
    func unpinAll(sender: AnyObject) {
        print("unpinAll");
        PFObject.unpinAllObjectsInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil) {
                print(task.error)
            }
            else {
                print("unpinned all success")
            }
            return nil
        }
    }
    
    func syncToParse(sender: AnyObject) {
        DataSync.sharedInstance.syncToParse().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            print("syncToParse done")
            if (task.error != nil) { print(task.error) }
            else if (task.result != nil) { print(task.result) }
            return task
        }
    }
    
    func saveNew(sender: AnyObject) {
        print("saveNew");
        
        let now = NSDate()
        DataSync.sharedInstance.newWorkSession("activity2", start: now, duration: 50).continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            print("saved new workSession to local store");
            return task
        }
        
    }
    
    
    func saveToParse(sender: AnyObject) {
        print("saveToParse");
        DataSync.sharedInstance.saveProvisionalWorkSessions().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil) {
                print(task.error)
            }
            else {
                print("saved provisional work sessions to parse");
            }
            return nil
        }
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
