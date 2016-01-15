//
//  OTCData.swift
//  OnTheClock1
//
//  Created by Work on 1/14/16.
//  Copyright © 2016 Mark Sanford. All rights reserved.
//

import Foundation

struct ActivityInfo {
    var lastTime: NSDate
    var totalTime: Double
    var name: String
}

struct WorkSessionInfo {
    var startTime: NSDate
    var duration: Double
    var activityName: String
}

class OTCData {
    
    static var dbQueue: FMDatabaseQueue?
    static var currentUserId = 0
    
    // synchronous
    static func initDatabase() {
        var sql_stmt: String!
        let filemgr = NSFileManager.defaultManager()
        let dirPaths = filemgr.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        
        let databasePath = dirPaths[0].URLByAppendingPathComponent("smallstep.db").path!
        print(databasePath)

        if filemgr.fileExistsAtPath(databasePath as String) { return };

        dbQueue = FMDatabaseQueue(path: databasePath as String)
        
        dbQueue?.inDatabase({ (db) -> Void in
        
            // Anonymous user is specified by empty string ("") for userid
            
            sql_stmt =
                  "CREATE TABLE IF NOT EXISTS activity ("
                + "  id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "  parseid TEXT, "
                + "  userid TEXT NOT NULL, "
                + "  name TEXT, "
                + "  lastTime INTEGER, "
                + "  totalTime REAL "
                + ")"
            
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
            }
            
            sql_stmt =
                  "CREATE TABLE IF NOT EXISTS worksession ("
                + "  id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "  parseid TEXT, "
                + "  userid TEXT NOT NULL, "
                + "  needsPush INTEGER DEFAULT 1,"
                + "  activityid INTEGER, "
                + "  startTime INTEGER, "
                + "  duration REAL "
                + ")"

            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
            }

            sql_stmt = "CREATE INDEX start_time_index ON worksession (startTime, userid)"
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
            }
            
            sql_stmt = "CREATE INDEX activity_index ON worksession (activityid, userid)"
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
            }
        
        })
        
    }
    
    //
    //
    static func addWorkSession(newWorkSession: WorkSessionInfo) {
        var activityQueryResult: FMResultSet?
        var activityId: Int!
        let activityName = newWorkSession.activityName.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        let userId = PFUser.currentUser()?.objectId ?? ""
        let startTime = Int(newWorkSession.startTime.timeIntervalSince1970)

        dbQueue?.inTransaction({ (db, rollback) -> Void in
            
            // See if there is an existing activity with the given activity name
            activityQueryResult = db.executeQuery("SELECT * FROM activity WHERE name = ? AND userid = ?", withArgumentsInArray: [activityName, userId])
            if (activityQueryResult == nil) {
                rollback.initialize(true)
                print("Error: \(db.lastErrorMessage())")
                return;
            }
            
            print("did activity query")
            
            // if there is, we can use it, and update it's lastTime
            if activityQueryResult?.next() == true {
                activityId = activityQueryResult?.longForColumn("id")
                let updateActivityQuery = "UPDATE activity SET lastTime = ? WHERE id = ?"
                if !db.executeUpdate(updateActivityQuery, withArgumentsInArray: [startTime, activityId]) {
                    rollback.initialize(true)
                    print("Error: \(db.lastErrorMessage())")
                    return;
                }
            }
                
            // otherwise we'll need to create a new activity
            else {
                let insertActivityQuery = "INSERT INTO activity (userid, name, lastTime, totalTime) VALUES (?, ?, ?, ?)"
                if !db.executeUpdate(insertActivityQuery, withArgumentsInArray: [userId, activityName, startTime, newWorkSession.duration]) {
                    rollback.initialize(true)
                    print("Error: \(db.lastErrorMessage())")
                    return;
                }
                activityId = Int(db.lastInsertRowId())
                print("did activity insert")
            }
            
            // now we can create the new work session
            let insertWorkSessionQuery = "INSERT INTO worksession (userid, activityid, startTime, duration) VALUES (?, ?, ?, ?)"
            if !db.executeUpdate(insertWorkSessionQuery, withArgumentsInArray: [userId, activityId, startTime, newWorkSession.duration]) {
                rollback.initialize(true)
                print("Error: \(db.lastErrorMessage())")
                return;
            }
            print("did worksession insert")

            rollback.initialize(false)
        })

        
    }
    
}