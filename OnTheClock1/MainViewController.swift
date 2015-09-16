//
//  MainViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/19/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit
import Parse

class MainViewController: UIViewController {
    
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

    @IBAction func nukeLocal(sender: AnyObject) {
        PFObject.unpinAllObjectsInBackground()
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "workSessionSegue" {
            print("prepareForSegue workSessionSegue")
            let navController = segue.destinationViewController as? UINavigationController
            let workSessionViewController = navController?.topViewController as? WorkSessionViewController
            if let query = Activity.query() {
                query.fromLocalDatastore()
                query.orderByDescending("last")
                do {
                    var recentActivities: [Activity]
                    try recentActivities = (query.findObjects() as! [Activity])
                    workSessionViewController!.recentActivities = recentActivities
                }
                catch {
                    // if something went wrong, just ignore it.   View will have no recent activities
                    // to show in popop
                }
            }
        }
    }
    
    
    @IBAction func unwindToMainView(sender: UIStoryboardSegue) {
        print("unwindToMainView")
        let sourceViewController = sender.sourceViewController as? WorkSessionViewController
        if (sourceViewController != nil) {
            // resyinc and update UI
        }
    }

}

