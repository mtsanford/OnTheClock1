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
    @IBOutlet weak var timePicker: UIDatePicker!
    @IBOutlet weak var activityLabel: UILabel!

    
    //var workSessionViewController: WorkSessionViewController?
    
    // These should be set by caller
    var delegate: WorkSessionControllerDelegate?
    var activityName: String?
    var startTime: NSDate?
    var duration: NSNumber?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timePicker.countDownDuration = 300;
        activityLabel.text = activityName
        
        timePicker.setValue(UIColor.whiteColor(), forKeyPath: "textColor")
        
        let backButton = UIBarButtonItem(
            title: "Keep working",
            style: UIBarButtonItemStyle.Plain,
            target: nil,
            action: nil
        )
        
        self.navigationController!.navigationBar.topItem!.backBarButtonItem = backButton
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("StopWorkSessionViewController prepareForSegue")
        if segue.identifier == "workSessionFinished" {
            print("StopWorkSessionViewController workSessionFinished")
            delegate?.workSessionFinished(activityName!, startTime: startTime!, duration: duration!)
        }
    }

    @IBAction func timePickerChanged(sender: AnyObject) {
        print("timePickerChanged: \(timePicker.countDownDuration)");
        if (timePicker.countDownDuration > 40 * 60) {
            timePicker.countDownDuration = 40 * 60;
        }
    }
    
}
