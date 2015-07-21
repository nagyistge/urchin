//
//  APIConnect.swift
//  urchin
//
//  Created by Ethan Look on 7/16/15.
//  Copyright (c) 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class APIConnector {
    
    var baseURL: String = "https://devel-api.tidepool.io"
    var x_tidepool_session_token: String = ""
    var user: User?
    
    func login(loginVC: LogInViewController, username: String, password: String) {
        
        let loginString = NSString(format: "%@:%@", username, password)
        let loginData: NSData = loginString.dataUsingEncoding(NSUTF8StringEncoding)!
        let base64LoginString = loginData.base64EncodedStringWithOptions(nil)
        
        if (loginVC.rememberMe) {
            self.saveLogin(base64LoginString)
        } else {
            self.saveLogin("")
        }
        
        loginRequest(loginVC, base64LoginString: base64LoginString)
    }
    
    func loginRequest(loginVC: LogInViewController, base64LoginString: String) {
        // create the request
        let urlString = baseURL + "/auth/login"
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        let loading = LoadingView(text: "Logging in...")
        let loadingX = loginVC.view.frame.width / 2 - loading.frame.width / 2
        let loadingY = loginVC.view.frame.height / 2 - loading.frame.height / 2
        loading.frame.origin = CGPoint(x: loadingX, y: loadingY)
        loginVC.view.addSubview(loading)
        loginVC.view.bringSubviewToFront(loading)
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            var jsonResult: NSDictionary = (NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary)!
            
            if let code = jsonResult.valueForKey("code") as? Int {
                if (code == 401) {
                    println("incorrect login information")
                    self.alertWithOkayButton("Invalid Login", message: "Wrong username or password.")
                } else {
                    println("an unknown error occurred")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while logging in. We are working hard to resolve this issue.")
                }
            } else {
                if let httpResponse = response as? NSHTTPURLResponse {
                    println("login \(httpResponse.statusCode)")
                    
                    if (httpResponse.statusCode == 200) {
                        var jsonResult: NSDictionary = (NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary)!
                        
                        if let sessionToken = httpResponse.allHeaderFields["x-tidepool-session-token"] as? String {
                            self.x_tidepool_session_token = sessionToken
                            self.user = User(userid: jsonResult.valueForKey("userid") as! String, apiConnector: self)
                            loginVC.makeTransition(self)
                        }
                    } else {
                        println("an unknown error occurred")
                        self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while logging in. We are working hard to resolve this issue.")
                    }
                } else {
                    println("an unknown error occurred")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while logging in. We are working hard to resolve this issue.")
                }
            }
            loading.removeFromSuperview()
        }
    }
    
    func login(loginVC: LogInViewController) {
        
        // Store the appDelegate
        let appDelegate =
        UIApplication.sharedApplication().delegate as! AppDelegate
        
        // Store the managedContext
        let managedContext = appDelegate.managedObjectContext!
        
        // Open a new fetch request
        let fetchRequest = NSFetchRequest(entityName:"Login")
        
        var error: NSError?
        
        // Execute the fetch
        let fetchedResults =
        managedContext.executeFetchRequest(fetchRequest,
            error: &error) as? [NSManagedObject]
        
        if let results = fetchedResults {
            if (results.count != 0) {
                let expiration = results[0].valueForKey("expiration") as! NSDate
                let dateFormatter = NSDateFormatter()
                if (expiration.timeIntervalSinceNow < 0) {

                    // Login has expired!
                    
                    // Set the value to the new saved login
                    results[0].setValue("", forKey: "login")
                    
                    // Save the expiration date (6 mo.s in advance)
                    let dateShift = NSDateComponents()
                    dateShift.month = 6
                    let calendar = NSCalendar.currentCalendar()
                    let date = calendar.dateByAddingComponents(dateShift, toDate: NSDate(), options: nil)!
                    results[0].setValue(date, forKey: "expiration")
                    
                    // Attempt to save the login
                    var error: NSError?
                    if !managedContext.save(&error) {
                        println("Could not save \(error), \(error?.userInfo)")
                    }
                }
                let base64LoginString = results[0].valueForKey("login") as! String
                
                if (base64LoginString != "") {
                    // Login information exists
                    
                    self.loginRequest(loginVC, base64LoginString: base64LoginString)
                }
            }
        } else {
            println("Could not fetch \(error), \(error!.userInfo)")
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
        
        var error: NSError?
        
        // Execute the fetch
        let fetchedResults =
        managedContext.executeFetchRequest(fetchRequest,
            error: &error) as? [NSManagedObject]
        
        if let results = fetchedResults {
            if (results.count == 0) {
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
                let date = calendar.dateByAddingComponents(dateShift, toDate: NSDate(), options: nil)!
                loginObj.setValue(date, forKey: "expiration")
                
                // Save the login
                var errorTwo: NSError?
                if !managedContext.save(&errorTwo) {
                    println("Could not save \(errorTwo), \(errorTwo?.userInfo)")
                }
            } else if (results.count == 1) {
                // Set the value to the new saved login
                results[0].setValue(login, forKey: "login")
                
                // Save the expiration date (6 mo.s in advance)
                let dateShift = NSDateComponents()
                dateShift.month = 6
                let calendar = NSCalendar.currentCalendar()
                let date = calendar.dateByAddingComponents(dateShift, toDate: NSDate(), options: nil)!
                results[0].setValue(date, forKey: "expiration")
                
                // Attempt to save the login
                var errorTwo: NSError?
                if !managedContext.save(&errorTwo) {
                    println("Could not save \(errorTwo), \(errorTwo?.userInfo)")
                }
            }
        }  else {
            println("Could not fetch \(error), \(error!.userInfo)")
        }
    }
    
    func logout(notesVC: NotesViewController) {
        
        self.saveLogin("")
        
        // /auth/logout
        
        // create the request
        let urlString = baseURL + "/auth/logout"
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        request.setValue("\(x_tidepool_session_token)", forHTTPHeaderField: "x-tidepool-session-token")
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            if let httpResponse = response as? NSHTTPURLResponse {
                println(httpResponse.statusCode)
                if (httpResponse.statusCode == 200) {
                    notesVC.dismissViewControllerAnimated(true, completion: {
                        self.user = nil
                        self.x_tidepool_session_token = ""
                    })
                } else {
                    println("an unknown error occurred")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while logging out. We are working hard to resolve this issue.")
                }
            } else {
                println("an unknown error occurred")
                self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while logging out. We are working hard to resolve this issue.")
            }
        }
    }
    
    func findProfile(otherUser: User) {
        // '/metadata/' + userId + '/profile'
        
        let urlString = baseURL + "/metadata/" + otherUser.userid + "/profile"
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "GET"
        request.setValue("\(x_tidepool_session_token)", forHTTPHeaderField: "x-tidepool-session-token")
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            if let httpResponse = response as? NSHTTPURLResponse {
                println(httpResponse.statusCode)
                if (httpResponse.statusCode == 200) {
                    var userDict: NSDictionary = (NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary)!
                    
                    otherUser.processUserDict(userDict)
                    
                    // Send notification to NotesVC to handle new note that was just created
                    let notification = NSNotification(name: "anotherGroup", object: nil)
                    NSNotificationCenter.defaultCenter().postNotification(notification)
                } else {
                    println("an unknown error occurred")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while fetching profile info. We are working hard to resolve this issue.")
                }
            } else {
                println("an unknown error occurred")
                self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while fetching profile info. We are working hard to resolve this issue.")
            }
        }
    }
    
    func getAllViewableUsers(notesVC: NotesViewController) {
        // '/access/groups/' + userId
        
        let urlString = baseURL + "/access/groups/" + user!.userid
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "GET"
        request.setValue("\(x_tidepool_session_token)", forHTTPHeaderField: "x-tidepool-session-token")
        
        let loading = LoadingView(text: "Loading teams...")
        let loadingX = notesVC.notesTable.frame.width / 2 - loading.frame.width / 2
        let loadingY = notesVC.notesTable.frame.height / 2 - loading.frame.height / 2
        loading.frame.origin = CGPoint(x: loadingX, y: loadingY)
        notesVC.view.addSubview(loading)
        notesVC.view.bringSubviewToFront(loading)
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            if let httpResponse = response as? NSHTTPURLResponse {
                println(httpResponse.statusCode)
                if (httpResponse.statusCode == 200) {
                    var jsonResult: NSDictionary = (NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary)!
                    
                    for key in jsonResult.keyEnumerator() {
                        let group = User(userid: key as! String, apiConnector: self)
                        notesVC.groups.insert(group, atIndex: 0)
                    }
                } else {
                    println("an unknown error occurred")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while fetching teams. We are working hard to resolve this issue.")
                }
            } else {
                println("an unknown error occurred")
                self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while fetching teams. We are working hard to resolve this issue.")
            }
            loading.removeFromSuperview()
        }
    }
    
    func getNotesForUserInDateRange(notesVC: NotesViewController, userid: String, start: NSDate, end: NSDate) {
        // '/message/notes/' + userId + '?starttime=' + start + '&endtime=' + end
        // Only top level notes
        
        // create the request
        let dateFormatter = NSDateFormatter()
        let urlString = baseURL + "/message/notes/" + userid + "?starttime=" + dateFormatter.isoStringFromDate(start) + "&endtime="  + dateFormatter.isoStringFromDate(end)
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "GET"
        request.setValue("\(x_tidepool_session_token)", forHTTPHeaderField: "x-tidepool-session-token")
        
        notesVC.loadingNotes = true
        notesVC.numberFetches++
        
        let loading = LoadingView(text: "Loading notes...")
        let loadingX = notesVC.notesTable.frame.width / 2 - loading.frame.width / 2
        let loadingY = notesVC.notesTable.frame.height / 2 - loading.frame.height / 2
        loading.frame.origin = CGPoint(x: loadingX, y: loadingY)
        notesVC.view.addSubview(loading)
        notesVC.view.bringSubviewToFront(loading)
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            if let httpResponse = response as? NSHTTPURLResponse {
                println(httpResponse.statusCode)
                
                if (httpResponse.statusCode == 200) {
                    var notes: [Note] = []
                    
                    var jsonResult: NSDictionary = (NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary)!
                    
                    var messages: NSArray = jsonResult.valueForKey("messages") as! NSArray
                    
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
                    println("no notes in range \(httpResponse.statusCode), userid: \(userid)")
                    self.alertWithOkayButton("No notes in range", message: "No more notes in this 3-month date range for user with userid: \(userid). There may be more notes for this user in the next 3 months.")
                } else {
                    println("an unknown error occurred \(httpResponse.statusCode)")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while fetching notes. We are working hard to resolve this issue.")
                }
                
                notesVC.numberFetches--
                if (notesVC.numberFetches == 0) {
                    notesVC.loadingNotes = false
                }
            } else {
                println("an unknown error occurred")
                self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while fetching notes. We are working hard to resolve this issue.")
            }
            loading.removeFromSuperview()
        }
    }
    
    func doPostWithNote(notesVC: NotesViewController, note: Note) {
        // '/message/send/' + message.groupid
        
        // create the request
        let urlString = baseURL + "/message/send/" + note.groupid
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        request.setValue("\(x_tidepool_session_token)", forHTTPHeaderField: "x-tidepool-session-token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonObject = note.dictionaryFromNote()
        var err: NSError?
        request.HTTPBody = NSJSONSerialization.dataWithJSONObject(jsonObject, options: nil, error: &err)
        
        println(NSJSONSerialization.isValidJSONObject(jsonObject))
        println(NSJSONSerialization.JSONObjectWithData(NSJSONSerialization.dataWithJSONObject(jsonObject, options: nil, error: nil)!, options: nil, error: nil)!)
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            if let httpResponse = response as? NSHTTPURLResponse {
                println(httpResponse.statusCode)
                
                if (httpResponse.statusCode == 201) {
                    var jsonResult: NSDictionary = (NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers, error: nil) as? NSDictionary)!
                    
                    note.id = jsonResult.valueForKey("id") as! String
                    
                    notesVC.notes.insert(note, atIndex: 0)
                    // filter the notes, sort the notes, reload notes table
                    notesVC.filterNotes()
                    notesVC.notesTable.reloadData()
                    
                } else {
                    println("an unknown error occurred")
                    self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while posting the note. We are working hard to resolve this issue.")
                }
            } else {
                println("an unknown error occurred")
                self.alertWithOkayButton("Unknown Error Occurred", message: "An unknown error occurred while posting the note. We are working hard to resolve this issue.")
            }
        }
    }
    
    func editNote(note: Note) {
        // '/message/edit/' + note.id
        
        // create the request
        let urlString = baseURL + "/message/edit/" + note.id
        println(urlString)
        let url = NSURL(string: urlString)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "PUT"
        request.setValue("\(x_tidepool_session_token)", forHTTPHeaderField: "x-tidepool-session-token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonObject = note.updatesFromNote()
        var err: NSError?
        request.HTTPBody = NSJSONSerialization.dataWithJSONObject(jsonObject, options: nil, error: &err)
        
        println(NSJSONSerialization.isValidJSONObject(jsonObject))
        println(NSJSONSerialization.JSONObjectWithData(NSJSONSerialization.dataWithJSONObject(jsonObject, options: nil, error: nil)!, options: nil, error: nil)!)
        
        println(note.id)
        
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
            
            if let httpResponse = response as? NSHTTPURLResponse {
                println(httpResponse.statusCode)
            }
        }
    }
    
    func alertWithOkayButton(title: String, message: String) {
        var unknownErrorAlert: UIAlertView = UIAlertView()
        unknownErrorAlert.title = title
        unknownErrorAlert.message = message
        unknownErrorAlert.addButtonWithTitle("Okay")
        unknownErrorAlert.show()
    }
}