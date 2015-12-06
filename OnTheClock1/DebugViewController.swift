//
//  DebugViewController.swift
//  OnTheClock1
//
//  Created by Work on 11/6/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation
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
        [ "action": "letsCorruptTheDatastore", "text": "letsCorruptTheDatastore"],
        [ "action": "pinPostFirst", "text": "pinPostFirst"],
        [ "action": "flatSave", "text": "flatSave"],
        [ "action": "makePost", "text": "makePost"],
        [ "action": "makeWorkSessions", "text": "makeWorkSessions"],
        [ "action": "timeZone", "text": "timeZone"],
        [ "action": "testMoment", "text": "testMoment"],
        [ "action": "addDate", "text": "add firstTime to user"],
        [ "action": "getDate", "text": "get firstTime from user"],
    ]
    
    func createTestButtons() {
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        NSLog("Document Path: %@", documentsPath)
        
        NSLog("Parse Framework API Version = %ld", PARSE_API_VERSION);
        
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

    

    func flatSave(sender: AnyObject) {
        
        // create a post with a comment and pin it
        let post1 = PFObject(className:"Post")
        post1["text"] = "I am post #1"
        
        post1.pinInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            
            // Make another post with comment and pin it
            let post2 = PFObject(className:"Post")
            post2["text"] = "I am post #2"
            return post2.pinInBackground()
            }.continueWithSuccessBlock {
                (task: BFTask!) -> AnyObject! in
                
                // Now try to query local Post objects
                let query = PFQuery(className:"Post")
                query.fromLocalDatastore()
                return query.findObjectsInBackground()
            }.continueWithBlock {
                (task: BFTask!) -> AnyObject! in
                if (task.error != nil) { print(task.error) }
                else if (task.result != nil) { print(task.result) }
                return nil 
        } 
    }

    
    func letsCorruptTheDatastore(sender: AnyObject) {
        
        // create a post with a comment and pin it
        let post1 = PFObject(className:"Post")
        post1["text"] = "I am post #1"
        let comment1 = PFObject(className:"Comment")
        comment1["post"] = post1
        
        comment1.pinInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            
            // Make another post with comment and pin it
            let post2 = PFObject(className:"Post")
            post2["text"] = "I am post #2"
            let comment2 = PFObject(className:"Comment")
            comment2["post"] = post2
            return comment2.pinInBackground()
            }.continueWithSuccessBlock {
                (task: BFTask!) -> AnyObject! in
                
                // Now try to query local Post objects
                let query = PFQuery(className:"Post")
                query.fromLocalDatastore()
                return query.findObjectsInBackground()
            }.continueWithBlock {
                (task: BFTask!) -> AnyObject! in
                if (task.error != nil) { print(task.error) }
                else if (task.result != nil) { print(task.result) }
                return nil
        }
    }
    
    func pinPostFirst(sender: AnyObject) {
        
        // create a post with a comment and pin it
        let post1 = PFObject(className:"Post")
        post1["text"] = "I am post #1"
        let comment1 = PFObject(className:"Comment")
        comment1["post"] = post1
        
        let post2 = PFObject(className:"Post")
        post2["text"] = "I am post #2"
        let comment2 = PFObject(className:"Comment")
        comment2["post"] = post2

        post1.pinInBackground().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return comment1.pinInBackground()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return post2.pinInBackground()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return comment2.pinInBackground()
        }.continueWithSuccessBlock {
                (task: BFTask!) -> AnyObject! in
                
                // Now try to query local Post objects
                let query = PFQuery(className:"Post")
                query.fromLocalDatastore()
                return query.findObjectsInBackground()
        }.continueWithBlock {
                (task: BFTask!) -> AnyObject! in
                if (task.error != nil) { print(task.error) }
                else if (task.result != nil) { print(task.result) }
                return nil
        }
    }
    
    func makePost(sender: AnyObject) {
        
        // create a post with a comment and pin it
        let post1 = PFObject(className:"Post")
        post1["text"] = "I am another post"
        let comment1 = PFObject(className:"Comment")
        comment1["post"] = post1
        
        comment1.pinInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil) { print(task.error) }
            else if (task.result != nil) { print(task.result) }
            return nil
        }
    }
    
    func makeWorkSessions(sender: AnyObject) {
        let localTimeZone = NSTimeZone.localTimeZone()

        let dateFormatter = NSDateFormatter()
        dateFormatter.timeZone = localTimeZone
        dateFormatter.dateFormat = "yyyy.MM.dd G 'at' HH:mm:ss zzz"
        
        var remaining = 100
        
        func randWS() -> (String, NSDate, NSNumber) {
            let maxMinutes = 120
            let secondsAgo = random() % (3600 * 24 * 180)  // 180 days
            let startTime = NSDate (timeIntervalSinceNow: NSTimeInterval(-secondsAgo))
            let duration = pow(Double(random() % maxMinutes), 2.0) * 60 / Double(maxMinutes) + 600
            
            let activityRand = random() % 100
            var activityName = "Work on novel"
            if (activityRand > 70) { activityName = "Learn swift" }
            if (activityRand > 90) { activityName = "Build flying robot" }
            if (activityRand > 97) { activityName = "Replace carpet in stairway" }
            
            return (activityName, startTime, duration)
        }
        
        let task = BFTask(result: nil)
        task.continueWithBlock {
            (var task) -> AnyObject! in
            for _ in 1...remaining {
                task = task.continueWithBlock({ (task) -> AnyObject! in
                    let (activityName, startTime, duration) = randWS()
                    let dateString = dateFormatter.stringFromDate(startTime)
                    print("\(activityName) \(dateString) \(duration)")
                    return DataSync.sharedInstance.newWorkSession(activityName, start: startTime, duration: duration)
                })
            }
            return task
        }
        
    }
    
    func timeZone(sender: AnyObject) {
        var currentLocale = NSLocale.currentLocale()
        print(currentLocale)
        print(currentLocale.localeIdentifier)
        
        var systemTimeZone = NSTimeZone.defaultTimeZone()
        print(systemTimeZone)
    }
    
    func testMoment(sender: AnyObject) {
        PFCloud.callFunctionInBackground("testMoment", withParameters: nil)
    }
    
    func addDate(sender: AnyObject) {
        let user = PFUser.currentUser() as? OTCUser
        user?.firstTime = NSDate()
        user?.saveInBackground()
    }
    
    func getDate(sender: AnyObject) {
        let user = PFUser.currentUser() as? OTCUser
        print(user?.firstTime)
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
