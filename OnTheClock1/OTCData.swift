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
    static var syncing = false
    static var dbVersion: Int!
    static var clientId: Int!
    
    static let updateNotificationKey = "me.marksanford.otcdata.updated"
    static let pushLimit = 50
    
    // synchronous
    static func initDatabase() -> Bool {
        var sql_stmt: String!
        let filemgr = NSFileManager.defaultManager()
        let dirPaths = filemgr.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        var success = true
        
        let databasePath = dirPaths[0].URLByAppendingPathComponent("nowstep.db").path!
        print(databasePath)

        let dbAlreadyExists = filemgr.fileExistsAtPath(databasePath as String)
        
        dbQueue = FMDatabaseQueue(path: databasePath as String)
        
        if (dbQueue == nil) {
            print("Can't create database queue")
            return false
        }
        
        if dbAlreadyExists {
            dbQueue!.inDatabase({ (db) -> Void in
                var result: FMResultSet!
                
                sql_stmt = "SELECT numberValue FROM application WHERE key = 'clientId';"
                result = db.executeQuery(sql_stmt, withArgumentsInArray: nil)
                if (result == nil) {
                    print("Error: \(db.lastErrorMessage())")
                    success = false
                    return;
                }
                if (!result.next()) {
                    print("Error: \(db.lastErrorMessage())")
                    success = false
                    return;
                }
                OTCData.clientId = result.longForColumnIndex(0)
                result.close()
                print ("clientId = \(OTCData.clientId)")
                
                sql_stmt = "SELECT numberValue FROM application WHERE key = 'dbVersion';"
                result = db.executeQuery(sql_stmt, withArgumentsInArray: nil)
                if (result == nil) {
                    print("Error: \(db.lastErrorMessage())")
                    success = false
                    return;
                }
                if (!result.next()) {
                    print("Error: \(db.lastErrorMessage())")
                    success = false
                    return;
                }
                OTCData.dbVersion = result.longForColumnIndex(0)
                result.close()
                print ("dbVersion = \(OTCData.dbVersion)")
                
            })
            
            return success
        }
        
        dbQueue?.inDatabase({ (db) -> Void in
        
            sql_stmt =
                "CREATE TABLE IF NOT EXISTS application ("
                + "  key TEXT PRIMARY KEY, "
                + "  numberValue INTEGER DEFAULT NULL, "
                + "  stringValue TEXT DEFAULT NULL "
                + ")"
            
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
                success = false
                return;
            }

            // Use timestamp as clientID.   There is probably something better, but all
            // we need is a unique ID, and two installs will not happen in the same
            // second for the same user.
            let now = Int(NSDate().timeIntervalSince1970)
            
            // Database version, in case future versions need to modify schema
            let version = 1
            
            sql_stmt =
                "INSERT INTO application (key, numberValue) VALUES "
              + "('clientId', ?), "
              + "('dbVersion', ?) "
            
            if !db.executeUpdate(sql_stmt, withArgumentsInArray: [now, version]) {
                print("Error: \(db.lastErrorMessage())")
                success = false
                return;
            }
            
            // Anonymous user is specified by empty string ("") for parseid in activity and worksession
            // (this is different behavior than other two tables).  There is no entry for the anon
            // user in this table because syncing is not allowed for anon user.
            //
            // lastSyncTimestamp - millisecond timestamp of the most recent Parse object we synced with.
            //
            // syncDownTimestamp - if Parse is unable to give us full update of foreign data, then
            // this is the millisecond timestamp of the earliest on it gave us.  NULL means
            // means we're all up to date (this happens at most once per user per install)
            
            sql_stmt =
                  "CREATE TABLE IF NOT EXISTS user ("
                + "  parseid TEXT PRIMARY KEY, "
                + "  lastSyncTimestamp INTEGER, "
                + "  syncDownTimestamp INTEGER DEFAULT 0"
                + ")"
            
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
                success = false
                return;
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
                success = false
                return;
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
                success = false
                return;
            }

            sql_stmt = "CREATE INDEX start_time_index ON worksession (startTime, userid)"
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
                success = false
                return;
            }
            
            sql_stmt = "CREATE INDEX activity_index ON worksession (activityid, userid)"
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
                success = false
                return;
            }
            
            sql_stmt = "CREATE INDEX parseid_index ON worksession (parseid, userid)"
            if !db.executeStatements(sql_stmt) {
                print("Error: \(db.lastErrorMessage())")
                success = false
                return;
            }
            
        })
        
        return success
    }
    
    //
    //
    static func convertAnonymousData(cb: (Bool -> Void)?) {
        if PFUser.currentUser()?.objectId == nil { cb!(false); return }
        
        let userId = PFUser.currentUser()!.objectId!
        var success = true;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            dbQueue?.inTransaction({ (db, rollback) -> Void in
                let updateActivitesQuery = "UPDATE activity SET userid = ? WHERE userid = ''"
                if !db.executeUpdate(updateActivitesQuery, withArgumentsInArray: [userId]) {
                    print("Error: \(db.lastErrorMessage())"); rollback.initialize(true); success = false; return
                }
                let updateWorkSessionsQuery = "UPDATE worksession SET userid = ? WHERE userid = ''"
                if !db.executeUpdate(updateWorkSessionsQuery, withArgumentsInArray: [userId]) {
                    print("Error: \(db.lastErrorMessage())"); rollback.initialize(true); success = false; return
                }
            })
            if (cb != nil) { dispatch_async(dispatch_get_main_queue()) { () -> Void in return cb!(success) } }
        }
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
    
    
    // Get the most recent activites, in decending order of lastTime
    static func getRecentActivites(cb: ([ActivityInfo]) -> Void ) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            var result = [ActivityInfo]()
            OTCData.dbQueue?.inDatabase({ (db: FMDatabase!) -> Void in
                let userParseId = PFUser.currentUser()?.objectId ?? ""
                let activityQuery = "SELECT * FROM activity WHERE userid = ? ORDER BY lastTime DESC LIMIT 200"
                
                let activityResult = db.executeQuery(activityQuery, withArgumentsInArray: [userParseId])
                if (activityResult == nil) {
                    print("Error: \(db.lastErrorMessage())");
                    return;
                }
                while activityResult.next() {
                    let activityInfo = ActivityInfo(
                        lastTime: NSDate(timeIntervalSince1970: activityResult.doubleForColumn("lastTime")),
                        totalTime: activityResult.doubleForColumn("totalTime"),
                        name: activityResult.stringForColumn("name")
                    )
                    result.append(activityInfo)
                }
            })
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                return cb(result)
            }
        }
    }
    
    
    // Asynchronously sync to parse.   Call on main thread.  Uses NSNotification if data has been changed by
    // another client.
    static func syncToParse() {
        // syncing only makes sense for non-anonymous user
        if (PFUser.currentUser()?.objectId == nil) { return }

        let userId = PFUser.currentUser()!.objectId!
        
        if (OTCData.syncing == true) { print("already syncing"); return }
        OTCData.syncing = true;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            var newWorkSessions = [NSDictionary]()
            var lastSyncTimestamp: Int = 0
            var syncDownTimestamp: Int = 0
            var fail = false
            
            OTCData.dbQueue?.inDatabase({ (db: FMDatabase!) -> Void in
                
                // get the last time this user synched to Parse
                let userQuery = "SELECT lastSyncTimestamp, syncDownTimestamp FROM user WHERE parseid = ?"
                let dateResult = db.executeQuery(userQuery, withArgumentsInArray: [userId])
                if (dateResult == nil) { print("Error: \(db.lastErrorMessage())"); fail = true; return; }
                if dateResult.next() {
                    lastSyncTimestamp = dateResult.longForColumn("lastSyncTimestamp")
                    syncDownTimestamp = dateResult.longForColumn("syncDownTimestamp")
                }
                dateResult.close()

                let needsPushQuery =
                      "SELECT ws.id as id, ws.startTime AS startTime, ws.duration AS duration, ws.adjustment as adjustment, "
                    + "act.name AS activityName, act.parseid as activityParseId, act.id AS activityId "
                    + "FROM worksession AS ws JOIN activity AS act ON act.id = ws.activityid "
                    + "WHERE ws.userid = ? AND ws.parseid IS NULL "
                    + "ORDER BY startTime DESC"
                    + "LIMIT ?"
                
                let newWorkSessionsResult = db.executeQuery(needsPushQuery, withArgumentsInArray: [userId, OTCData.pushLimit])
                if (newWorkSessionsResult == nil) { print("Error: \(db.lastErrorMessage())"); fail = true; return; }
                while newWorkSessionsResult.next() {
                    var workSession = [
                        "id" : newWorkSessionsResult.longForColumn("id"),
                        "startTime" :  NSDate(timeIntervalSince1970: Double(newWorkSessionsResult.longForColumn("startTime"))),
                        "duration" : newWorkSessionsResult.doubleForColumn("duration"),
                        "adjustment": newWorkSessionsResult.doubleForColumn("adjustment"),
                        "activityId": newWorkSessionsResult.longForColumn("activityId")
                    ]
                    if newWorkSessionsResult.columnIsNull("activityParseId") {
                        workSession["activityName"] = newWorkSessionsResult.stringForColumn("activityName")
                    }
                    else {
                        workSession["activityParseId"] = newWorkSessionsResult.stringForColumn("activityParseId")
                    }
                    newWorkSessions.append(workSession)
                }
            })
            
            if (fail) { dispatch_async(dispatch_get_main_queue()) { () -> Void in OTCData.syncing = false }; return; }
                
            var parameters = Dictionary<NSObject, AnyObject>()
            parameters["newWorkSessions"] = newWorkSessions
            parameters["lastSyncTimestamp"] = lastSyncTimestamp
            parameters["syncDownTimestamp"] = syncDownTimestamp
            parameters["clientId"] = OTCData.clientId
            
            PFCloud.callFunctionInBackground("sync", withParameters: parameters).continueWithBlock {
                (task: BFTask!) -> AnyObject! in
                if (task.error == nil && task.result != nil) {
                    let syncResult = task.result as! Dictionary<String, AnyObject>
                    print(task.result)
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                        let saveSuccess = _saveSyncResults(userId, syncResult: syncResult)
                        dispatch_async(dispatch_get_main_queue()) { () -> Void in
                            OTCData.syncing = false
                            if (saveSuccess && syncResult["haveUpdates"] as! Bool) {
                                NSNotificationCenter.defaultCenter().postNotificationName(OTCData.updateNotificationKey, object: nil)
                            }
                        }
                    }
                }
                else {
                    print(task.error)
                    dispatch_async(dispatch_get_main_queue()) { () -> Void in OTCData.syncing = false }
                }
                return nil;
            }
        }
    }
    
    //
    // sync returns:
    //
    // savedWorkSessions: sessions that WE sent to Parse to be saved
    // foreignWorkSessions: sessions that were saved by another client
    // activites: activities referred to by both savedWorkSessions and foreignWorkSessions
    // newLastSyncTimestamp:
    // newSyncDownTimestamp: the ms updatedAt of the most recent change send, when incomplete set sent
    //
    

    private static func _saveSyncResults(userId: String, syncResult: Dictionary<String, AnyObject>) -> Bool {
        var fail = false
        
        dbQueue?.inTransaction({ (db, rollback) -> Void in
            
            // Update/Insert activities so worksessions can refer to them
            let activities = syncResult["activities"] as! Array<Dictionary<String,AnyObject>>
            for activity in activities {
                let id: Int! = activity["id"] as? Int
                let parseId = activity["parseId"]!
                let lastTime = Int(activity["lastTime"]!.timeIntervalSince1970)
                let totalTime = activity["totalTime"]!
                let name = activity["name"]!
                
                if (id == nil) {
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
                else {
                    // If Parse gave us an ID, that means we gave this activity to parse as a provisional activity (no parseid)
                    let updateActivityQuery = "UPDATE activity SET parseid = ?, name = ?, lastTime = ?, totalTime = ? WHERE id = ?"
                    if !db.executeUpdate(updateActivityQuery, withArgumentsInArray: [parseId, name, lastTime, totalTime, id]) {
                        print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
                    }
                    print("updated provisional activity: \(name)")
                }
                
            }
            
            // Now update the new work sessions
            let worksessions = syncResult["savedWorkSessions"] as! Array<Dictionary<String,AnyObject>>
            for worksession in worksessions {
                let id: Int = worksession["id"] as! Int
                let parseid: Int = worksession["parseid"] as! Int
                let newWorkSessionQuery = "UPDATE worksession SET parseid = ? WHERE id = ?"
                
                if !db.executeUpdate(newWorkSessionQuery, withArgumentsInArray: [parseid, id]) {
                    print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
                }
                
                if (db.changes() > 0) {
                    print("updated parseid for worksession: \(worksession["startTime"]!)")
                } else {
                    print("updated for worksession: \(worksession["startTime"]!)...local not found")
                }
            }
            
            // Now insert the foreign worksessions that were added from other clients
            // Do NOT assume that we haven't inserted it already, since it's possible for sync to send it twice
            let foreignWorkSessions = syncResult["foreignWorkSessions"] as! Array<Dictionary<String,AnyObject>>
            for worksession in foreignWorkSessions {
                let parseId = worksession["parseid"] as! String
                let forgeignWorkSessionQuery = "SELECT id FROM worksession WHERE parseid = ?"
                let queryResult = db.executeQuery(forgeignWorkSessionQuery, withArgumentsInArray: [parseId])
                if (queryResult == nil) { print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return; }
                if queryResult.next() {
                    print("Got existing foreign work session")
                }
                else {
                    let newWorkSessionQuery =
                        "INSERT INTO worksession (parseid, userid, activityid, startTime, duration, adjustment) "
                      + "VALUES (?, ?, (SELECT id FROM activity WHERE parseid = ?), ?, ?, ?)"
                    
                    let arguments = [parseId, userId, worksession["activityId"]!,
                        Int(worksession["startTime"]!.timeIntervalSince1970), worksession["duration"]!, worksession["adjustment"]!]
                    
                    if !db.executeUpdate(newWorkSessionQuery, withArgumentsInArray: arguments) {
                        print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
                    }
                    print("inserted new worksession: \(worksession["startTime"]!)")
                }
                queryResult.close()
            }
        
            // Lastly, update the lastSyncTimestamp record for the user
            let userQuery = "INSERT OR REPLACE INTO user (parseid, lastSyncTimestamp, syncDownTimestamp) VALUES (?, ?)"
            let newLastSyncTimestamp = syncResult["newLastSyncTimestamp"] as! Int
            let newSyncDownTimestamp = syncResult["newSyncDownTimestamp"] as! Int
            if !db.executeUpdate(userQuery, withArgumentsInArray: [userId, newLastSyncTimestamp, newSyncDownTimestamp]) {
                print("Error: \(db.lastErrorMessage())"); fail = true; rollback.initialize(true); return;
            }
            
        })
        
        return !fail
    }
    
    
}