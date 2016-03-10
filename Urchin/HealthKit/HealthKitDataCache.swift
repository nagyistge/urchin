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

import HealthKit
import RealmSwift
import CocoaLumberjack
import Granola

// TODO: my - Need to set up a periodic task to perodically drain the Realm db and upload those events to service, this should be able to be done as background task even when app is not active, and periodically when active

class HealthKitDataCache {
    // MARK: Access, authorization
    
    static let sharedInstance = HealthKitDataCache()
    private init() {
        var config = Realm.Configuration(
            schemaVersion: 4,

            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < 4) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically

                    DDLogInfo("Migrating Realm from 0 to 4")
                }
            }
        )
        
        // Append nosync to avoid iCloud backup of realm db
        config.path = NSURL.fileURLWithPath(config.path!)
            .URLByAppendingPathExtension("nosync")
            .path
        
        DDLogInfo("Realm path: \(config.path)")
        
        // Set this as the configuration used for the default Realm
        Realm.Configuration.defaultConfiguration = config

        var cacheTime = NSUserDefaults.standardUserDefaults().objectForKey("lastCacheTimeBloodGlucoseSamples")
        if (cacheTime != nil) {
            lastCacheTimeBloodGlucoseSamples = cacheTime as! NSDate
            lastCacheCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastCacheCountBloodGlucoseSamples")
            totalCacheCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalCacheCountBloodGlucoseSamples")
        }
        
        cacheTime = NSUserDefaults.standardUserDefaults().objectForKey("lastCacheTimeWorkoutSamples")
        if (cacheTime != nil) {
            lastCacheTimeWorkoutSamples = cacheTime as! NSDate
            lastCacheCountWorkoutSamples = NSUserDefaults.standardUserDefaults().integerForKey("lastCacheCountWorkoutSamples")
            totalCacheCountWorkoutSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalCacheCountWorkoutSamples")
        }
    }
    
    private(set) var totalCacheCountBloodGlucoseSamples = -1
    private(set) var lastCacheCountBloodGlucoseSamples = -1
    private(set) var lastCacheTimeBloodGlucoseSamples = NSDate.distantPast()

    private(set) var totalCacheCountWorkoutSamples = -1
    private(set) var lastCacheCountWorkoutSamples = -1
    private(set) var lastCacheTimeWorkoutSamples = NSDate.distantPast()
    
    var totalCacheCount: Int {
        get {
            var count = 0
            if (lastCacheCountBloodGlucoseSamples > 0) {
                count += lastCacheCountBloodGlucoseSamples
            }
            if (lastCacheCountWorkoutSamples > 0) {
                count += lastCacheCountWorkoutSamples
            }
            return count
        }
    }
    
    var lastCacheCount: Int {
        get {
            let time = lastCacheTime
            var count = 0
            if (lastCacheCountBloodGlucoseSamples > 0 && fabs(lastCacheTimeBloodGlucoseSamples.timeIntervalSinceDate(time)) < 60) {
                count += lastCacheCountBloodGlucoseSamples
            }
            if (lastCacheCountWorkoutSamples > 0 && fabs(lastCacheTimeWorkoutSamples.timeIntervalSinceDate(time)) < 60) {
                count += lastCacheCountWorkoutSamples
            }
            return count
        }
    }
    
    var lastCacheTime: NSDate {
        get {
            var time = NSDate.distantPast()
            if (lastCacheCountBloodGlucoseSamples > 0 && time.compare(lastCacheTimeBloodGlucoseSamples) == .OrderedAscending) {
                time = lastCacheTimeBloodGlucoseSamples
            }
            if (lastCacheCountWorkoutSamples > 0 && time.compare(lastCacheTimeWorkoutSamples) == .OrderedAscending) {
                time = lastCacheTimeWorkoutSamples
            }
            return time
        }
    }
    
    enum Notifications {
        static let CachedBloodGlucoseSamples = "HealthKitDataCache-observed-\(HKQuantityTypeIdentifierBloodGlucose)"
        static let CachedWorkoutSamples = "HealthKitDataCache-observed-\(HKWorkoutTypeIdentifier)"
    }

    func authorizeAndStartCaching(
            shouldCacheBloodGlucoseSamples shouldCacheBloodGlucoseSamples: Bool,
            shouldCacheWorkoutSamples: Bool)
    {
        HealthKitManager.sharedInstance.authorize(
            shouldAuthorizeBloodGlucoseSamples: shouldCacheBloodGlucoseSamples,
            shouldAuthorizeWorkoutSamples: shouldCacheWorkoutSamples) {
            success, error -> Void in
            if (error == nil) {
                self.startCaching(
                    shouldCacheBloodGlucoseSamples: shouldCacheBloodGlucoseSamples,
                    shouldCacheWorkoutSamples: shouldCacheWorkoutSamples)
            } else {
                DDLogError("Error authorizing health data \(error), \(error!.userInfo)")
            }
        }
    }
    
    // MARK: Cache control
    
    func startCaching(shouldCacheBloodGlucoseSamples shouldCacheBloodGlucoseSamples: Bool, shouldCacheWorkoutSamples: Bool)
    {
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            if (shouldCacheBloodGlucoseSamples) {
                HealthKitManager.sharedInstance.startObservingBloodGlucoseSamples() {
                    (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in
                    
                    if (newSamples != nil) {
                        DDLogInfo("********* PROCESSING \(newSamples!.count) new blood glucose samples ********* ")
                    }
                    
                    if (deletedSamples != nil) {
                        DDLogInfo("********* PROCESSING \(deletedSamples!.count) deleted blood glucose samples ********* ")
                    }
                    
                    self.writeSamplesToDb(typeIdentifier: HKQuantityTypeIdentifierBloodGlucose, samples: newSamples, deletedSamples: deletedSamples, error: error)
                    
                    self.updateLastCacheBloodGlucoseSamples(newSamples: newSamples, deletedSamples: deletedSamples)
                }
                HealthKitManager.sharedInstance.enableBackgroundDeliveryBloodGlucoseSamples()
            }
            if (shouldCacheWorkoutSamples) {
                HealthKitManager.sharedInstance.startObservingWorkoutSamples() {
                    (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in

                    if (newSamples != nil) {
                        DDLogInfo("********* PROCESSING \(newSamples!.count) new workout samples ********* ")
                    }
                    
                    if (deletedSamples != nil) {
                        DDLogInfo("********* PROCESSING \(deletedSamples!.count) deleted workout samples ********* ")
                    }

                    self.writeSamplesToDb(typeIdentifier: HKWorkoutTypeIdentifier, samples: newSamples, deletedSamples: deletedSamples, error: error)
                    
                    self.updateLastCacheWorkoutSamples(newSamples: newSamples, deletedSamples: deletedSamples)
                }
                HealthKitManager.sharedInstance.enableBackgroundDeliveryWorkoutSamples()
            }
        }
    }
    
    func stopCaching(shouldStopCachingBloodGlucoseSamples shouldStopCachingBloodGlucoseSamples: Bool, shouldStopCachingWorkoutSamples: Bool) {
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            if (shouldStopCachingBloodGlucoseSamples) {
                HealthKitManager.sharedInstance.stopObservingBloodGlucoseSamples()
                HealthKitManager.sharedInstance.disableBackgroundDeliveryBloodGlucoseSamples()
            }
            if (shouldStopCachingWorkoutSamples) {
                HealthKitManager.sharedInstance.stopObservingWorkoutSamples()
                HealthKitManager.sharedInstance.disableBackgroundDeliveryWorkoutSamples()
            }
        }
    }
    
    // MARK: Private
    
    private func writeSamplesToDb(typeIdentifier typeIdentifier: String, samples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) {
        guard error == nil else {
            DDLogError("Error processing samples \(error), \(error!.userInfo)")
            return
        }
        
        if (samples != nil) {
            writeNewSamplesToDb(typeIdentifier: typeIdentifier, samples: samples!)
        }
        
        if (deletedSamples != nil) {
            writeDeletedSamplesToDb(deletedSamples!)
        }
    }
    
    private func writeNewSamplesToDb(typeIdentifier typeIdentifier: String, samples: [HKSample]) {
        do {
            let realm = try Realm()

            realm.beginWrite()
            
            for sample in samples {
                let sourceRevision = sample.sourceRevision
                let source = sourceRevision.source
                let sourceName = source.name
                let sourceBundleIdentifier = source.bundleIdentifier
                let sourceVersion = sourceRevision.version
                
                DDLogInfo("Source:")
                DDLogInfo("\tName: \(sourceName)")
                DDLogInfo("\tBundleIdentifier: \(sourceBundleIdentifier)")
                DDLogInfo("\tVersion: \(sourceVersion)")

                if typeIdentifier == HKQuantityTypeIdentifierBloodGlucose &&
                   sourceName.lowercaseString.rangeOfString("dexcom") == nil {
                    DDLogInfo("Ignoring non-Dexcom glucose data")
                    continue
                }

                let device = sample.device
                let deviceName = device?.name
                let deviceManufacturer = device?.manufacturer
                let deviceModel = device?.model
                let deviceHardwareVersion = device?.hardwareVersion
                let deviceFirmwareVersion = device?.firmwareVersion
                let deviceSoftwareVersion = device?.softwareVersion
                let deviceLocalIdentifier = device?.localIdentifier
                let deviceUDIDeviceIdentifier = device?.UDIDeviceIdentifier
                
                DDLogInfo("Device:")
                DDLogInfo("\tName: \(deviceName)")
                DDLogInfo("\tManufacturer: \(deviceManufacturer)")
                DDLogInfo("\tModel: \(deviceModel)")
                DDLogInfo("\tHardwareVersion: \(deviceHardwareVersion)")
                DDLogInfo("\tFirmwareVersion: \(deviceFirmwareVersion)")
                DDLogInfo("\tSoftwareVersion: \(deviceSoftwareVersion)")
                DDLogInfo("\tLocalIdentifier: \(deviceLocalIdentifier)")
                DDLogInfo("\tUDIDeviceIdentifier: \(deviceUDIDeviceIdentifier)")

                let healthKitData = HealthKitData()

                healthKitData.id = sample.UUID.UUIDString
                healthKitData.healthKitTypeIdentifier = typeIdentifier
                healthKitData.action = HealthKitData.Action.Added.rawValue

                healthKitData.sourceName = sourceName
                healthKitData.sourceBundleIdentifier = sourceBundleIdentifier
                healthKitData.sourceVersion = sourceVersion ?? ""
                healthKitData.startDate = sample.startDate
                healthKitData.endDate = sample.endDate
                
                if let quantitySample = sample as? HKQuantitySample {
                    healthKitData.units = "mg/dL"
                    let unit = HKUnit(fromString: healthKitData.units)
                    healthKitData.value = quantitySample.quantity.doubleValueForUnit(unit)
                }
                
                let serializer = OMHSerializer()
                healthKitData.granolaJson = try serializer.jsonForSample(sample)

                DDLogInfo("Granola sample:\n\(healthKitData.granolaJson)");
                
                // TODO: my - Confirm that composite key of id + action does not exist before attempting to add to avoid dups?
                realm.add(healthKitData)
            }
            
            try realm.commitWrite()
        } catch let error as NSError! {
            DDLogError("Error writing new samples \(error), \(error!.userInfo)")
        }
    }
    
    private func writeDeletedSamplesToDb(deletedSamples: [HKDeletedObject]) {
        do {
            let realm = try Realm()
            
            try realm.write() {
                for sample in deletedSamples {
                    let healthKitData = HealthKitData()
                    healthKitData.id = sample.UUID.UUIDString
                    healthKitData.action = HealthKitData.Action.Deleted.rawValue
                    healthKitData.granolaJson = ""

                    DDLogInfo("Deleted sample: \(healthKitData.id)");

                    // TODO: my - Confirm that composite key of id + action does not exist before attempting to add to avoid dups?
                    realm.add(healthKitData)
                }
            }
        } catch let error as NSError! {
            DDLogError("Error writing deleted samples \(error), \(error.userInfo)")
        }
    }
    
    private func updateLastCacheBloodGlucoseSamples(newSamples newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?) {
        var totalCount = 0
        if (newSamples != nil) {
            totalCount += newSamples!.count
        }
        if (deletedSamples != nil) {
            totalCount += deletedSamples!.count
        }
        if (totalCount > 0) {
            lastCacheCountBloodGlucoseSamples = totalCount
            lastCacheTimeBloodGlucoseSamples = NSDate()
            NSUserDefaults.standardUserDefaults().setObject(lastCacheTimeBloodGlucoseSamples, forKey: "lastCacheTimeBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastCacheCountBloodGlucoseSamples, forKey: "lastCacheCountBloodGlucoseSamples")
            let totalCacheCountBloodGlucoseSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalCacheCountBloodGlucoseSamples") + lastCacheCountBloodGlucoseSamples
            NSUserDefaults.standardUserDefaults().setObject(totalCacheCountBloodGlucoseSamples, forKey: "totalCacheCountBloodGlucoseSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.CachedBloodGlucoseSamples, object: nil))
            }
        }
    }
    
    private func updateLastCacheWorkoutSamples(newSamples newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?) {
        var totalCount = 0
        if (newSamples != nil) {
            totalCount += newSamples!.count
        }
        if (deletedSamples != nil) {
            totalCount += deletedSamples!.count
        }
        if (totalCount > 0) {
            lastCacheCountWorkoutSamples = totalCount
            lastCacheTimeWorkoutSamples = NSDate()
            NSUserDefaults.standardUserDefaults().setObject(lastCacheTimeWorkoutSamples, forKey: "lastCacheTimeWorkoutSamples")
            NSUserDefaults.standardUserDefaults().setInteger(lastCacheCountWorkoutSamples, forKey: "lastCacheCountWorkoutSamples")
            let totalCacheCountWorkoutSamples = NSUserDefaults.standardUserDefaults().integerForKey("totalCacheCountWorkoutSamples") + lastCacheCountBloodGlucoseSamples
            NSUserDefaults.standardUserDefaults().setObject(totalCacheCountWorkoutSamples, forKey: "totalCacheCountWorkoutSamples")
            NSUserDefaults.standardUserDefaults().synchronize()
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: Notifications.CachedWorkoutSamples, object: nil))
            }
        }
    }
}
