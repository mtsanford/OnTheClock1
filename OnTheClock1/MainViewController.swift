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
    @IBOutlet weak var historyButton: UIButton!

    let userImage: UIImage! = UIImage(named: "user")?.imageWithRenderingMode(.AlwaysTemplate)
    let signoutImage: UIImage! = UIImage(named: "signout")?.imageWithRenderingMode(.AlwaysTemplate)
    let historyImage: UIImage! = UIImage(named: "history")?.imageWithRenderingMode(.AlwaysTemplate)
    
    var activityString: String?
    var recentActivities: [Activity]?
    var popupData = [Dictionary<String, AnyObject>]()
    var anonUser: PFUser?
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityTextField.delegate = self
        activityTextField.mDelegate = self
        
        /*
        let paddingView = UIView(frame: CGRectMake(0,0,5,self.activityTextField.frame.height))
        activityTextField.leftView = paddingView
        activityTextField.leftViewMode = UITextFieldViewMode.Always
        */
        
        userButton.setImage(userImage, forState: .Normal)
        historyButton.setImage(historyImage, forState: .Normal)
        
        updateRecentItems(true)

        // UIControl.addTarget will get us change events, but only UI initialted.   The Subclass may programatically change the text too,
        // so we'll observe the text property using the NSKeyValueObserving protocol
        activityTextField.addTarget(self, action: "activityTextFieldChanged", forControlEvents: [UIControlEvents.EditingChanged])
        activityTextField.addObserver(self, forKeyPath: "text", options: .New, context: nil)
    }
    
    
    override func viewDidAppear(animated: Bool) {
        setUserButtonImage()
    }
    
    func activityTextFieldChanged() {
        startButton.enabled = activityTextField.text != nil && !activityTextField.text!.isEmpty
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath! == "text" {
            activityTextFieldChanged()
        }
    }
    
    func updateRecentItems(setActivityText: Bool) {
        DataSync.sharedInstance.getRecentActivities().continueWithExecutor(BFExecutor.mainThreadExecutor(), withBlock: {
            (task: BFTask!) -> BFTask! in
            self.recentActivities = task.result as? [Activity]
            self.updatePopupData()
            if (setActivityText) { self.setDefaultActivityText() }
            return nil
        })
    }
    
    func updatePopupData() {
        popupData.removeAll()
        if self.recentActivities != nil && self.recentActivities!.count > 0 {
            for (_, activity) in self.recentActivities!.enumerate() {
                let popupItem = [ "DisplayText" : activity.name, "DisplaySubText" : Utils.agoStringFromDate(activity.last) ]
                self.popupData.append(popupItem)
            }
        }
    }
    
    func setDefaultActivityText() {
        if self.activityTextField.text?.characters.count == 0 {
            var activityString: String = ""
            if self.recentActivities != nil && self.recentActivities!.count > 0 {
                activityString = self.recentActivities![0].name
            }
            self.activityTextField.text = activityString
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "workSessionSegue" {
            let navController = segue.destinationViewController as? UINavigationController
            let workSessionViewController = navController?.topViewController as? WorkSessionViewController
            workSessionViewController?.delegate = self
            workSessionViewController?.activityString = activityTextField.text?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        }
    }
    
    @IBAction func unwindToMainView(sender: UIStoryboardSegue) {
    }

    @IBAction func syncPressed(sender: UIButton) {
        OTCData.syncToParse()
    }
    
    // MARK: WorkSessionControllerDelegate
    func workSessionFinished(workSessionInfo: WorkSessionInfo) {
        
        OTCData.addWorkSession(workSessionInfo)
        
        OTCData.syncToParse()
        return;
        
        /*
        DataSync.sharedInstance.newWorkSession(activityName, start: startTime, duration: duration).continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            // Only sync to parse if the user is logged in
            if (!PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser())) {
                return DataSync.sharedInstance.syncToParse()
            }
            else {
                return nil
            }
        }.continueWithBlock {
            (task: BFTask!) -> AnyObject! in
            self.updateRecentItems(true)
            return nil
        }
        */
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
    }
    
    
    func dataForPopoverInTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        updatePopupData()
        return popupData
    }
    
    func dataForPopoverInEmptyTextField(textfield: MPGTextField) -> [Dictionary<String, AnyObject>]? {
        updatePopupData()
        return popupData
    }
    
    func setUserButtonImage() {
        let newImage: UIImage = PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser()) ? userImage : signoutImage
        userButton.setImage(newImage, forState: .Normal)
    }

    
    @IBAction func userPressed(sender: AnyObject) {
        if (PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser())) {
            let loginController = MyLoginViewController()
            loginController.emailAsUsername = true
            loginController.delegate = self
            
            loginController.signUpController?.emailAsUsername = true
            loginController.signUpController?.delegate = self
            
            // remember who the anonymous user, so that if there is a login, we can convert
            // unsaved data for that user to belong to the new logged in user
            self.anonUser = PFUser.currentUser()
            
            self.presentViewController(loginController, animated: false, completion: nil)
        }
        else {
            let message = "Sign out " + (PFUser.currentUser()?.username)! + "?"
            
            let alert = UIAlertController(title: "Sign out", message: message, preferredStyle: UIAlertControllerStyle.Alert)
            
            // add the actions (buttons)
            alert.addAction(UIAlertAction(title: "Sign out", style: UIAlertActionStyle.Default, handler: {
                alert in
                PFUser.logOut()
                print("Current user after logout: \(PFUser.currentUser()?.objectId)")
                print(PFUser.currentUser())
                self.setUserButtonImage()
                self.activityTextField.text = ""
                self.updateRecentItems(true)
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
        
        print("Current user after login: \(PFUser.currentUser()?.objectId)")
        print(PFUser.currentUser())

        
        DataSync.sharedInstance.convertAnonymousData(self.anonUser!).continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            return DataSync.sharedInstance.syncToParse()
        }.continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            self.updateRecentItems(true)
            return nil
        }
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
        DataSync.sharedInstance.syncToParse().continueWithSuccessBlock {
            (task: BFTask!) -> AnyObject! in
            self.updateRecentItems(true)
            return nil
        }
    }
    
    func signUpViewController(signUpController: PFSignUpViewController, didFailToSignUpWithError error: NSError?) {
        print("signup error")
    }
    
    func signUpViewControllerDidCancelSignUp(signUpController: PFSignUpViewController) {
        print("signup cancel")
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

