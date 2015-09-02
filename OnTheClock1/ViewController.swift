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

