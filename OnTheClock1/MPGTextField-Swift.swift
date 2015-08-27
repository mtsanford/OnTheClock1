//
//  MPGTextField-Swift.swift
//  MPGTextField-Swift
//
//  Created by Gaurav Wadhwani on 08/06/14.
//  Copyright (c) 2014 Mappgic. All rights reserved.
//

import UIKit

@objc protocol MPGTextFieldDelegate{
    // Data for autocomplete, using letters in "DisplayText"
    func dataForPopoverInTextField(textfield: MPGTextField_Swift) -> [Dictionary<String, AnyObject>]?

    // Popup options to show when there is no text shown
    optional func dataForPopoverInEmptyTextField(textfield: MPGTextField_Swift) -> [Dictionary<String, AnyObject>]?
    
    optional func textFieldDidEndEditing(textField: MPGTextField_Swift, withSelection data: Dictionary<String,AnyObject>)
    optional func textFieldShouldSelect(textField: MPGTextField_Swift) -> Bool
}

class MPGTextField_Swift: UITextField, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    
    // TODO: mDelegate is separate from delegate.  Is there anyway to repurpose the UITextField::delegate?
    var mDelegate : MPGTextFieldDelegate?
    var tableViewController : UITableViewController?
    var data : [Dictionary<String, AnyObject>]?
    
    //Set this to override the default color of suggestions popover. The default color is [UIColor colorWithWhite:0.8 alpha:0.9]
    @IBInspectable var popoverBackgroundColor : UIColor = UIColor(red: 240.0/255.0, green: 240.0/255.0, blue: 240.0/255.0, alpha: 1.0)
    
    //Set this to override the default frame of the suggestions popover that will contain the suggestions pertaining to the search query. The default frame will be of the same width as textfield, of height 200px and be just below the textfield.
    @IBInspectable var popoverSize : CGRect?
    
    //Set this to override the default seperator color for tableView in search results. The default color is light gray.
    @IBInspectable var seperatorColor : UIColor = UIColor(white: 0.95, alpha: 1.0)


    override init(frame: CGRect) {
        super.init(frame: frame)
        // Initialization code
    }
    
    required init?(coder aDecoder: NSCoder){
        super.init(coder: aDecoder)
    }

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect)
    {
        // Drawing code
    }
    */
    
    
    // TODO handle case where it's reopened while fading, or visa versa!
    func closeTableView() {
        if let table = self.tableViewController {
            UIView.animateWithDuration(0.3,
                animations: ({
                    self.tableViewController!.tableView.alpha = 0.0
                }),
                completion:{
                    (finished : Bool) in
                    if table.tableView.superview != nil {
                        table.tableView.removeFromSuperview()
                    }
                    self.tableViewController = nil
            })
        }
    }
    
    override func layoutSubviews(){
        super.layoutSubviews()
        
        let str: String? = self.text
        
        if !self.isFirstResponder() || mDelegate == nil {
            closeTableView()
            data = nil
        }
        else if (str != nil && str!.characters.count > 0) {
            let fullData = mDelegate!.dataForPopoverInTextField(self)
            data = self.applyFilterWithSearchQuery(fullData, filter: str!)
            self.provideSuggestions()
        }
        else {
            data = mDelegate!.dataForPopoverInEmptyTextField?(self)
            self.provideSuggestions()
        }
        
    }
    
    override func resignFirstResponder() -> Bool {
        closeTableView()
        handleExit()
        return super.resignFirstResponder()
    }
    
    func provideSuggestions() {
        if data == nil || data!.count == 0 {
            closeTableView()
        }
        else if self.tableViewController != nil {
            tableViewController!.tableView.reloadData()
        }
        else {
            //Add a tap gesture recogniser to dismiss the suggestions view when the user taps outside the suggestions view
            let tapRecognizer = UITapGestureRecognizer(target: self, action: "tapped:")
            tapRecognizer.numberOfTapsRequired = 1
            tapRecognizer.cancelsTouchesInView = false
            tapRecognizer.delegate = self
            self.superview!.addGestureRecognizer(tapRecognizer)

            self.tableViewController = UITableViewController()
            self.tableViewController!.tableView.delegate = self
            self.tableViewController!.tableView.dataSource = self
            self.tableViewController!.tableView.backgroundColor = self.popoverBackgroundColor
            self.tableViewController!.tableView.separatorColor = self.seperatorColor
            if let frameSize = self.popoverSize{
                self.tableViewController!.tableView.frame = frameSize
            }
            else{
                //PopoverSize frame has not been set. Use default parameters instead.
                var frameForPresentation = self.frame
                frameForPresentation.origin.y += self.frame.size.height
                frameForPresentation.size.height = 200
                self.tableViewController!.tableView.frame = frameForPresentation
            }
            
            var frameForPresentation = self.frame
            frameForPresentation.origin.y += self.frame.size.height;
            frameForPresentation.size.height = 200;
            tableViewController!.tableView.frame = frameForPresentation
            
            self.superview!.addSubview(tableViewController!.tableView)
            self.tableViewController!.tableView.alpha = 0.0
            UIView.animateWithDuration(0.3,
                animations: ({
                    self.tableViewController!.tableView.alpha = 1.0
                    }),
                completion:{
                    (finished : Bool) in
                    
                })
        }
        
    }
    
    func tapped (sender : UIGestureRecognizer!){
        if let table = self.tableViewController{
            if !CGRectContainsPoint(table.tableView.frame, sender.locationInView(self.superview)) && self.isFirstResponder(){
                self.resignFirstResponder()
            }
        }
    }
    
    // how many table rows?
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data == nil ? 0 : data!.count
    }
    
    // get the row for an index
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("MPGResultsCell")
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "MPGResultsCell")
        }

        cell!.backgroundColor = UIColor.clearColor()
        let dataForRowAtIndexPath = data![indexPath.row]
        let displayText : AnyObject? = dataForRowAtIndexPath["DisplayText"]
        let displaySubText : AnyObject? = dataForRowAtIndexPath["DisplaySubText"]
        cell!.textLabel!.text = displayText as? String
        cell!.detailTextLabel!.text = displaySubText as? String
        
        return cell!
    }
    
    // row selected
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.text = data![indexPath.row]["DisplayText"] as? String
        self.resignFirstResponder()
    }
    
    
//   #pragma mark Filter Method
    
    func applyFilterWithSearchQuery(allData: [Dictionary<String, AnyObject>]?, filter : String) -> [Dictionary<String, AnyObject>]
    {
        let filteredData = allData!.filter({
                if let match : AnyObject  = $0["DisplayText"] {
                    return (match as! NSString).lowercaseString.hasPrefix((filter as NSString).lowercaseString)
                }
                else {
                    return false
                }
            })
        return filteredData
    }
    
    func handleExit(){
        if let table = self.tableViewController{
            table.tableView.removeFromSuperview()
        }
        
        /* this is hot steaming mess
        if mDelegate != nil && mDelegate!.textFieldShouldSelect != nil && mDelegate!.textFieldShouldSelect!(self) {
            //if self.applyFilterWithSearchQuery(self.text!).count > 0 {
            if data!.count > 0 {
                let selectedData = self.applyFilterWithSearchQuery(self.text!)[0]
                let displayText : AnyObject? = selectedData["DisplayText"]
                self.text = displayText as? String
                mDelegate?.textFieldDidEndEditing?(self, withSelection: selectedData)
            }
            else{
                mDelegate?.textFieldDidEndEditing?(self, withSelection: ["DisplayText":self.text!, "CustomObject":"NEW"])
            }
        }
        */

    }

}
