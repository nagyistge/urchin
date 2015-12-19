/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import Foundation
import UIKit
import CoreData
import SystemConfiguration

class APIConnector {
    
    let metricsSource: String = "urchin"
    var x_tidepool_session_token: String = ""
    var user: User?
    
    private var groupsToFetchFor = 0
    private var groupsFetched = 0
    
    private var isShowingAlert = false
    
    func request(method: String, urlExtension: String, headerDict: [String: String], body: NSData?, preRequest: () -> Void,
        completion: (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void) {
        
            if (self.isConnectedToNetwork()) {
                preRequest()
                
                var urlString = baseURL + urlExtension
                urlString = urlString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
                let url = NSURL(string: urlString)
                let request = NSMutableURLRequest(URL: url!)
                request.HTTPMethod = method
                for (field, value) in headerDict {
                    request.setValue(value, forHTTPHeaderField: field)
                }
                request.HTTPBody = body
                
                NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) { (response, data, error) -> Void in
                    completion(response: response, data: data, error: error)
                }
            } else {
                NSLog("Not connected to network")
                self.alertWithOkayButton("Not Connected to Network", message: "Please restart Blip notes when you are connected to a network.")
            }
    }
    
    func trackMetric(metricName: String) {
        
        let urlExtension = "/metrics/thisuser/\(metricsSource) - \(metricName)?source=\(metricsSource)&sourceVersion=\(UIApplication.appVersion())"
        
        let headerDict: [String: String] = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            // nothing to do
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    NSLog("Tracked metric: \(metricName)")
                } else {
                    NSLog("Invalid status code: \(httpResponse.statusCode) for tracking metric: \(metricName)")
                }
            } else {
                NSLog("Invalid response for tracking metric")
            }
        }
        
        request("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
        
    }
    
    func login(loginVC: LogInViewController, username: String, password: String) {
        
        let loginString = NSString(format: "%@:%@", username, password)
        let loginData: NSData = loginString.dataUsingEncoding(NSUTF8StringEncoding)!
        let base64LoginString = loginData.base64EncodedStringWithOptions([])
        
        loginRequest(loginVC, base64LoginString: base64LoginString, saveLogin: true)
    }
    
    func loginRequest(loginVC: LogInViewController?, base64LoginString: String, saveLogin: Bool) {

        let headerDict = ["Authorization":"Basic \(base64LoginString)"]
        
        let loading = LoadingView(text: loadingLogIn)
        
        let preRequest = { () -> Void in
            if (loginVC != nil) {
                let loadingX = loginVC!.view.frame.width / 2 - loading.frame.width / 2
                let loadingY = loginVC!.view.frame.height / 2 - loading.frame.height / 2
                loading.frame.origin = CGPoint(x: loadingX, y: loadingY)
                loginVC!.view.addSubview(loading)
                loginVC!.view.bringSubviewToFront(loading)
            }
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            let jsonResult: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
            
            if let code = jsonResult.valueForKey("code") as? Int {
                if (code == 401) {
                    NSLog("Invalid login request: \(code)")
                    
                    let notification = NSNotification(name: "prepareLogin", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                    
                    self.alertWithOkayButton(invalidLogin, message: invalidLoginMessage)
                } else {
                    NSLog("Invalid login request: \(code)")
                    
                    let notification = NSNotification(name: "prepareLogin", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                    
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                if let httpResponse = response as? NSHTTPURLResponse {
                    
                    if (httpResponse.statusCode == 200) {
                        NSLog("Logged in")
                        
                        let jsonResult: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
                        
                        if let sessionToken = httpResponse.allHeaderFields["x-tidepool-session-token"] as? String {
                            self.x_tidepool_session_token = sessionToken
                            self.user = User(userid: jsonResult.valueForKey("userid") as! String, apiConnector: self, notesVC: nil)
                            
                            if (saveLogin) {
                                if (loginVC!.rememberMe) {
                                    self.trackMetric("Remember Me Used")
                                    
                                    self.saveLogin(base64LoginString)
                                } else {
                                    self.saveLogin("")
                                }
                            }
                            
                            let notification = NSNotification(name: "makeTransitionToNotes", object: nil)
                            NSNotificationCenter.defaultCenter().postNotification(notification)
                            
                            let notificationTwo = NSNotification(name: "directLogin", object: nil)
                            NSNotificationCenter.defaultCenter().postNotification(notificationTwo)
                        } else {
                            NSLog("Invalid login: \(httpResponse.statusCode)")
                            
                            let notification = NSNotification(name: "prepareLogin", object: nil)
                            NSNotificationCenter.defaultCenter().postNotification(notification)
                            
                            let notificationTwo = NSNotification(name: "forcedLogout", object: nil)
                            NSNotificationCenter.defaultCenter().postNotification(notificationTwo)
                        }
                    } else {
                        NSLog("Invalid status code: \(httpResponse.statusCode) for logging in")
                        
                        let notification = NSNotification(name: "prepareLogin", object: nil)
                        NSNotificationCenter.defaultCenter().postNotification(notification)
                        
                        let notificationTwo = NSNotification(name: "forcedLogout", object: nil)
                        NSNotificationCenter.defaultCenter().postNotification(notificationTwo)
                        
                        self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                    }
                } else {
                    NSLog("Invalid response for logging in")
                    
                    let notification = NSNotification(name: "prepareLogin", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                    
                    let notificationTwo = NSNotification(name: "forcedLogout", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notificationTwo)
                    
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            }
            // If there is a loginVC, remove the loading view from it
            if (loginVC != nil) {
                loading.removeFromSuperview()
            }
        }
        
        request("POST", urlExtension: "/auth/login", headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    func login() {
        
        // Store the appDelegate
        let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
        
        // Store the managedContext
        let managedContext = appDelegate.managedObjectContext!
        
        // Open a new fetch request
        let fetchRequest = NSFetchRequest(entityName:"Login")
        
        // Execute the fetch from CoreData
        do {
            let results =
            try managedContext.executeFetchRequest(fetchRequest) as? [NSManagedObject]
            
            if (results!.count != 0) {
                let expiration = results![0].valueForKey("expiration") as! NSDate
                if (expiration.timeIntervalSinceNow < 0) {
                    
                    // Login has expired!
                    
                    // Set the value to the new saved login
                    results![0].setValue("", forKey: "login")
                    
                    // Save the expiration date (6 mo.s in advance)
                    let dateShift = NSDateComponents()
                    dateShift.month = 6
                    let calendar = NSCalendar.currentCalendar()
                    let date = calendar.dateByAddingComponents(dateShift, toDate: NSDate(), options: [])!
                    results![0].setValue(date, forKey: "expiration")
                    
                    // Attempt to save the login
                    var error: NSError?
                    do {
                        try managedContext.save()
                    } catch let error1 as NSError {
                        error = error1
                        NSLog("Could not save log in remember me: \(error), \(error?.userInfo)")
                    }
                }
                let base64LoginString = results![0].valueForKey("login") as! String
                
                if (base64LoginString != "") {
                    // Login information exists
                    
                    self.loginRequest(nil, base64LoginString: base64LoginString, saveLogin: false)
                } else {
                    // Login information does not exist
                    
                    let notification = NSNotification(name: "prepareLogin", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                    
                    let notificationTwo = NSNotification(name: "forcedLogout", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notificationTwo)
                }
            } else {
                // Login information does not exist
                
                let notification = NSNotification(name: "prepareLogin", object: nil)
                NSNotificationCenter.defaultCenter().postNotification(notification)
                
                let notificationTwo = NSNotification(name: "forcedLogout", object: nil)
                NSNotificationCenter.defaultCenter().postNotification(notificationTwo)
            }
        } catch let error as NSError {
            NSLog("Could not fetch remember me information: \(error), \(error.userInfo)")
        }
    }

    
    func saveLogin(login: String) {
        // Store the appDelegate
        let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
        
        // Store the managedContext
        let managedContext = appDelegate.managedObjectContext!
        
        // Open a new fetch request
        let fetchRequest = NSFetchRequest(entityName:"Login")
        
        do {
            // Execute the fetch
            let results =
            try managedContext.executeFetchRequest(fetchRequest) as? [NSManagedObject]
            
            if (results!.count == 0) {
                // Create a new login for remembering
                
                // Initialize the new entity
                let entity =  NSEntityDescription.entityForName("Login",
                    inManagedObjectContext:
                    managedContext)
                
                // Let it be a hashtag in the managedContext
                let loginObj = NSManagedObject(entity: entity!,
                    insertIntoManagedObjectContext:managedContext)
                
                // Save the encrypted login information
                loginObj.setValue(login, forKey: "login")
                
                // Save the expiration date (6 mo.s in advance)
                let dateShift = NSDateComponents()
                dateShift.month = 6
                let calendar = NSCalendar.currentCalendar()
                let date = calendar.dateByAddingComponents(dateShift, toDate: NSDate(), options: [])!
                loginObj.setValue(date, forKey: "expiration")
                
                // Save the login
                var errorTwo: NSError?
                do {
                    try managedContext.save()
                } catch let error as NSError {
                    errorTwo = error
                    NSLog("Could not save new remember me info: \(errorTwo), \(errorTwo?.userInfo)")
                }
            } else if (results!.count == 1) {
                // Set the value to the new saved login
                results![0].setValue(login, forKey: "login")
                
                // Save the expiration date (6 mo.s in advance)
                let dateShift = NSDateComponents()
                dateShift.month = 6
                let calendar = NSCalendar.currentCalendar()
                let date = calendar.dateByAddingComponents(dateShift, toDate: NSDate(), options: [])!
                results![0].setValue(date, forKey: "expiration")
                
                // Attempt to save the login
                var errorTwo: NSError?
                do {
                    try managedContext.save()
                } catch let error as NSError {
                    errorTwo = error
                    NSLog("Could not save edited remember me info: \(errorTwo), \(errorTwo?.userInfo)")
                }
            }
        } catch let error as NSError {
            NSLog("Could not fetch remember me info: \(error), \(error.userInfo)")
        }
    }
    
    func refreshToken() {
        
        let urlExtension = "/auth/login"
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            // Nothing to do (yet)
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            let jsonResult: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
            
            if let code = jsonResult.valueForKey("code") as? Int {
                if (code == 401) {
                    NSLog("Could not refresh session token: \(code)")
                    
                    self.tryLoginFromRefreshToken()
                    
                } else {
                    NSLog("Could not refresh session token: \(code)")
                    
                    self.tryLoginFromRefreshToken()
                }
            } else {
                if let httpResponse = response as? NSHTTPURLResponse {
                    
                    if (httpResponse.statusCode == 200) {
                        NSLog("Refreshed session token")
                        
                        // Store the session token for further use.
                        self.x_tidepool_session_token = httpResponse.allHeaderFields["x-tidepool-session-token"] as! String
                        
                        // Send notification to NotesVC to open new note
                        let notification = NSNotification(name: "newNote", object: nil)
                        NSNotificationCenter.defaultCenter().postNotification(notification)
                        
                        
                    } else {
                        NSLog("Could not refresh session token - invalid status code \(httpResponse.statusCode)")
                        
                        self.tryLoginFromRefreshToken()
                    }
                    
                } else {
                    NSLog("Could not refresh session token - response could not be parsed")
                    
                    self.tryLoginFromRefreshToken()
                }
            }
            
        }
        
        // Post the request.
        self.request("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
        
    }
    
    func tryLoginFromRefreshToken() {
        
        self.groupsFetched = 0
        self.groupsToFetchFor = 0
        self.login()
        
    }
    
    func logout(notesVC: NotesViewController) {
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            self.saveLogin("")
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    NSLog("Logged out")
                    let notification = NSNotification(name: "prepareLogin", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                    
                    notesVC.dismissViewControllerAnimated(true, completion: {
                        self.user = nil
                        self.x_tidepool_session_token = ""
                        self.groupsFetched = 0
                        self.groupsToFetchFor = 0
                    })
                } else {
                    NSLog("Did not log out - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                NSLog("Did not log out - response could not be parsed")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("POST", urlExtension: "/auth/logout", headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    func findProfile(otherUser: User, notesVC: NotesViewController?) {
        
        let urlExtension = "/metadata/" + otherUser.userid + "/profile"
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            // nothing to prepare
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    NSLog("Profile found: \(otherUser.userid)")
                    
                    let userDict: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
                    
                    otherUser.processUserDict(userDict)
                    
                    if (notesVC != nil) {
                        self.groupsFetched++
                        
                        // Insert logic here for DSAs only
                        if (otherUser.patient != nil && (otherUser.patient?.aboutMe != nil || otherUser.patient?.birthday != nil || otherUser.patient?.diagnosisDate != nil)) {
                            notesVC!.groups.insert(otherUser, atIndex: 0)
                        }
                        
                        if (self.groupsFetched == self.groupsToFetchFor) {
                            // Send notification to NotesVC to notify that groups are ready
                            let notification = NSNotification(name: "groupsReady", object: nil)
                            NSNotificationCenter.defaultCenter().postNotification(notification)
                        }
                    }
                    
                    
                } else {
                    NSLog("Did not find profile - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                NSLog("Did not find profile - response could not be parsed")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    func getAllViewableUsers(notesVC: NotesViewController) {
        
        let urlExtension = "/access/groups/" + user!.userid
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            // Nothing to do
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    NSLog("Found viewable users for user: \(self.user?.userid)")
                    let jsonResult: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
                                        
                    var i = 0
                    for key in jsonResult.keyEnumerator() {
                        _ = User(userid: key as! String, apiConnector: self, notesVC: notesVC)
                        i++
                    }
                    self.groupsToFetchFor = i
                } else {
                    NSLog("Did not find viewable users - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                NSLog("Did not find viewable users - response could not be parsed")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    func getNotesForUserInDateRange(notesVC: NotesViewController, userid: String, start: NSDate, end: NSDate) {
        
        let dateFormatter = NSDateFormatter()
        let urlExtension = "/message/notes/" + userid + "?starttime=" + dateFormatter.isoStringFromDate(start, zone: nil) + "&endtime="  + dateFormatter.isoStringFromDate(end, zone: nil)
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            notesVC.loadingNotes = true
            notesVC.numberFetches++
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            
            // End refreshing for refresh control
            notesVC.refreshControl.endRefreshing()
            
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    NSLog("Got notes for user (\(userid)) in given date range: \(dateFormatter.isoStringFromDate(start, zone: nil)) to \(dateFormatter.isoStringFromDate(end, zone: nil))")
                    
                    var notes: [Note] = []
                    
                    let jsonResult: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
                    
                    let messages: NSArray = jsonResult.valueForKey("messages") as! NSArray
                    
                    let dateFormatter = NSDateFormatter()
                    
                    for message in messages {
                        let id = message.valueForKey("id") as! String
                        let otheruserid = message.valueForKey("userid") as! String
                        let groupid = message.valueForKey("groupid") as! String
                        let timestamp = dateFormatter.dateFromISOString(message.valueForKey("timestamp") as! String)
                        var createdtime: NSDate
                        if let created = message.valueForKey("createdtime") as? String {
                            createdtime = dateFormatter.dateFromISOString(created)
                        } else {
                            createdtime = timestamp
                        }
                        let messagetext = message.valueForKey("messagetext") as! String
                        
                        let otheruser = User(userid: otheruserid)
                        let userDict = message.valueForKey("user") as! NSDictionary
                        otheruser.processUserDict(userDict)
                        
                        let note = Note(id: id, userid: otheruserid, groupid: groupid, timestamp: timestamp, createdtime: createdtime, messagetext: messagetext, user: otheruser)
                        notes.append(note)
                    }
                    
                    notesVC.notes = notesVC.notes + notes
                    notesVC.filterNotes()
                    notesVC.notesTable.reloadData()
                } else if (httpResponse.statusCode == 404) {
                    NSLog("No notes retrieved, status code: \(httpResponse.statusCode), userid: \(userid)")
                } else {
                    NSLog("No notes retrieved - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
                
                notesVC.numberFetches--
                if (notesVC.numberFetches == 0) {
                    notesVC.loadingNotes = false
                    let notification = NSNotification(name: "doneFetching", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                }
            } else {
                NSLog("No notes retrieved - could not parse response")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    func doPostWithNote(notesVC: NotesViewController, note: Note) {
        
        let urlExtension = "/message/send/" + note.groupid
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)", "Content-Type":"application/json"]
        
        let jsonObject = note.dictionaryFromNote()
        let body: NSData?
        do {
            body = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: [])
        } catch {
            body = nil
        }
        
        let preRequest = { () -> Void in
            // nothing to do in prerequest
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                
                if (httpResponse.statusCode == 201) {
                    NSLog("Sent note for groupid: \(note.groupid)")
                    
                    let jsonResult: NSDictionary = ((try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as? NSDictionary)!
                    
                    note.id = jsonResult.valueForKey("id") as! String
                    
                    notesVC.notes.insert(note, atIndex: 0)
                    // filter the notes, sort the notes, reload notes table
                    notesVC.filterNotes()
                    notesVC.notesTable.reloadData()
                    
                } else {
                    NSLog("Did not send note for groupid \(note.groupid) - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                NSLog("Did not send note for groupid \(note.groupid) - could not parse response")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("POST", urlExtension: urlExtension, headerDict: headerDict, body: body, preRequest: preRequest, completion: completion)
    }
    
    func editNote(notesVC: NotesViewController, editedNote: Note, originalNote: Note) {
        
        let urlExtension = "/message/edit/" + originalNote.id
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)", "Content-Type":"application/json"]
        
        let jsonObject = editedNote.updatesFromNote()
        let body: NSData?
        do {
            body = try NSJSONSerialization.dataWithJSONObject(jsonObject, options: [])
        } catch  {
            body = nil
        }
        
        let preRequest = { () -> Void in
            // nothing to do in the preRequest
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    NSLog("Edited note with id \(originalNote.id)")
                    
                    originalNote.messagetext = editedNote.messagetext
                    originalNote.timestamp = editedNote.timestamp
                    
                    // filter the notes, sort the notes, reload notes table
                    notesVC.filterNotes()
                    notesVC.notesTable.reloadData()
                } else {
                    NSLog("Did not edit note with id \(originalNote.id) - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                NSLog("Did not edit note with id \(originalNote.id) - could not parse response")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("PUT", urlExtension: urlExtension, headerDict: headerDict, body: body, preRequest: preRequest, completion: completion)
    }
    
    func deleteNote(notesVC: NotesViewController, noteToDelete: Note) {
        let urlExtension = "/message/remove/" + noteToDelete.id
        
        let headerDict = ["x-tidepool-session-token":"\(x_tidepool_session_token)"]
        
        let preRequest = { () -> Void in
            // nothing to do in the preRequest
        }
        
        let completion = { (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                if (httpResponse.statusCode == 202) {
                    NSLog("Deleted note with id \(noteToDelete.id)")
                    
                    var i = 0
                    for note in notesVC.notes {
                        
                        if (note.id == noteToDelete.id) {
                            notesVC.notes.removeAtIndex(i)
                            break
                        }
                        
                        i++
                    }
                    
                    // filter the notes, sort the notes, reload notes table
                    notesVC.filterNotes()
                    notesVC.notesTable.reloadData()
                } else {
                    NSLog("Did not delete note with id \(noteToDelete.id) - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
                }
            } else {
                NSLog("Did not delete note with id \(noteToDelete.id) - could not parse response")
                self.alertWithOkayButton(unknownError, message: unknownErrorMessage)
            }
        }
        
        request("DELETE", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    // Save the currently used server.
    // So when the user returns, the server is the last set server.
    //      --> Primarily Tidepool employees changing server.
    func saveServer(serverName: String) {
        
        // Store the appDelegate
        let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
        
        // Store the managedContext
        let managedContext = appDelegate.managedObjectContext!
        
        // Open a new fetch request
        let fetchRequest = NSFetchRequest(entityName:"Server")
        
        do {
            // Execute the fetch from CoreData
            let results =
            try managedContext.executeFetchRequest(fetchRequest) as? [NSManagedObject]
            
            if (results!.count == 0) {
                // Create a new server for remembering
                
                // Initialize the new entity
                let entity =  NSEntityDescription.entityForName("Server",
                    inManagedObjectContext:
                    managedContext)
                
                // Let it be a hashtag in the managedContext
                let loginObj = NSManagedObject(entity: entity!,
                    insertIntoManagedObjectContext:managedContext)
                
                // Save the encrypted login information
                loginObj.setValue(serverName, forKey: "serverName")
                
            } else if (results!.count == 1) {
                // Set the value to the new server
                results![0].setValue(serverName, forKey: "serverName")
            }
            
            // Attempt to save the server
            var errorTwo: NSError?
            do {
                try managedContext.save()
                baseURL = servers[serverName]!
            } catch let error as NSError {
                errorTwo = error
                NSLog("Could not save edited remember me info: \(errorTwo), \(errorTwo?.userInfo)")
            }
        } catch let error as NSError {
            NSLog("Could not fetch server information: \(error), \(error.userInfo)")
        }
    }
    
    func loadServer() {
        
        // Store the appDelegate
        let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
        
        // Store the managedContext
        let managedContext = appDelegate.managedObjectContext!
        
        // Open a new fetch request
        let fetchRequest = NSFetchRequest(entityName:"Server")
        
        // Execute the fetch from CoreData
        do {
            let fetchedResults =
            try managedContext.executeFetchRequest(fetchRequest) as? [NSManagedObject]
            
            if let results = fetchedResults {
                if results.count == 1 {
                    
                    let serverName = results[0].valueForKey("serverName") as! String
                    
                    baseURL = servers[serverName]!
                    
                }
            }
        } catch let error as NSError {
            NSLog("Could not fetch server information: \(error), \(error.userInfo)")
        }
        
     }
    
    func alertWithOkayButton(title: String, message: String) {
        if (!isShowingAlert) {
            isShowingAlert = true
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
            
            alert.addAction(UIAlertAction(title: "Okay", style: .Default, handler: { Void in
                self.isShowingAlert = false
            }))
            if var topController = UIApplication.sharedApplication().keyWindow?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                
                topController.presentViewController(alert, animated: true, completion: nil)
            }
        }
    }
    
    func isConnectedToNetwork() -> Bool {

        do {
            let reachability = try Reachability.reachabilityForInternetConnection()
            return reachability.isReachable()
        } catch ReachabilityError.FailedToCreateWithAddress(let address) {
            NSLog("Unable to create\nReachability with address:\n\(address)")
            return true
        } catch {
            NSLog("Other reachability error!")
            return true
        }
    }
    
}