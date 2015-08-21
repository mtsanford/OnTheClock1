//
//  TimeRecordViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/20/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit

class TimeRecordViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var timeWorkedLabel: UILabel!

    var timer: NSTimer?
    var startTime: NSDate?
    var running: Bool = false
    
    var timeRecord = TimeRecord?()

    required init?(coder aDecoder: NSCoder) {
        self.timer = nil
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation
    @IBAction func cancel(sender: UIBarButtonItem) {
        if running {
            // If the timer is running, ask user to confirm cancel
            let refreshAlert = UIAlertController(title: "Cancel work?", message: "You are currently on the clock.  Cancel and loose this record?", preferredStyle: UIAlertControllerStyle.Alert)
            
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
        if cancelButton === sender {
            
        }
    }

    @IBAction func startStopPressed(sender: UIButton) {
        if running {
            running = false
            timer?.invalidate()
            startStopButton.setTitle("Start", forState: .Normal)
            doneButton.enabled = true
        }
        else {
            running = true
            startTime = NSDate()
            let startTimeFormatter = NSDateFormatter()
            startTimeFormatter.dateFormat = "h:mm a"
            startTimeLabel.text = startTimeFormatter.stringFromDate(startTime!)
            print("started at \(startTime)")
            timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("timerTick"), userInfo: nil, repeats: true)
            startStopButton.setTitle("Stop", forState: .Normal)
        }
    }
    
    func timerTick() {
        print("got a tick")
    }
    
}
