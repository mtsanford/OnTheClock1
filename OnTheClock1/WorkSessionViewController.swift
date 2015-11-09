//
//  WorkSessionViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/20/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

protocol WorkSessionControllerDelegate {
    func workSessionFinished(activityName: String, startTime: NSDate, duration: NSNumber)
}

class WorkSessionViewController: UIViewController, UINavigationControllerDelegate {
    
    // MARK: Properties
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var minutesStackView: UIStackView!
    @IBOutlet weak var minutesLabel: UILabel!

    var activityString: String?

    var timer: NSTimer?
    var startTime: NSDate?
    var firstStartTime: NSDate?
    var accumulatedTimeLastPause: NSTimeInterval
    var accumulatedTime: NSTimeInterval
    var running: Bool = false
    var finishing: Bool = false
    let minimumWorkTime = 2.0
    
    var workSession: WorkSession?
    
    var delegate: WorkSessionControllerDelegate?
    
    
    // TODO: Does this need to be implemented correctly?
    // could be "freeze dried" if put into background?
    required init?(coder aDecoder: NSCoder) {
        self.timer = nil
        self.accumulatedTime = 0.0
        self.accumulatedTimeLastPause = 0.0
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("WorkSessionViewController viewDidLoad")
        startTimeLabel.hidden = true
        minutesStackView.hidden = true
        
        activityLabel.text = activityString
        
        self.navigationController?.delegate = self

        continueSession()
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - Navigation
    @IBAction func cancel(sender: UIBarButtonItem) {
        if accumulatedTime >= minimumWorkTime {
            let refreshAlert = UIAlertController(title: "Cancel work?", message: "Cancel and forget about this work session?", preferredStyle: UIAlertControllerStyle.Alert)
            
            refreshAlert.addAction(UIAlertAction(title: "Confirm cancel", style: .Default, handler: { (action: UIAlertAction!) in
                self.dismissViewControllerAnimated(true, completion: nil)
            }))
            
            refreshAlert.addAction(UIAlertAction(title: "Keep working", style: .Default, handler: { (action: UIAlertAction!) in
            }))
            
            presentViewController(refreshAlert, animated: true, completion: nil)
        }
        else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("WorkSessionViewController prepareForSegue")
        if segue.identifier == "stopWorkSession" {
            //stopWorkSessionViewController!.workSessionViewController = self
            pause()
            let stopWorkSessionViewController = segue.destinationViewController as? StopWorkSessionViewController
            stopWorkSessionViewController!.delegate = self.delegate
            stopWorkSessionViewController?.activityName = self.activityString
            stopWorkSessionViewController?.startTime = firstStartTime
            stopWorkSessionViewController?.duration = accumulatedTime
        }
    }

    @IBAction func donePressed(sender: UIBarButtonItem) {
        print("donePressed")
        if finishing { return }
        finishing = true
        pause()
        
        DataSync.sharedInstance.newWorkSession(activityString!, start: self.firstStartTime!, duration: self.accumulatedTime).continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            self.performSegueWithIdentifier("unwindToMainView", sender: self)
            return nil
        }
        return;
    }
    
    func continueSession() {
        print("continueSession")
        if (running == false) {
            running = true
            startTime = NSDate()
            updateTime()
            print("timer started at \(startTime)")
            if firstStartTime === nil  {
                firstStartTime = startTime?.dateByAddingTimeInterval(0.0)
                let startTimeFormatter = NSDateFormatter()
                startTimeFormatter.dateFormat = "h:mm a"
                let startTimeText = startTimeFormatter.stringFromDate(startTime!)
                startTimeLabel.text = "Started at \(startTimeText)"
                startTimeLabel.hidden = false
                minutesStackView.hidden = false
                print("initial start at \(firstStartTime)")
            }
            doneButton.enabled = false
            timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("updateTime"), userInfo: nil, repeats: true)
        }
    }
    
    func pause() {
        print("pause")
        if (running == true) {
            running = false
            timer?.invalidate()
            updateTime()
            accumulatedTimeLastPause = accumulatedTime
            self.view.backgroundColor = UIColor.lightGrayColor()
            
            let timeSinceStart = -(startTime?.timeIntervalSinceNow)!
            print("timeSinceStart: \(timeSinceStart)")
            print("accumulatedTime: + \(accumulatedTime)")
        }
    }
    
    func updateTime() {
        accumulatedTime = accumulatedTimeLastPause - (startTime?.timeIntervalSinceNow)!
        let minutes = Int(floor(accumulatedTime / 60.0))
        minutesLabel.text = "\(minutes)"
        doneButton.enabled = accumulatedTime >= minimumWorkTime
    }
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        if (viewController == self) {
            continueSession()
        }
        else {
            pause()
        }
    }

}