//
//  NewWorkSessionViewController.swift
//  OnTheClock1
//
//  Created by Work on 1/9/16.
//  Copyright © 2016 Mark Sanford. All rights reserved.
//

import UIKit

class NewWorkSessionViewController: UIViewController {

    /* User Interface */
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    @IBOutlet weak var activityNameLabel: UILabel!
    
    @IBOutlet weak var hoursLabel: UILabel!
    @IBOutlet weak var minutesLabel: UILabel!
    @IBOutlet weak var colonLabel: UILabel!
    
    @IBOutlet weak var adjustLabel: UILabel!
    @IBOutlet weak var downButton: UIButton!
    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var adjustAmountLabel: UILabel!
    
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
    var accumulatedAdjustedTime = 0.0
    
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

        downButton.setImage(downButtonImage, forState: .Normal)
        downButton.tintColor = self.view.tintColor
        upButton.setImage(upButtonImage, forState: .Normal)
        upButton.tintColor = self.view.tintColor
        
        hoursLabel.font = hoursLabel.font.monospacedDigitFont
        minutesLabel.font = minutesLabel.font.monospacedDigitFont
        
        timeFormatter.positiveFormat = "00"
        
        run(true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func continueSession() {
        if (running == false) {
            running = true
            updateUI()
            startTime = NSDate()
            print("timer started at \(startTime)")
            if firstStartTime === nil  {
                firstStartTime = startTime?.dateByAddingTimeInterval(0.0)
            }
            timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("updateTime"), userInfo: nil, repeats: true)
        }
    }
    
    func updateTime() {
        
        // Use 60.0 for debugging so time goes faster :)
        //accumulatedTime = accumulatedTimeLastPause - (startTime?.timeIntervalSinceNow)!
        accumulatedTime = accumulatedTimeLastPause - ((startTime?.timeIntervalSinceNow)! * 60.0)
        
        accumulatedAdjustedTime = accumulatedTime + adjustTime
        
        updateCounter()
        
        // "blink" colon to indicate time is running
        colonLabel.hidden = !colonLabel.hidden
    }
    
    func updateCounter() {
        let minutes = (floor(accumulatedAdjustedTime / 60) % 60)
        let hours = (floor(accumulatedAdjustedTime / 3600.0) % 100)
        minutesLabel.text = timeFormatter.stringFromNumber(minutes)
        hoursLabel.text = timeFormatter.stringFromNumber(hours)
    }

    func updateUI() {
        if (running) {
            pauseButton.setTitle("Stop", forState: .Normal)
            pauseButton.titleLabel?.font = UIFont.systemFontOfSize(16)
            adjustLabel.hidden = true;
            downButton.hidden = true;
            upButton.hidden = true;
            adjustAmountLabel.hidden = true;
            doneButton.enabled = false
        }
        else {
            colonLabel.hidden = false
            pauseButton.setTitle("Resume", forState: .Normal)
            pauseButton.titleLabel?.font = UIFont.systemFontOfSize(13)
            adjustLabel.hidden = false;
            downButton.hidden = false;
            upButton.hidden = false;
            adjustAmountLabel.hidden = false;
            doneButton.enabled = accumulatedTime >= minimumWorkTime
        }
    }
    
    func run(newRunning: Bool) {
        if (running == newRunning) { return }
        running = newRunning
        if (running) {
            startTime = NSDate()
            print("timer started at \(startTime)")
            if firstStartTime === nil  { firstStartTime = startTime?.dateByAddingTimeInterval(0.0) }
            timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("updateTime"), userInfo: nil, repeats: true)
        }
        else {
            timer?.invalidate()
            
            // don't accumulate fractional seconds, so that colon blinks on when time visibly changes
            accumulatedTime = floor(accumulatedTime)
            accumulatedTimeLastPause = accumulatedTime
            accumulatedAdjustedTime = accumulatedTime + adjustTime
            
            let timeSinceStart = -(startTime?.timeIntervalSinceNow)!
            print("timeSinceStart: \(timeSinceStart)")
            print("accumulatedTime: + \(accumulatedTime)")
        }
        updateUI()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    /* Pause/Resume button */
    
    
    @IBAction func pauseButtonPressed(sender: AnyObject) {
        run(!running)
        updateUI()
    }
    
    @IBAction func downButtonPressed(sender: UIButton) {
        let newAdjustTime = adjustTime - adjustIncrement
        if (accumulatedTime + newAdjustTime >= 0.0 && newAdjustTime > 1000 * -60.0) {
            adjustTime = newAdjustTime
            accumulatedAdjustedTime = accumulatedTime + adjustTime
            updateCounter()
            let minutes = Int(adjustTime / 60.0)
            adjustAmountLabel.text = "\(minutes) minutes"
        }
        else {
            shakeAdjustTime()
        }
    }
    
    @IBAction func upButtonPressed(sender: UIButton) {
        let newAdjustTime = adjustTime + adjustIncrement
        if (newAdjustTime <= 0.0) {
            adjustTime = newAdjustTime
            accumulatedAdjustedTime = accumulatedTime + adjustTime
            updateCounter()
            let minutes = Int(adjustTime / 60.0)
            adjustAmountLabel.text = "\(minutes) minutes"
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
        animation.fromValue = NSValue(CGPoint: CGPointMake(adjustAmountLabel.center.x - 2.0, adjustAmountLabel.center.y))
        animation.toValue = NSValue(CGPoint: CGPointMake(adjustAmountLabel.center.x + 2.0, adjustAmountLabel.center.y))
        adjustAmountLabel.layer.addAnimation(animation, forKey: "position")
    }
    
}
