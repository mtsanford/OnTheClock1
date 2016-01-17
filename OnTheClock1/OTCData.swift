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

// Mights as well keep the adjustment info.   Could decide to support changing it later.
struct WorkSessionInfo {
    var activityName: String
    var startTime: NSDate
    var duration: Double
    var adjustment: Double
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
            // parseid == NULL means that the record does not have an id in Parse yet
            
            sql_stmt =
                  "CREATE TABLE IF NOT EXISTS activity ("
                + "  id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "  parseid TEXT DEFAULT NULL, "
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
                + "  parseid TEXT DEFAULT NULL, "
                + "  userid TEXT NOT NULL, "
                + "  activityid INTEGER, "
                + "  startTime INTEGER, "
                + "  duration REAL, "
                + "  adjustment REAL "
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
            let insertWorkSessionQuery = "INSERT INTO worksession (userid, activityid, startTime, duration, adjustment) VALUES (?, ?, ?, ?, ?)"
            if !db.executeUpdate(insertWorkSessionQuery, withArgumentsInArray: [userId, activityId, startTime, newWorkSession.duration, newWorkSession.adjustment]) {
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
                      "SELECT ws.startTime AS startTime, ws.duration AS duration, ws.adjustment as adjustment, act.name AS activityName, act.parseid as activityParseId "
                    + "FROM worksession AS ws JOIN activity AS act ON act.id = ws.activityid "
                    + "WHERE ws.userid = ? AND ws.parseid IS NULL"
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
                        "adjustment": result.doubleForColumn("adjustment"),
                    ]
                    if result.columnIsNull("activityParseId") {
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
                
                PFCloud.callFunctionInBackground("sync", withParameters: parameters).continueWithSuccessBlock {
                    (task: BFTask!) -> AnyObject! in
                    print(task.result)
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                        var syncResult = task.result as! Dictionary<String, AnyObject>
                        
                        // We're being handed proper new Parse objects, so go ahead and delete any provisional data
                        db.executeUpdate("DELETE FROM activity WHERE parseid IS NULL", withArgumentsInArray: nil)
                        db.executeUpdate("DELETE FROM worksession WHERE parseid IS NULL", withArgumentsInArray: nil)
                        
                        let activities = syncResult["activities"] as! Array<Dictionary<String,AnyObject>>
                        for activity in activities {
                            print("processing \(activity["id"])")
                            let parseId = activity["id"]!
                            let lastTime = Int(activity["last"]!.timeIntervalSince1970)
                            let totalTime = activity["total"]!
                            let name = activity["name"]!
                            
                            let existingActivityQuery = "SELECT id FROM activity WHERE parseid = ?"
                            let queryResult = db.executeQuery(existingActivityQuery, withArgumentsInArray: [parseId])
                            if (queryResult == nil) {
                                print("Error: \(db.lastErrorMessage())")
                                OTCData.synching = false
                                return
                            }
                            if queryResult.next() {
                                let updateActivityQuery = "UPDATE activity SET name = ?, lastTime = ?, totalTime = ? WHERE parseid = ?"
                                if !db.executeUpdate(updateActivityQuery, withArgumentsInArray: [name, lastTime, totalTime, parseId]) {
                                    print("Error: \(db.lastErrorMessage())")
                                    OTCData.synching = false
                                    return
                                }
                                print("updated activity: \(name)")
                            }
                            else {
                                let newActivityQuery = "INSERT INTO activity (parseid, userid, name, lastTime, totalTime) VALUES (?, ?, ?, ?, ?)"
                                if !db.executeUpdate(newActivityQuery, withArgumentsInArray: [parseId, userId, name, lastTime, totalTime]) {
                                    print("Error: \(db.lastErrorMessage())")
                                    OTCData.synching = false
                                    return
                                }
                                print("new activity: \(name)")
                            }
                        }
                        
                        let worksessions = syncResult["workSessions"] as! Array<Dictionary<String,AnyObject>>
                        for worksession in worksessions {
                            let newWorkSessionQuery = "INSERT INTO worksession (parseid, userid, activityid, startTime, duration, adjustment) "
                              + "VALUES (?, ?, (SELECT id FROM activity WHERE parseid = ?), ?, ?, ?)"
                            if !db.executeUpdate(
                                newWorkSessionQuery,
                                withArgumentsInArray: [worksession["id"]!, userId, worksession["activityId"]!,
                                  Int(worksession["startTime"]!.timeIntervalSince1970), worksession["duration"]!, worksession["adjustment"]!])
                            {
                                print("Error: \(db.lastErrorMessage())")
                                OTCData.synching = false
                                return
                            }
                            print("inserted new worksession: \(worksession["startTime"]!)")
                        }

                        
                    }
                    OTCData.synching = false
                    return nil;
                }.continueWithBlock { (task: BFTask!) -> AnyObject! in
                    if (task.error != nil) { print(task.error) }
                    return nil
                }
                //dispatch_async(dispatch_get_main_queue()) { () -> Void in
            })
        }
    }

}