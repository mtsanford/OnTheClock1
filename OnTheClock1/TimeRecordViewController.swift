//
//  TimeRecordViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/20/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class TimeRecordViewController: UIViewController, UITextFieldDelegate, MPGTextFieldDelegate, UINavigationControllerDelegate {
    
    // MARK: Properties
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var activityTextField: MPGTextField!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var minutesStackView: UIStackView!
    @IBOutlet weak var minutesLabel: UILabel!

    var timer: NSTimer?
    var startTime: NSDate?
    var firstStartTime: NSDate?
    var accumulatedTimeLastPause: NSTimeInterval
    var accumulatedTime: NSTimeInterval
    var activityString: String?
    var running: Bool = false
    let minimumWorkTime = 60.0
    
    var timeRecord: TimeRecord?

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
        activityTextField.delegate = self
        activityTextField.mDelegate = self
        activityTextField.text = activityString
        startStopButton.setTitle("Start", forState: .Normal)
        activityLabel.hidden = true
        startTimeLabel.hidden = true
        minutesStackView.hidden = true
        startStopButton.hidden = true
        
        setActivityText(activityString)
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
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let textFieldCount = textField.text == nil ? 0 : textField.text!.characters.count
        
        // Sanity check to work around ios bug
        if (range.length + range.location > textFieldCount )
        {
            return false;
        }
        
        let newLength = textFieldCount + string.characters.count - range.length
        return newLength <= 40
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        print("textFieldDidEndEditing: \(activityTextField.text)");
        setActivityText(activityTextField.text)
    }
    
    
    func dataForPopoverInTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        return [
            [ "DisplayText" : "app development", "DisplaySubText" : "last done 3 days ago"  ], [ "DisplayText" : "appreciate art", "DisplaySubText" : "last done 3 days ago"  ],
            [ "DisplayText" : "aid people", "DisplaySubText" : "last done 3 days ago"  ], [ "DisplayText" : "arrest Clinton art", "DisplaySubText" : "last done 3 days ago"  ],
            [ "DisplayText" : "age gracefuly", "DisplaySubText" : "last done 3 days ago"  ], [ "DisplayText" : "add numbers", "DisplaySubText" : "last done 3 days ago"  ],
            [ "DisplayText" : "burn up things", "DisplaySubText" : "last done 3 days ago"  ],
            [ "DisplayText" : "do some work", "DisplaySubText" : "last done 3 days ago" ], [ "DisplayText" : "pretend to work", "DisplaySubText" : "last done 3 days ago"  ], [ "DisplayText" : "jump up and down", "DisplaySubText" : "last done 3 days ago"  ]
        ]
    }
    
    func dataForPopoverInEmptyTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        return [ [ "DisplayText" : "jump up and down" ], [ "DisplayText" : "do some work" ], [ "DisplayText" : "pretend to work" ] ]
    }

    
    func setActivityText(activity: String?) {
        activityString = activity
        activityLabel.text = activityString
        if (activityLabel == nil || activityString!.characters.count == 0) {
            activityLabel.hidden = true
            startStopButton.hidden = true
        }
        else {
            activityLabel.hidden = false
            startStopButton.hidden = false
        }
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
        if doneButton === sender {
            pause()
            
            
            //let minutes = Int(accumulatedTime/60.0)
            var minutes = Int(accumulatedTime/60.0)
            if (minutes < 1) { minutes = 1 }  //!!! FORCE < 60 seconds to 1 min for testing, or we get nil TimeRecord
            
            
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
                let startTimeText = startTimeFormatter.stringFromDate(startTime!)
                startTimeLabel.text = "Started at \(startTimeText)"
                startTimeLabel.hidden = false
                minutesStackView.hidden = false
                print("initial start at \(firstStartTime)")
            }
            activityTextField.hidden = true
            doneButton.enabled = false
            timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("updateTime"), userInfo: nil, repeats: true)
            startStopButton.setTitle("Pause", forState: .Normal)
            self.view.backgroundColor = UIColor.greenColor()
        }
    }
    
    func pause() {
        running = false
        timer?.invalidate()
        updateTime()
        accumulatedTimeLastPause = accumulatedTime
        startStopButton.setTitle("Continue", forState: .Normal)
        activityTextField.hidden = false
        self.view.backgroundColor = UIColor.lightGrayColor()
        
        let timeSinceStart = -(startTime?.timeIntervalSinceNow)!
        print("timeSinceStart: \(timeSinceStart)")
        print("accumulatedTime: + \(accumulatedTime)")
    }
    
    func updateTime() {
        accumulatedTime = accumulatedTimeLastPause - (startTime?.timeIntervalSinceNow)!
        let minutes = Int(floor(accumulatedTime / 60.0))
        minutesLabel.text = "\(minutes)"
        doneButton.enabled = accumulatedTime >= minimumWorkTime
    }
    
}
