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
        dismissViewControllerAnimated(true, completion: nil)
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if cancelButton === sender {
            
        }
    }

}
