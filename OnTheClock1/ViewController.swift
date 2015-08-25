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

    static let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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
                print(timeRecord!.start);
                print(timeRecord!.duration);
                print(timeRecord!.activity);
            }
        }
    }

}

