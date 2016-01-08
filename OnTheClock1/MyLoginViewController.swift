//
//  MyLoginViewController.swift
//  OnTheClock1
//
//  Created by Work on 11/8/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import UIKit
import ParseUI

class MyLoginViewController: PFLogInViewController {

    let cancelImage = UIImage(named: "cancel")?.imageWithRenderingMode(.AlwaysTemplate)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let logo = UILabel()
        
        logo.text = "Small Steps"
        logo.font = UIFont.systemFontOfSize(36)
        logo.textColor = UIColor.OTCDark()
        self.logInView?.logo = logo
        self.fields = [PFLogInFields.Default, PFLogInFields.Facebook, PFLogInFields.Twitter]
        
        self.logInView?.dismissButton?.setImage(cancelImage, forState: .Normal)
        self.logInView?.dismissButton?.tintColor = UIColor.OTCDark()
        
        self.logInView?.tintColor = UIColor.OTCDark()
        
        self.signUpController = MySignUpViewController()
        
    }
    
}
