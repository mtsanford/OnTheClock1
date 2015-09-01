//
//  ViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/19/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var startButton: UIButton!

    var databasePath = NSString()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        OnTheClockData.sharedInstance.open()
        
        /*
        // first crack at sqlite...
        let filemgr = NSFileManager.defaultManager()
        let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        
        let docsDir = dirPaths[0]
        
        databasePath = (docsDir as NSString).stringByAppendingPathComponent("ontheclock.db")
        
        if !filemgr.fileExistsAtPath(databasePath as String) {
            
            let contactDB = FMDatabase(path: databasePath as String)
            
            if contactDB == nil {
                print("Error: \(contactDB.lastErrorMessage())")
            }
            
            if contactDB.open() {
                let create_worksessions = "CREATE TABLE IF NOT EXISTS WORKSESSIONS (ID INTEGER PRIMARY KEY AUTOINCREMENT, START INTEGER, ACTIVITY VARCHAR(255), MINUTES INTEGER)"
                if !contactDB.executeStatements(create_worksessions) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                let create_worksessions_index1 = "CREATE INDEX IF NOT EXISTS WORKSESSION_ACTIVITY ON WORKSESSIONS (ACTIVITY)"
                if !contactDB.executeStatements(create_worksessions_index1) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                let create_worksessions_index2 = "CREATE INDEX IF NOT EXISTS WORKSESSION_START ON WORKSESSIONS (START)"
                if !contactDB.executeStatements(create_worksessions_index2) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                
                let create_activites = "CREATE TABLE IF NOT EXISTS ACTIVITES (ID INTEGER PRIMARY KEY AUTOINCREMENT, ACTIVITY VARCHAR(255), LASTUSED INTEGER)"
                if !contactDB.executeStatements(create_activites) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                contactDB.close()
            } else {
                print("Error: \(contactDB.lastErrorMessage())")
            }
        }
       */
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "timeRecordSegue" {
            let navController = segue.destinationViewController as? UINavigationController
            let timeRecordViewController = navController?.topViewController as? TimeRecordViewController
            timeRecordViewController!.activityString = "do some work"
        }
    }
    
    
    @IBAction func unwindToMainView(sender: UIStoryboardSegue) {
        print("unwindToMainView")
        let sourceViewController = sender.sourceViewController as? TimeRecordViewController
        if (sourceViewController != nil) {
            let timeRecord = sourceViewController!.timeRecord
            if (timeRecord != nil) {
                OnTheClockData.sharedInstance.addWorkSession(timeRecord!)
                print(timeRecord!.start);
                print(timeRecord!.duration);
                print(timeRecord!.activity);
            }
        }
    }

}

