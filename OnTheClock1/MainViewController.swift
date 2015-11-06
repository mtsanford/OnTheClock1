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
    
    // present login view if user has not logged in, but allow them to use without
    // loggint in
    var checkedLogin = false
    
    override func viewDidLoad() {
        super.viewDidLoad()        
    }

    override func viewDidAppear(animated: Bool) {
        if (PFUser.currentUser() == nil && self.checkedLogin == false) {
            let loginController = PFLogInViewController()
            loginController.delegate = self
            
            let signUpController = PFSignUpViewController()
            signUpController.delegate = self
            loginController.signUpController = signUpController
            
            self.presentViewController(loginController, animated: true, completion: nil)
        }
        
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
                query.whereKey("user", equalTo: PFUser.currentUser()!)
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
        if segue.identifier == "debugSegue" {
            print("prepareForSegue debugSegue")
        }
    }
    
    
    @IBAction func unwindToMainView(sender: UIStoryboardSegue) {
        print("unwindToMainView")
        let sourceViewController = sender.sourceViewController as? WorkSessionViewController
        if (sourceViewController != nil) {
            // resyinc and update UI
        }
    }

    // MARK: PFLogInViewControllerDelegate
    
    func logInViewController(logInController: PFLogInViewController, didLogInUser user: PFUser) {
        self.checkedLogin = true
        print("login with user")
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func logInViewControllerDidCancelLogIn(logInController: PFLogInViewController) {
        self.checkedLogin = true
        print("login cancel")
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func logInViewController(logInController: PFLogInViewController, didFailToLogInWithError error: NSError?) {
        self.checkedLogin = true
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

