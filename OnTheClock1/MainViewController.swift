//
//  MainViewController.swift
//  OnTheClock1
//
//  Created by Work on 8/19/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit
import Parse
import ParseUI

class MainViewController: UIViewController, PFLogInViewControllerDelegate, PFSignUpViewControllerDelegate {
    
    // MARK: Properties
    @IBOutlet weak var startButton: UIButton!

    var databasePath = NSString()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        OnTheClockData.sharedInstance.open()
        
        if (PFUser.currentUser() == nil) {
            let loginController = PFLogInViewController()
            loginController.delegate = self
            self.presentViewController(loginController, animated: true, completion: nil)
        }
        
        createTestButtons()
        
    }

    override func viewDidAppear(animated: Bool) {
        if (PFUser.currentUser() == nil) {
            let loginController = PFLogInViewController()
            loginController.delegate = self
            
            let signUpController = PFSignUpViewController()
            signUpController.delegate = self
            loginController.signUpController = signUpController
            
            self.presentViewController(loginController, animated: true, completion: nil)
        }
        
        createTestButtons()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "workSessionSegue" {
            print("prepareForSegue workSessionSegue")
            let navController = segue.destinationViewController as? UINavigationController
            let workSessionViewController = navController?.topViewController as? WorkSessionViewController
            if let query = Activity.query() {
                query.fromLocalDatastore()
                query.orderByDescending("last")
                do {
                    var recentActivities: [Activity]
                    try recentActivities = (query.findObjects() as! [Activity])
                    workSessionViewController!.recentActivities = recentActivities
                }
                catch {
                    // if something went wrong, just ignore it.   View will have no recent activities
                    // to show in popop
                }
            }
        }
    }
    
    
    @IBAction func unwindToMainView(sender: UIStoryboardSegue) {
        print("unwindToMainView")
        let sourceViewController = sender.sourceViewController as? WorkSessionViewController
        if (sourceViewController != nil) {
            // resyinc and update UI
        }
    }

    // Development experiment functions

    let actions = [
        [ "action": "unpinAll", "text": "Unpin all"],
        [ "action": "syncActions", "text": "Sync actions"],
    ]
    
    func createTestButtons() {

        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
        NSLog("Document Path: %@", documentsPath)
        
        for (i, action) in actions.enumerate() {
            let button   = UIButton(type: UIButtonType.System)
            button.frame = CGRectMake(20, 80.0 + CGFloat(i)*30.0, 220, 30)
            button.backgroundColor = UIColor.greenColor()
            button.setTitle(action["text"], forState: UIControlState.Normal)
            let selector = Selector(action["action"]! + ":")
            button.addTarget(self, action: selector, forControlEvents: UIControlEvents.TouchUpInside)
            self.view.addSubview(button)
        }
        
        
    }
    
    func unpinAll(sender: AnyObject) {
        print("unpinAll");
        PFObject.unpinAllObjectsInBackground().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            if (task.error != nil) {
                print(task.error)
            }
            else {
                print("unpinned all success")
            }
            return nil
        }
    }
    
    func syncActions(sender: AnyObject) {
        print("syncActions");
        DataSync.sharedInstance.syncActivities().continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            print("task done")
            print(task)
            return task
        }
    }
    
    // MARK: PFLogInViewControllerDelegate
    
    func logInViewController(logInController: PFLogInViewController, didLogInUser user: PFUser) {
        print("login with user")
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func logInViewControllerDidCancelLogIn(logInController: PFLogInViewController) {
        print("login cancel")
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func logInViewController(logInController: PFLogInViewController, didFailToLogInWithError error: NSError?) {
        print("login fail")
        //self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: PFSignUpViewControllerDelegate
    
    func signUpViewController(signUpController: PFSignUpViewController, didSignUpUser user: PFUser) {
        print("signup success")
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func signUpViewController(signUpController: PFSignUpViewController, didFailToSignUpWithError error: NSError?) {
        print("signup error")
    }
    
    func signUpViewControllerDidCancelSignUp(signUpController: PFSignUpViewController) {
        print("signup cancel")
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
}

