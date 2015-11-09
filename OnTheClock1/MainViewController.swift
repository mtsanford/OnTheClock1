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

class MainViewController: UIViewController, PFLogInViewControllerDelegate, PFSignUpViewControllerDelegate, UITextFieldDelegate, MPGTextFieldDelegate, WorkSessionControllerDelegate {
    
    // MARK: Properties
    @IBOutlet weak var activityTextField: MPGTextField!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var userButton: UIButton!

    
    var activityString: String?
    var recentActivities: [Activity]?
    var popupDataAll = [Dictionary<String, AnyObject>]()
    var popupDataRecent = [Dictionary<String, AnyObject>]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityTextField.delegate = self
        activityTextField.mDelegate = self
        
        createPopupItems()
        if recentActivities != nil && recentActivities!.count > 0 {
            activityString = recentActivities![0].name
        }
        activityTextField.text = activityString
    }
    
    override func viewDidAppear(animated: Bool) {
        setUserButtonImage()
    }
    
    func createPopupItems() {
        popupDataAll.removeAll()
        popupDataRecent.removeAll()
        if let query = Activity.query() {
            query.fromLocalDatastore()
            query.whereKey("user", equalTo: PFUser.currentUser()!)
            query.orderByDescending("last")
            do {
                var recentActivities: [Activity]
                try recentActivities = (query.findObjects() as! [Activity])
                self.recentActivities = recentActivities
            }
            catch {
                // if something went wrong, just ignore it.   View will have no recent activities
                // to show in popop
            }
        }
        if recentActivities != nil && recentActivities!.count > 0 {
            activityString = recentActivities![0].name
            for (i, activity) in recentActivities!.enumerate() {
                let popupItem = [ "DisplayText" : activity.name, "DisplaySubText" : Utils.agoStringFromDate(activity.last) ]
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

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "workSessionSegue" {
            print("prepareForSegue workSessionSegue")
            let navController = segue.destinationViewController as? UINavigationController
            let workSessionViewController = navController?.topViewController as? WorkSessionViewController
            workSessionViewController?.delegate = self
            workSessionViewController?.activityString = activityTextField.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
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

    // MARK: WorkSessionControllerDelegate
    func workSessionFinished(activityName: String, startTime: NSDate, duration: NSNumber) {
        print("workSessionFinished");
        print(activityName)
        print(startTime)
        print(duration)
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
        //setActivityText(activityTextField.text)
    }
    
    
    func dataForPopoverInTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        createPopupItems()
        return popupDataAll
    }
    
    func dataForPopoverInEmptyTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        createPopupItems()
        return popupDataAll
    }
    
    func setUserButtonImage() {
        var userImage: UIImage!
        if (PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser())) {
            userImage = UIImage(named: "user.png")
        }
        else {
            userImage = UIImage(named: "signout.png")
        }
        userButton.setImage(userImage, forState: .Normal)
    }

    
    @IBAction func userPressed(sender: AnyObject) {
        if (PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser())) {
            let loginController = MyLoginViewController()
            loginController.emailAsUsername = true
            loginController.delegate = self
            
            loginController.signUpController?.emailAsUsername = true
            loginController.signUpController?.delegate = self
            
            self.presentViewController(loginController, animated: false, completion: nil)
        }
        else {
            let message = "Sign out " + (PFUser.currentUser()?.username)! + "?"
            
            let alert = UIAlertController(title: "Sign out", message: message, preferredStyle: UIAlertControllerStyle.Alert)
            
            // add the actions (buttons)
            alert.addAction(UIAlertAction(title: "Sign out", style: UIAlertActionStyle.Default, handler: {
                alert in
                PFUser.logOut()
                print("sign out pressed. user is now:")
                print(PFUser.currentUser())
                self.setUserButtonImage()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
            
            // show the alert
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: PFLogInViewControllerDelegate
    
    func logInViewController(logInController: PFLogInViewController, didLogInUser user: PFUser) {
        print("login with user")
        self.dismissViewControllerAnimated(true, completion: nil)
        setUserButtonImage()
    }
    
    func logInViewControllerDidCancelLogIn(logInController: PFLogInViewController) {
        print("login cancel")
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func logInViewController(logInController: PFLogInViewController, didFailToLogInWithError error: NSError?) {
        print("login fail")
    }
    
    // MARK: PFSignUpViewControllerDelegate
    
    func signUpViewController(signUpController: PFSignUpViewController, didSignUpUser user: PFUser) {
        print("signup success")
        setUserButtonImage()
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func signUpViewController(signUpController: PFSignUpViewController, didFailToSignUpWithError error: NSError?) {
        print("signup error")
    }
    
    func signUpViewControllerDidCancelSignUp(signUpController: PFSignUpViewController) {
        print("signup cancel")
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

