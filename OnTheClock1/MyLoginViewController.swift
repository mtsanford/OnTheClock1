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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let logo = UILabel()
        
        logo.text = "On the Clock"
        logo.font = UIFont.systemFontOfSize(36)
        self.logInView?.logo = logo

        self.signUpController = MySignUpViewController()
        
    }
    
}
