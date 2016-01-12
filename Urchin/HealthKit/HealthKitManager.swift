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

class HealthKitManager {
    
    // MARK: Access, availability, authorization

    static let sharedInstance = HealthKitManager()
    private init() {}
    
    let healthStore: HKHealthStore? = {
        return HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()
    
    let isHealthDataAvailable: Bool = {
        return HKHealthStore.isHealthDataAvailable()
    }()
    
    func authorizationRequestedForBloodGlucoseSamples() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("authorizationRequestedForBloodGlucoseSamples")
    }
    
    func authorizationRequestedForWorkoutSamples() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("authorizationRequestedForWorkoutSamples")
    }
    
    func authorize(shouldAuthorizeBloodGlucoseSamples shouldAuthorizeBloodGlucoseSamples: Bool, shouldAuthorizeWorkoutSamples: Bool, completion: ((success:Bool, error:NSError!) -> Void)!)
    {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        var readTypes = Set<HKSampleType>()
        if (shouldAuthorizeBloodGlucoseSamples) {
            readTypes.insert(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!)
        }
        if (shouldAuthorizeWorkoutSamples) {
            readTypes.insert(HKObjectType.workoutType())
        }
        guard readTypes.count > 0 else {
            NSLog("\(__FUNCTION__): No health data authorization requested, ignoring")
            return
        }
        
        if (isHealthDataAvailable) {
            healthStore!.requestAuthorizationToShareTypes(nil, readTypes: readTypes) { (success, error) -> Void in
                if (shouldAuthorizeBloodGlucoseSamples) {
                    NSUserDefaults.standardUserDefaults().setBool(true, forKey: "authorizationRequestedForBloodGlucoseSamples");
                }
                if (shouldAuthorizeWorkoutSamples) {
                    NSUserDefaults.standardUserDefaults().setBool(true, forKey: "authorizationRequestedForWorkoutSamples");
                }
                NSUserDefaults.standardUserDefaults().synchronize()
                
                if (completion != nil) {
                    completion(success:success, error:error)
                }
            }
        } else {
            let error = NSError(
                            domain: "HealthKitManager",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey:"HealthKit is not available on this device"])
            if (completion != nil) {
                completion(success:false, error:error)
            }
        }
    }
    
    // MARK: Observation
    
    func startObservingBloodGlucoseSamples(resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!) {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (!bloodGlucoseObservationSuccessful) {
            if (bloodGlucoseObservationQuery != nil) {
                healthStore?.stopQuery(bloodGlucoseObservationQuery!)
            }
            
            let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
            bloodGlucoseObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
                [unowned self](query, observerQueryCompletion, error) in
                if error == nil {
                    self.bloodGlucoseObservationSuccessful = true
                    self.readBloodGlucoseSamples(resultsHandler)
                } else {
                    NSLog("\(__FUNCTION__): HealthKit observation error \(error), \(error!.userInfo)")
                    if (resultsHandler != nil) {
                        resultsHandler(nil, nil, error);
                    }
                }
                
                observerQueryCompletion()
            }
            healthStore?.executeQuery(bloodGlucoseObservationQuery!)
        }
    }
    
    func stopObservingBloodGlucoseSamples() {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (bloodGlucoseObservationSuccessful) {
            if (bloodGlucoseObservationQuery != nil) {
                healthStore?.stopQuery(bloodGlucoseObservationQuery!)
                bloodGlucoseObservationQuery = nil
            }
            bloodGlucoseObservationSuccessful = false
        }
    }
    
    // NOTE: resultsHandler is called on a separate process queue!
    func startObservingWorkoutSamples(resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!) {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (!workoutsObservationSuccessful) {
            if (workoutsObservationQuery != nil) {
                healthStore?.stopQuery(workoutsObservationQuery!)
            }
            
            let sampleType = HKObjectType.workoutType()
            workoutsObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
                [unowned self](query, observerQueryCompletion, error) in
                if error == nil {
                    self.workoutsObservationSuccessful = true
                    self.readWorkoutSamples(resultsHandler)
                } else {
                    NSLog("\(__FUNCTION__): HealthKit observation error \(error), \(error!.userInfo)")
                    if (resultsHandler != nil) {
                        resultsHandler(nil, nil, error);
                    }
                }
                
                observerQueryCompletion()
            }
            healthStore?.executeQuery(workoutsObservationQuery!)
        }
    }
    
    func stopObservingWorkoutSamples() {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (workoutsObservationSuccessful) {
            if (workoutsObservationQuery != nil) {
                healthStore?.stopQuery(workoutsObservationQuery!)
                workoutsObservationQuery = nil
            }
            workoutsObservationSuccessful = false
        }
    }
    
    // MARK: Background delivery
    
    func enableBackgroundDeliveryBloodGlucoseSamples() {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (!bloodGlucoseBackgroundDeliveryEnabled) {
            healthStore?.enableBackgroundDeliveryForType(
                HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!,
                frequency: HKUpdateFrequency.Immediate) {
                    success, error -> Void in
                    if (error == nil) {
                        self.bloodGlucoseBackgroundDeliveryEnabled = true
                        NSLog("\(__FUNCTION__): Enabled background delivery of health data")
                    } else {
                        NSLog("\(__FUNCTION__): Error enabling background delivery of health data \(error), \(error!.userInfo)")
                    }
            }
        }
    }
    
    func disableBackgroundDeliveryBloodGlucoseSamples() {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (bloodGlucoseBackgroundDeliveryEnabled) {
            healthStore?.disableBackgroundDeliveryForType(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!) {
                success, error -> Void in
                if (error == nil) {
                    self.bloodGlucoseBackgroundDeliveryEnabled = false
                    NSLog("\(__FUNCTION__): Disabled background delivery of health data")
                } else {
                    NSLog("\(__FUNCTION__): Error disabling background delivery of health data \(error), \(error!.userInfo)")
                }
            }
        }
    }
    
    func enableBackgroundDeliveryWorkoutSamples() {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (!workoutsBackgroundDeliveryEnabled) {
            healthStore?.enableBackgroundDeliveryForType(
                HKObjectType.workoutType(),
                frequency: HKUpdateFrequency.Immediate) {
                    success, error -> Void in
                    if (error == nil) {
                        self.workoutsBackgroundDeliveryEnabled = true
                        NSLog("\(__FUNCTION__): Enabled background delivery of health data")
                    } else {
                        NSLog("\(__FUNCTION__): Error enabling background delivery of health data \(error), \(error!.userInfo)")
                    }
            }
        }
    }
    
    func disableBackgroundDeliveryWorkoutSamples() {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if (workoutsBackgroundDeliveryEnabled) {
            healthStore?.disableBackgroundDeliveryForType(HKObjectType.workoutType()) {
                success, error -> Void in
                if (error == nil) {
                    self.workoutsBackgroundDeliveryEnabled = false
                    NSLog("\(__FUNCTION__): Disabled background delivery of health data")
                } else {
                    NSLog("\(__FUNCTION__): Error disabling background delivery of health data \(error), \(error!.userInfo)")
                }
            }
        }
    }
    
    // MARK: Private
    
    private func readBloodGlucoseSamples(resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!)
    {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        var queryAnchor: HKQueryAnchor?
        let queryAnchorData = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseQueryAnchor")
        if (queryAnchorData != nil) {
            queryAnchor = NSKeyedUnarchiver.unarchiveObjectWithData(queryAnchorData as! NSData) as? HKQueryAnchor
        }
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let sampleQuery = HKAnchoredObjectQuery(type: sampleType,
            predicate: nil,
            anchor: queryAnchor,
            limit: Int(HKObjectQueryNoLimit)) {
                [unowned self](query, newSamples, deletedSamples, newAnchor, error) -> Void in
                
                if (newAnchor != nil) {
                    let queryAnchorData = NSKeyedArchiver.archivedDataWithRootObject(newAnchor!)
                    // TODO: my - We should allow caller control of this in case caller, which provides resultsHandler,
                    // might do something atomically, as a transaction, with the batch data, and might need to avoid
                    // updating the anchor if the batch processing fails.
                    NSUserDefaults.standardUserDefaults().setObject(queryAnchorData, forKey: "bloodGlucoseQueryAnchor")
                    NSUserDefaults.standardUserDefaults().synchronize()
                }
                

                if (resultsHandler != nil) {
                    resultsHandler(newSamples, deletedSamples, error)
                } else {
                     self.logNewBloodGlucoseSamples(newSamples)
                     self.logDeletedBloodGlucoseSamples(deletedSamples)
                }
            }
        healthStore?.executeQuery(sampleQuery)
    }
    
    private func readWorkoutSamples(resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!)
    {
        guard isHealthDataAvailable else {
            NSLog("\(__FUNCTION__): Unexpected HealthKitManager call when health data not available")
            return
        }
        
        var queryAnchor: HKQueryAnchor?
        let queryAnchorData = NSUserDefaults.standardUserDefaults().objectForKey("workoutQueryAnchor")
        if (queryAnchorData != nil) {
            queryAnchor = NSKeyedUnarchiver.unarchiveObjectWithData(queryAnchorData as! NSData) as? HKQueryAnchor
        }
        
        let sampleType = HKObjectType.workoutType()
        let sampleQuery = HKAnchoredObjectQuery(type: sampleType,
            predicate: nil,
            anchor: queryAnchor,
            limit: Int(HKObjectQueryNoLimit)) {
                [unowned self](query, newSamples, deletedSamples, newAnchor, error) -> Void in
                
                if (newAnchor != nil) {
                    let queryAnchorData = NSKeyedArchiver.archivedDataWithRootObject(newAnchor!)
                    // TODO: my - We should allow caller control of this in case caller, which provides resultsHandler,
                    // might do something atomically, as a transaction, with the batch data, and might need to avoid
                    // updating the anchor if the batch processing fails.
                    NSUserDefaults.standardUserDefaults().setObject(queryAnchorData, forKey: "workoutQueryAnchor")
                    NSUserDefaults.standardUserDefaults().synchronize()
                }
                
                if (resultsHandler != nil) {
                     resultsHandler(newSamples, deletedSamples, error)
                } else {
                    self.logNewWorkoutSamples(newSamples)
                    self.logDeletedWorkoutSamples(deletedSamples)
                }
        }
        healthStore?.executeQuery(sampleQuery)
    }
    
    private func logNewBloodGlucoseSamples(samples: [HKSample]?) {
        guard samples != nil else {
            return
        }
        
        let samples = samples!
        NSLog("********* PROCESSING \(samples.count) new glucose samples ********* ")
        let serializer = OMHSerializer()
        for sample in samples {
            let jsonString = try! serializer.jsonForSample(sample)
            NSLog("Granola serialized glucose sample: \(jsonString)");
        }
    }
    
    private func logDeletedBloodGlucoseSamples(samples: [HKDeletedObject]?) {
        guard samples != nil else {
            return
        }
        
        let samples = samples!
        NSLog("********* PROCESSING \(samples.count) deleted glucose samples ********* ")
        for sample in samples {
            NSLog("Processed deleted glucose sample with UUID: \(sample.UUID)");
        }
    }
    
    private func logNewWorkoutSamples(samples: [HKSample]?) {
        guard samples != nil else {
            return
        }
        
        let samples = samples!
        NSLog("********* PROCESSING \(samples.count) new workout samples ********* ")
        let serializer = OMHSerializer()
        for sample in samples {
            let jsonString = try! serializer.jsonForSample(sample)
            NSLog("Granola serialized workout sample: \(jsonString)");
        }
    }
    
    private func logDeletedWorkoutSamples(samples: [HKDeletedObject]?) {
        guard samples != nil else {
            return
        }
        
        let samples = samples!
        NSLog("********* PROCESSING \(samples.count) deleted workout samples ********* ")
        for sample in samples {
            NSLog("Processed deleted workout sample with UUID: \(sample.UUID)");
        }
    }
    
    private var bloodGlucoseObservationSuccessful = false
    private var bloodGlucoseObservationQuery: HKObserverQuery?
    private var bloodGlucoseBackgroundDeliveryEnabled = false
    private var bloodGlucoseQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)

    private var workoutsObservationSuccessful = false
    private var workoutsObservationQuery: HKObserverQuery?
    private var workoutsBackgroundDeliveryEnabled = false
    private var workoutsQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)
}
