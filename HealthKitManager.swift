//
//  HealthKitManager.swift
//  Glucometer
//  This is the interface between the GlucoseRecord class and the HealthKit record
//
//  Created by Liam Goudge on 10/19/18.
//  tag for Git1

import Foundation
import HealthKit

class HealthKitManager {
    
    let healthKitDataStore: HKHealthStore?
    
    let readableHKQuantityTypes: Set<HKQuantityType>?
    let writeableHKQuantityTypes: Set<HKQuantityType>?
    
    let glucoseQuantity = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
    
    init () {
        
        if HKHealthStore.isHealthDataAvailable() {
            self.healthKitDataStore = HKHealthStore()
            
            writeableHKQuantityTypes = [glucoseQuantity!]
            readableHKQuantityTypes = [glucoseQuantity!]
           
            healthKitDataStore?.requestAuthorization(toShare: writeableHKQuantityTypes, read: readableHKQuantityTypes, completion: {(success,error) in
                if success {
                    // print ("Qtys worked")
                }
                    
                else {
                    // print ("Qtys did not work")
                    
                }})
            
        }
        else {
            self.healthKitDataStore = nil
            writeableHKQuantityTypes = nil
            readableHKQuantityTypes = nil
        }
    }

    
    func writeBloodGlucoseToHealthKit(glucoseValue: Double, timestamp: Date, offsetSecs: Int) {
        
        let glucoseMassUnit = HKUnit(from: "mg/dL")
        let glucosemgperdlQuantity = HKQuantity(unit: glucoseMassUnit, doubleValue: glucoseValue)
        
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            fatalError("*** Unable to create glucose quantity type***")
        }
        
        let userTimeZone = NSTimeZone.init(forSecondsFromGMT: offsetSecs)
        
        guard let tz = userTimeZone.name as String? else {
            fatalError("*** Unable to create timeZone for quantity ***")
        }
        
        let glucoseSampleData = HKQuantitySample(type: glucoseType,
                                                 quantity: glucosemgperdlQuantity,
                                                 start: timestamp,
                                                 end: timestamp,
                                                 metadata: [HKMetadataKeyTimeZone: tz ])
        
        healthKitDataStore?.save([glucoseSampleData]) { (success, error) in
            //print("Glucose data saved to HealthKit.")
        }
    }
    
}






