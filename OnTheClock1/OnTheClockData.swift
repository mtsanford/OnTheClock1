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
    
    var db: FMDatabase!
    
    init() {
        
    }
    
    func open() -> Bool {
        if db != nil { return true }
        
        let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let docsDir = dirPaths[0]
        let databasePath = (docsDir as NSString).stringByAppendingPathComponent("ontheclock.db") as String
        
        /*
        let filemgr = NSFileManager.defaultManager()
        if filemgr.fileExistsAtPath(databasePath) {
            return;
        }
        */
            
        db = FMDatabase(path: databasePath)
        
        if db == nil {
            log("Error: \(db.lastErrorMessage())")
            return false
        }
        
        if !db.open() {
            log("Error: \(db.lastErrorMessage())")
            db = nil
            return false;
        }

        let create_activites    = "CREATE TABLE IF NOT EXISTS ACTIVITIES"
                                + " ("
                                + "     ACTIVITYID      INTEGER PRIMARY KEY AUTOINCREMENT,"
                                + "     ACTIVITYNAME    TEXT,"
                                + "     LASTUSED        INTEGER,"   // seconds since 1970
                                + "     SYNCED          INTEGER"    // synched to cloud data store?
                                + " );"
        
        if !db.executeStatements(create_activites) {
            log("Error: \(db.lastErrorMessage())")
        }
        
        let create_worksessions = "CREATE TABLE IF NOT EXISTS WORKSESSIONS"
                                + " ("
                                + "     WORKSESSIONID   INTEGER PRIMARY KEY AUTOINCREMENT,"
                                + "     START           INTEGER,"   // seconds since 1970
                                + "     ACTIVITYID      INTEGER,"   // References ACTIVITIES table
                                + "     MINUTES         INTEGER,"   // minutes worked
                                + "     SYNCED          INTEGER"    // synched to cloud data store?
                                + " );"
        
        if !db.executeStatements(create_worksessions) {
            log("Error: \(db.lastErrorMessage())")
        }
        
        let create_worksessions_index1 = "CREATE INDEX IF NOT EXISTS WORKSESSION_ACTIVITY ON WORKSESSIONS (ACTIVITY);"
        if !db.executeStatements(create_worksessions_index1) {
            log("Error: \(db.lastErrorMessage())")
        }
        
        let create_worksessions_index2 = "CREATE INDEX IF NOT EXISTS WORKSESSION_START ON WORKSESSIONS (START);"
        if !db.executeStatements(create_worksessions_index2) {
            log("Error: \(db.lastErrorMessage())")
        }
        
        let create_worksessions_index3 = "CREATE INDEX IF NOT EXISTS WORKSESSION_SYNCHED ON WORKSESSIONS (SYNCED);"
        if !db.executeStatements(create_worksessions_index3) {
            log("Error: \(db.lastErrorMessage())")
        }
                
        return true
        
    }
    
    
    
    func sleep() {
        if db != nil {
            db!.close()
            db = nil
        }
    }
    
    func sync() {
        
    }
    
    
    func addWorkSession(record: TimeRecord) {
        
        if !open() { return }

        let start = Int64(record.start.timeIntervalSince1970)
        var result: Bool?
        var results:FMResultSet?
        var activityID: Int64 = 0
        
        // if a timerecord already exists with this time, do nothing, otherwise insert it, and update ACTIVITES
        let query_worksession_exists = "SELECT * FROM WORKSESSIONS WHERE START = \(start)"
        results = db!.executeQuery(query_worksession_exists, withArgumentsInArray: nil)
        let query_worksession_exists_results = results?.next()
        if query_worksession_exists_results == nil || query_worksession_exists_results! == true {
            return;
        }
        
        result = db.executeUpdate("BEGIN TRANSACTION", withArgumentsInArray: nil)
        if (result == nil || result! == false) { return }
        
        //====  first update or create the activity
        let query_actities = "SELECT ACTIVITYID FROM ACTIVITIES WHERE ACTIVITYNAME = '\(record.activity)';"
        results =  db.executeQuery(query_actities, withArgumentsInArray: nil)
        if results == nil {
            log(db.lastErrorMessage())
            db.executeUpdate("ROLLBACK", withArgumentsInArray: nil)
            return;
        }
        
        if results!.next() {
            activityID = Int64(results!.longForColumnIndex(0))
            let update_acivity    = "UPDATE ACTIVITIES SET SYNCED = 0, LASTUSED = \(start)"
            
            result = db.executeUpdate(update_acivity, withArgumentsInArray: nil)
            if (result == nil || result! == false) {
                log(db.lastErrorMessage())
                db.executeUpdate("ROLLBACK", withArgumentsInArray: nil)
                return
            }
        }
        else {
            let insert_acivity    = "INSERT INTO ACTIVITIES (ACTIVITYNAME, LASTUSED, SYNCED) VALUES"
                + " ('\(record.activity)', \(start), 0)"
            
            result = db.executeUpdate(insert_acivity, withArgumentsInArray: nil)
            if (result == nil || result! == false) {
                log(db.lastErrorMessage())
                db.executeUpdate("ROLLBACK", withArgumentsInArray: nil)
                return
            }
            activityID = db.lastInsertRowId() as Int64
        }
        
        let insert_worksession  = "INSERT INTO WORKSESSIONS (START, ACTIVITYID, MINUTES, SYNCED) VALUES "
                                + "(\(start), \(activityID), \(record.duration), 0)"
        
        result = db.executeUpdate(insert_worksession, withArgumentsInArray: nil)
        if (result == nil || result! == false) {
            log(db.lastErrorMessage())
            db.executeUpdate("ROLLBACK", withArgumentsInArray: nil)
            return
        }

        db.executeUpdate("END TRANSACTION", withArgumentsInArray: nil)
    
    }
    
    
    func log(logMessage: String) {
        print(logMessage)
    }

}
