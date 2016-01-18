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
        
            // Anonymous user is specified by empty string ("") for parseid
            // (this is different behavior than other two tables)
            sql_stmt =
                  "CREATE TABLE IF NOT EXISTS user ("
                + "  id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "  parseid TEXT UNIQUE NOT NULL, "
                + "  lastSyncDate INTEGER "
                + ")"
            
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
            }

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
        var activityId: Int!
        let activityName = newWorkSession.activityName.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        let userId = PFUser.currentUser()?.objectId ?? ""
        let startTime = Int(newWorkSession.startTime.timeIntervalSince1970)

        dbQueue?.inTransaction({ (db, rollback) -> Void in
            
            // See if there is an existing activity with the given activity name
            let activityQueryResult = db.executeQuery("SELECT * FROM activity WHERE name = ? AND userid = ?", withArgumentsInArray: [activityName, userId])
            if (activityQueryResult == nil) {
                rollback.initialize(true)
                print("Error: \(db.lastErrorMessage())")
                return;
            }
            
            // if there is, we can use it, and update it's lastTime
            if activityQueryResult.next() == true {
                activityId = activityQueryResult?.longForColumn("id")
                let updateActivityQuery = "UPDATE activity SET lastTime = ? WHERE id = ?"
                if !db.executeUpdate(updateActivityQuery, withArgumentsInArray: [startTime, activityId]) {
                    rollback.initialize(true)
                    print("Error: \(db.lastErrorMessage())")
                    return;
                }
                activityQueryResult.close()
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
            }
            
            // now we can create the new work session
            let insertWorkSessionQuery = "INSERT INTO worksession (userid, activityid, startTime, duration, adjustment) VALUES (?, ?, ?, ?, ?)"
            if !db.executeUpdate(insertWorkSessionQuery, withArgumentsInArray: [userId, activityId, startTime, newWorkSession.duration, newWorkSession.adjustment]) {
                rollback.initialize(true)
                print("Error: \(db.lastErrorMessage())")
                return;
            }

            rollback.initialize(false)
        })

        
    }
    
    // Asynchronously sync to parse.   Call on main thread!  Uses NSNotification if data has changed.
    static func syncToParse() {
        // synching only makes sense for non-anonymous user
        if (PFUser.currentUser()?.objectId == nil) { return }

        let userId = PFUser.currentUser()!.objectId!
        
        if (OTCData.synching == true) { return }
        OTCData.synching = true;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            var newWorkSessions = [NSDictionary]()
            var lastSyncDate: NSDate!
            var fail = false
            
            OTCData.dbQueue?.inDatabase({ (db: FMDatabase!) -> Void in
                
                // get the last time this user synched to Parse
                let userQuery = "SELECT lastSyncDate FROM user WHERE parseid = ?"
                let dateResult = db.executeQuery(userQuery, withArgumentsInArray: [userId])
                if (dateResult == nil) { print("Error: \(db.lastErrorMessage())"); fail = true; return; }
                lastSyncDate = NSDate(timeIntervalSince1970: (dateResult.next() ?  dateResult.doubleForColumn("lastSyncDate") : 0.0))
                dateResult.close()

                let needsPushQuery =
                      "SELECT ws.startTime AS startTime, ws.duration AS duration, ws.adjustment as adjustment, act.name AS activityName, act.parseid as activityParseId "
                    + "FROM worksession AS ws JOIN activity AS act ON act.id = ws.activityid "
                    + "WHERE ws.userid = ? AND ws.parseid IS NULL"
                let newWorkSessionsResult = db.executeQuery(needsPushQuery, withArgumentsInArray: [userId])
                if (newWorkSessionsResult == nil) { print("Error: \(db.lastErrorMessage())"); fail = true; return; }
                while newWorkSessionsResult.next() {
                    var workSession = [
                        "startTime" :  NSDate(timeIntervalSince1970: Double(newWorkSessionsResult.longForColumn("startTime"))),
                        "duration" : newWorkSessionsResult.doubleForColumn("duration"),
                        "adjustment": newWorkSessionsResult.doubleForColumn("adjustment"),
                    ]
                    if newWorkSessionsResult.columnIsNull("activityParseId") {
                        workSession["activityName"] = newWorkSessionsResult.stringForColumn("activityName")
                    }
                    else {
                        workSession["activityId"] = newWorkSessionsResult.stringForColumn("activityParseId")
                    }
                    newWorkSessions.append(workSession)
                }
            })
            
            if (fail) { dispatch_async(dispatch_get_main_queue()) { () -> Void in OTCData.synching = false }; return; }
                
            var parameters = Dictionary<NSObject, AnyObject>()
            parameters["newWorkSessions"] = newWorkSessions
            parameters["lastSyncDate"] = lastSyncDate
            
            PFCloud.callFunctionInBackground("sync", withParameters: parameters).continueWithBlock {
                (task: BFTask!) -> AnyObject! in
                if (task.error == nil && task.result != nil) {
                    let syncResult = task.result as! Dictionary<String, AnyObject>
                    print(task.result)
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                        let saveSuccess = _saveSyncResults(userId, syncResult: syncResult)
                        dispatch_async(dispatch_get_main_queue()) { () -> Void in
                            OTCData.synching = false
                            if (saveSuccess) {
                                // Do some notification that sync has succeeded
                            }
                        }
                    }
                }
                else {
                    print(task.error)
                    dispatch_async(dispatch_get_main_queue()) { () -> Void in OTCData.synching = false }
                }
                return nil;
            }
        }
    }

    private static func _saveSyncResults(userId: String, syncResult: Dictionary<String, AnyObject>) -> Bool {
        var fail = false
        
        dbQueue?.inTransaction({ (db, rollback) -> Void in
            // We're being handed proper new Parse objects, so go ahead and delete any provisional data
            if !db.executeStatements("DELETE FROM activity WHERE parseid IS NULL;") {
                print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
            }
            if !db.executeStatements("DELETE FROM worksession WHERE parseid IS NULL;") {
                print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
            }
            
            // Now insert or update activites
            let activities = syncResult["activities"] as! Array<Dictionary<String,AnyObject>>
            for activity in activities {
                let parseId = activity["id"]!
                let lastTime = Int(activity["last"]!.timeIntervalSince1970)
                let totalTime = activity["total"]!
                let name = activity["name"]!
                
                let existingActivityQuery = "SELECT id FROM activity WHERE parseid = ?"
                let queryResult = db.executeQuery(existingActivityQuery, withArgumentsInArray: [parseId])
                if (queryResult == nil) { print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return; }
                if queryResult.next() {
                    let updateActivityQuery = "UPDATE activity SET name = ?, lastTime = ?, totalTime = ? WHERE parseid = ?"
                    if !db.executeUpdate(updateActivityQuery, withArgumentsInArray: [name, lastTime, totalTime, parseId]) {
                        print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
                    }
                    print("updated activity: \(name)")
                }
                else {
                    let newActivityQuery = "INSERT INTO activity (parseid, userid, name, lastTime, totalTime) VALUES (?, ?, ?, ?, ?)"
                    if !db.executeUpdate(newActivityQuery, withArgumentsInArray: [parseId, userId, name, lastTime, totalTime]) {
                        print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
                    }
                    print("new activity: \(name)")
                }
                queryResult.close()
            }
            
            // Now insert the new work sessions
            let worksessions = syncResult["workSessions"] as! Array<Dictionary<String,AnyObject>>
            for worksession in worksessions {
                let newWorkSessionQuery = "INSERT INTO worksession (parseid, userid, activityid, startTime, duration, adjustment) "
                    + "VALUES (?, ?, (SELECT id FROM activity WHERE parseid = ?), ?, ?, ?)"
                if !db.executeUpdate(
                    newWorkSessionQuery,
                    withArgumentsInArray: [worksession["id"]!, userId, worksession["activityId"]!,
                        Int(worksession["startTime"]!.timeIntervalSince1970), worksession["duration"]!, worksession["adjustment"]!])
                {
                    print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
                }
                print("inserted new worksession: \(worksession["startTime"]!)")
            }
            
            // Lastly, update the lastSyncDate record for the user
            let userQuery = "INSERT OR REPLACE INTO user (parseid, lastSyncDate) VALUES (?, ?)"
            let newLastSyncDate = syncResult["newLastSyncDate"] as! NSDate
            if !db.executeUpdate(userQuery, withArgumentsInArray: [userId, newLastSyncDate]) {
                print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
            }
            
        })
        
        return fail
    }
    
    
}