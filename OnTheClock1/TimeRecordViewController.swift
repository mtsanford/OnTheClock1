//
//  TimeRecordViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/20/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class TimeRecordViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    // MARK: Properties
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var activityTextField: UITextField!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var minutesLabel: UILabel!

    var timer: NSTimer?
    var startTime: NSDate?
    var firstStartTime: NSDate?
    var accumulatedTimeLastPause: NSTimeInterval
    var accumulatedTime: NSTimeInterval
    var activityString: String?
    var running: Bool = false
    
    var timeRecord: TimeRecord?

    required init?(coder aDecoder: NSCoder) {
        self.timer = nil
        self.accumulatedTime = 0.0
        self.accumulatedTimeLastPause = 0.0
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        activityTextField.delegate = self
        startStopButton.setTitle("Start", forState: .Normal)
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
    
    func textFieldDidBeginEditing(textField: UITextField) {
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        print("textFieldDidEndEditing\(activityTextField.text)");
        navigationItem.title = activityTextField.text
        activityString = activityTextField.text
    }
    
    
    // MARK: - Navigation
    @IBAction func cancel(sender: UIBarButtonItem) {
        if accumulatedTime >= 60.0 {
            let refreshAlert = UIAlertController(title: "Cancel work?", message: "Cancel and forget about this work period?", preferredStyle: UIAlertControllerStyle.Alert)
            
            refreshAlert.addAction(UIAlertAction(title: "Confirm cancel", style: .Default, handler: { (action: UIAlertAction!) in
                self.dismissViewControllerAnimated(true, completion: nil)
            }))
            
            refreshAlert.addAction(UIAlertAction(title: "Keep working", style: .Default, handler: { (action: UIAlertAction!) in
            }))
            
            presentViewController(refreshAlert, animated: true, completion: nil)
        }
    }

    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if doneButton === sender {
            pause()
            
            
            //let minutes = Int(accumulatedTime/60.0)
            let minutes = Int(ceil(accumulatedTime/60.0)) //!!! FORCE < 60 seconds to 1 min for testing, or we get nil TimeRecord
            
            
            timeRecord = TimeRecord(activity: activityString!, start: startTime!, duration: minutes)
            print("done")
            print("accumulatedTime: + \(accumulatedTime)")
            print("firstStartTime: + \(firstStartTime!)")
        }
    }

    @IBAction func startStopPressed(sender: UIButton) {
        if running {
            pause()
        }
        else {
            running = true
            startTime = NSDate()
            updateTime()
            print("timer started at \(startTime)")
            if firstStartTime === nil  {
                firstStartTime = startTime?.dateByAddingTimeInterval(0.0)
                let startTimeFormatter = NSDateFormatter()
                startTimeFormatter.dateFormat = "h:mm a"
                startTimeLabel.text = startTimeFormatter.stringFromDate(startTime!)
                print("initial start at \(firstStartTime)")
            }
            doneButton.enabled = false
            timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("updateTime"), userInfo: nil, repeats: true)
            startStopButton.setTitle("Pause", forState: .Normal)
        }
    }
    
    func pause() {
        running = false
        timer?.invalidate()
        updateTime()
        accumulatedTimeLastPause = accumulatedTime
        startStopButton.setTitle("Continue", forState: .Normal)
        
        let timeSinceStart = -(startTime?.timeIntervalSinceNow)!
        print("timeSinceStart: \(timeSinceStart)")
        print("accumulatedTime: + \(accumulatedTime)")
    }
    
    func updateTime() {
        accumulatedTime = accumulatedTimeLastPause - (startTime?.timeIntervalSinceNow)!
        let minutes = Int(floor(accumulatedTime / 60.0))
        minutesLabel.text = "\(minutes)"
        if (accumulatedTime > 3.0) {
            doneButton.enabled = true
        }
    }
    
}
