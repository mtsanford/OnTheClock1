//
//  WorkSessionViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/20/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class WorkSessionViewController: UIViewController, UITextFieldDelegate, MPGTextFieldDelegate, UINavigationControllerDelegate {
    
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
    var finishing: Bool = false
    let minimumWorkTime = 2.0
    
    var workSession: WorkSession?
    
    //var recentActivities: [OnTheClockActivityRecord]?
    var recentActivities: [Activity]?
    var popupDataAll = [Dictionary<String, AnyObject>]()
    var popupDataRecent = [Dictionary<String, AnyObject>]()
    
    let agoStringSettings: [[String: AnyObject]] = [
            [ "floor" : 0, "unit": 1, "single": "second", "plural": "seconds" ],
            [ "floor" : 60, "unit": 60, "single": "minute", "plural": "minutes" ],
            [ "floor" : 60*60, "unit": 60*60, "single": "hour", "plural": "hours" ],
            [ "floor" : 60*60*24, "unit": 60*60*24, "single": "day", "plural": "days" ],
            [ "floor" : 60*60*24*7, "unit": 60*60*24*7, "single": "week", "plural": "weeks" ],
        ]
    
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
        startStopButton.setTitle("Start", forState: .Normal)
        activityLabel.hidden = true
        startTimeLabel.hidden = true
        minutesStackView.hidden = true
        startStopButton.hidden = true
        
        createPopupItems()
        if recentActivities != nil && recentActivities!.count > 0 {
            activityString = recentActivities![0].name
            setActivityText(activityString)
        }
        activityTextField.text = activityString
    }

    
    func createPopupItems() {
        popupDataAll.removeAll()
        popupDataRecent.removeAll()
        if recentActivities != nil && recentActivities!.count > 0 {
            activityString = recentActivities![0].name
            for (i, activity) in recentActivities!.enumerate() {
                let popupItem = [ "DisplayText" : activity.name, "DisplaySubText" : agoStringFromDate(activity.last) ]
                popupDataAll.append(popupItem)
                if (i < 4) {
                    popupDataRecent.append(popupItem)
                }
            }
        }
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
        if (range.length + range.location > textFieldCount ) {
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
        createPopupItems()
        return popupDataAll
    }
    
    func dataForPopoverInEmptyTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        createPopupItems()
        return popupDataAll
    }

    
    func setActivityText(activity: String?) {
        activityString = activity
        activityLabel.text = activityString
        if (activityString == nil || activityString!.characters.count == 0) {
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
        print("prepareForSegue ")
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
    
    func agoStringFromDate(date: NSDate) -> String {
        var agoString = ""
        let secondsAgo = -date.timeIntervalSinceNow
        for setting in agoStringSettings {
            if secondsAgo > setting["floor"] as! Double {
                let unit = setting["unit"] as! Double
                let units = Int(floor(secondsAgo / unit))
                let unitName = (units >= 2 ? setting["plural"] : setting["single"]) as! String
                agoString = "\(units) \(unitName) ago"
            }
        }
        return agoString
    }
    
}
