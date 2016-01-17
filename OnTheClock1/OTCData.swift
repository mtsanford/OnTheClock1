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
    static var synching = false
    
    // synchronous
    static func initDatabase() {
        var sql_stmt: String!
        let filemgr = NSFileManager.defaultManager()
        let dirPaths = filemgr.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        
        let databasePath = dirPaths[0].URLByAppendingPathComponent("smallstep.db").path!
        print(databasePath)

        let dbAlreadyExists = filemgr.fileExistsAtPath(databasePath as String)
        
        dbQueue = FMDatabaseQueue(path: databasePath as String)
        
        if dbAlreadyExists { return }
        
        dbQueue?.inDatabase({ (db) -> Void in
        
            // Anonymous user is specified by empty string ("") for userid
            // parseid is the Parse objectId.
            // parseid == '' means that the record does not have an id in Parse yet
            
            sql_stmt =
                  "CREATE TABLE IF NOT EXISTS activity ("
                + "  id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "  parseid TEXT DEFAULT '', "
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
                + "  parseid TEXT DEFAULT '', "
                + "  userid TEXT NOT NULL, "
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
            
            sql_stmt = "CREATE INDEX parseid_index ON worksession (parseid, userid)"
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
    
    // asynchronously since to parse.   Use NSNotification
    static func syncToParse() {
        let userId = PFUser.currentUser()?.objectId ?? ""
        let defaults = NSUserDefaults.standardUserDefaults()
        let lastSyncDate = defaults.objectForKey("lastSyncDate") as? NSDate ?? NSDate(timeIntervalSince1970: 0.0)
        var newWorkSessions = [NSDictionary]()

        print(lastSyncDate)
        
        if (synching == true) { return }
        synching = true;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            OTCData.dbQueue?.inDatabase({ (db: FMDatabase!) -> Void in
                let needsPushQuery =
                      "SELECT ws.startTime AS startTime, ws.duration AS duration, act.name AS activityName, act.parseid as activityParseId "
                    + "FROM worksession AS ws JOIN activity AS act ON act.id = ws.activityid "
                    + "WHERE ws.userid = ? AND ws.parseid = ''"
                let result = db.executeQuery(needsPushQuery, withArgumentsInArray: [userId])
                if (result == nil) {
                    print("Error: \(db.lastErrorMessage())")
                    OTCData.synching = false
                    return
                }
                while result.next() {
                    var workSession = [
                        "startTime" :  NSDate(timeIntervalSince1970: Double(result.longForColumn("startTime"))),
                        "duration" : result.doubleForColumn("duration"),
                        "activityName" : result.stringForColumn("activityName")
                    ]
                    if result.stringForColumn("activityParseId") == "" {
                        workSession["activityName"] = result.stringForColumn("activityName")
                    }
                    else {
                        workSession["activityId"] = result.stringForColumn("activityParseId")
                    }
                    newWorkSessions.append(workSession)
                }
                
                var parameters = Dictionary<NSObject, AnyObject>()
                parameters["newWorkSessions"] = newWorkSessions
                parameters["lastSyncDate"] = lastSyncDate
                PFCloud.callFunctionInBackground("sync", withParameters: parameters).continueWithBlock {
                    (task: BFTask!) -> AnyObject! in
                    print("sync returned")
                    OTCData.synching = false
                    return nil;
                }
                dispatch_async(dispatch_get_main_queue()) { () -> Void in
                    print(newWorkSessions);
                }
            })
        }
    }

}