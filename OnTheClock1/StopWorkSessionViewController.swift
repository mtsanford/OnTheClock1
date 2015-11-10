//
//  StopWorkSessionViewController.swift
//  OnTheClock1
//
//  Created by Work on 11/8/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

// This view is tighly coupled to WorkSessionViewController

class StopWorkSessionViewController: UIViewController {

    
    //var workSessionViewController: WorkSessionViewController?
    
    // These should be set by caller
    var delegate: WorkSessionControllerDelegate?
    var activityName: String?
    var startTime: NSDate?
    var duration: NSNumber?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("StopWorkSessionViewController prepareForSegue")
        if segue.identifier == "workSessionFinished" {
            delegate?.workSessionFinished(activityName!, startTime: startTime!, duration: duration!)            
        }
    }

}
