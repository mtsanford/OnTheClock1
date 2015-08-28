//
//  OnTheClockData.swift
//  OnTheClock1
//
//  Created by Work on 8/28/15.
//  Copyright © 2015 Mark Sanford. All rights reserved.
//

import Foundation


class OnTheClockData {
    static var sharedInstance = OnTheClockData()
    
    var databasePath: String = ""
    var db: FMDatabase?
    
    init() {
        
    }
    
    func open() {
        if db != nil { return }
        
        let filemgr = NSFileManager.defaultManager()
        let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        
        let docsDir = dirPaths[0]
        
        databasePath = (docsDir as NSString).stringByAppendingPathComponent("ontheclock.db") as String
        
        if !filemgr.fileExistsAtPath(databasePath) {
            
            let contactDB = FMDatabase(path: databasePath)
            
            if contactDB == nil {
                print("Error: \(contactDB.lastErrorMessage())")
            }
            
            if contactDB.open() {
                let create_worksessions = "CREATE TABLE IF NOT EXISTS WORKSESSIONS (ID INTEGER PRIMARY KEY AUTOINCREMENT, START INTEGER, ACTIVITY VARCHAR(255), MINUTES INTEGER)"
                if !contactDB.executeStatements(create_worksessions) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                let create_worksessions_index1 = "CREATE INDEX IF NOT EXISTS WORKSESSION_ACTIVITY ON WORKSESSIONS (ACTIVITY)"
                if !contactDB.executeStatements(create_worksessions_index1) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                let create_worksessions_index2 = "CREATE INDEX IF NOT EXISTS WORKSESSION_START ON WORKSESSIONS (START)"
                if !contactDB.executeStatements(create_worksessions_index2) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                
                let create_activites = "CREATE TABLE IF NOT EXISTS ACTIVITES (ID INTEGER PRIMARY KEY AUTOINCREMENT, ACTIVITY VARCHAR(255), LASTUSED INTEGER)"
                if !contactDB.executeStatements(create_activites) {
                    print("Error: \(contactDB.lastErrorMessage())")
                }
                contactDB.close()
            } else {
                print("Error: \(contactDB.lastErrorMessage())")
            }
        }
        
    }
    
    func sleep() {
        if db != nil {
            db!.close()
            db = nil
        }
    }

}
