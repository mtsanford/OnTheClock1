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
        
        logo.text = "Stepnow"
        logo.font = UIFont.systemFontOfSize(36)
        self.logInView?.logo = logo
        self.fields = [PFLogInFields.Default, PFLogInFields.Facebook, PFLogInFields.Twitter]
        
        self.logInView?.dismissButton?.setImage(cancelImage, forState: .Normal)
        
        self.signUpController = MySignUpViewController()
        
    }
    
}
