//
//  WorkSessionViewController.swift
//  OnTheClock1
//
//  Created by Work on 1/9/16.
//  Copyright © 2016 Mark Sanford. All rights reserved.
//

import UIKit

protocol WorkSessionControllerDelegate: class {
    func workSessionFinished(workSessionInfo: WorkSessionInfo)
}


class WorkSessionViewController: UIViewController {

    /* THESE SHOULD BE SET BY CREATOR */
    
    var activityString: String?
    weak var delegate: WorkSessionControllerDelegate?
    
    /* User Interface */
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    @IBOutlet weak var activityNameLabel: UILabel!
    
    @IBOutlet weak var counterLabel: UILabel!
    @IBOutlet weak var counterCover: UIView!
    
    @IBOutlet weak var adjustLabel: UILabel!
    @IBOutlet weak var downButton: UIButton!
    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var adjustAmountLabel: UILabel!
    
    @IBOutlet weak var minimumLabel: UILabel!
    
    @IBOutlet weak var pauseButton: UIButton!
    
    let downButtonImage: UIImage! = UIImage(named: "left-arrow")?.imageWithRenderingMode(.AlwaysTemplate)
    let upButtonImage: UIImage! = UIImage(named: "right-arrow")?.imageWithRenderingMode(.AlwaysTemplate)
    
    /* State */
    
    var timer: NSTimer? = nil
    var startTime: NSDate?
    var firstStartTime: NSDate?
    var accumulatedTimeLastPause: NSTimeInterval = 0.0
    var accumulatedTime: NSTimeInterval = 0.0
    var adjustTime: NSTimeInterval = 0.0
    var accumulatedAdjustedTime: NSTimeInterval {
        get {
            return accumulatedTime + adjustTime
        }
    }
    
    var running: Bool = false
    var finishing: Bool = false
    let minimumWorkTime = 300.0
    let adjustIncrement = 300.0
    
    let timeFormatter = NSNumberFormatter()

    
    
    /*
    // TODO: Does this need to be implemented correctly?
    // could be "freeze dried" if put into background?
    required init?(coder aDecoder: NSCoder) {
        self.timer = nil
        self.accumulatedTime = 0.0
        self.accumulatedTimeLastPause = 0.0
        super.init(coder: aDecoder)
    }
    */
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityNameLabel.text = activityString
        downButton.setImage(downButtonImage, forState: .Normal)
        downButton.tintColor = self.view.tintColor
        upButton.setImage(upButtonImage, forState: .Normal)
        upButton.tintColor = self.view.tintColor
        
        counterLabel.font = counterLabel.font.monospacedDigitFont
        
        timeFormatter.positiveFormat = "00"
        
        run(true)
        changeAdjustTime(0.0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func run(newRunning: Bool) {
        if (running == newRunning) { return }
        running = newRunning
        if (running) {
            startTime = NSDate()
            if firstStartTime === nil  { firstStartTime = startTime?.dateByAddingTimeInterval(0.0) }
            timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("updateTime"), userInfo: nil, repeats: true)
            pauseButton.setTitle("Stop", forState: .Normal)
            pauseButton.titleLabel?.font = UIFont.systemFontOfSize(16)
            adjustLabel.hidden = true;
            downButton.hidden = true;
            upButton.hidden = true;
            adjustAmountLabel.hidden = true;
            minimumLabel.hidden = true;
        }
        else {
            timer?.invalidate()
            
            // don't accumulate fractional seconds, so that colon blinks on when time visibly changes
            accumulatedTime = floor(accumulatedTime)
            accumulatedTimeLastPause = accumulatedTime
            
            counterCover.hidden = true
            pauseButton.setTitle("Resume", forState: .Normal)
            pauseButton.titleLabel?.font = UIFont.systemFontOfSize(13)
            if (accumulatedTime >= minimumWorkTime) {
                adjustLabel.hidden = false;
                downButton.hidden = false;
                upButton.hidden = false;
                adjustAmountLabel.hidden = false;
            }
            else {
                minimumLabel.hidden = false;
            }
        }
        updateDoneButton()
    }
    
    func updateTime() {
        // Use 60.0 for debugging so time goes faster :)
        //accumulatedTime = accumulatedTimeLastPause - (startTime?.timeIntervalSinceNow)!
        accumulatedTime = accumulatedTimeLastPause - ((startTime?.timeIntervalSinceNow)! * 300.0)
        
        updateCounter()
        
        // "blink" colon to indicate time is running
        counterCover.hidden = !counterCover.hidden
    }
    
    func updateCounter() {
        let minutes = (floor(accumulatedAdjustedTime / 60) % 60)
        let hours = (floor(accumulatedAdjustedTime / 3600.0) % 100)
        let minutesString = timeFormatter.stringFromNumber(minutes)!
        let hoursString = timeFormatter.stringFromNumber(hours)!
        
        counterLabel.text = "\(hoursString):\(minutesString)"
    }
    
    func updateDoneButton() {
        doneButton.enabled = !running && accumulatedAdjustedTime >= minimumWorkTime
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let btn = sender as? UIBarButtonItem {
            if btn == doneButton {
                let workSessionInfo = WorkSessionInfo(
                    activityName: activityString!,
                    startTime: startTime!,
                    duration: accumulatedAdjustedTime,
                    adjustment: adjustTime
                )
                delegate?.workSessionFinished(workSessionInfo)
            }
        }
    }

    @IBAction func cancelPressed(sender: UIBarButtonItem) {
        func cancelWorkSession() {
            self.run(false)
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        if accumulatedTime >= minimumWorkTime {
            let refreshAlert = UIAlertController(title: "Cancel work?", message: "Cancel and forget about this work session?", preferredStyle: UIAlertControllerStyle.Alert)
            refreshAlert.addAction(UIAlertAction(title: "Confirm cancel", style: .Default, handler: { (action: UIAlertAction!) in cancelWorkSession() }))
            refreshAlert.addAction(UIAlertAction(title: "Keep working", style: .Default, handler: nil))
            presentViewController(refreshAlert, animated: true, completion: nil)
        }
        else {
            cancelWorkSession()
        }
    }
    
    /* Pause/Resume button */
    
    
    @IBAction func pauseButtonPressed(sender: AnyObject) {
        run(!running)
    }
    
    //
    //  MARK: - Adjust time
    
    @IBAction func downButtonPressed(sender: UIButton) {
        changeAdjustTime(adjustTime - adjustIncrement)
    }
    
    @IBAction func upButtonPressed(sender: UIButton) {
        changeAdjustTime(adjustTime + adjustIncrement)
    }
    
    func changeAdjustTime(newAdjustTime: NSTimeInterval) {
        if (newAdjustTime <= 0.0 && accumulatedTime + newAdjustTime >= 0.0 && newAdjustTime > 1000 * -60.0) {
            adjustTime = newAdjustTime
            updateCounter()
            let minutes = Int(adjustTime / 60.0)
            adjustAmountLabel.text = "\(minutes) minutes"
            updateDoneButton()
        }
        else {
            shakeAdjustTime()
        }
    }
    
    func shakeAdjustTime() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = 0.04
        animation.repeatCount = 5
        animation.autoreverses = true
        animation.fromValue = NSValue(CGPoint: CGPointMake(counterLabel.center.x - 4.0, counterLabel.center.y))
        animation.toValue = NSValue(CGPoint: CGPointMake(counterLabel.center.x + 4.0, counterLabel.center.y))
        counterLabel.layer.addAnimation(animation, forKey: "position")
    }
    
}
