//
//  HealthKitManager.swift
//  Glucometer
//  This is the interface between the GlucoseRecord class and the HealthKit record
//
//  Created by Liam Goudge on 10/19/18.
//  This code is provided for the purpose of demonstration. Use is entirely at your own risk. No warranty is provided. No license for use in a commercial product.
//

import Foundation
import HealthKit

class HealthKitManager {
    
    let healthKitDataStore: HKHealthStore?
    
    let readableHKQuantityTypes: Set<HKQuantityType>?
    let writeableHKQuantityTypes: Set<HKQuantityType>?
    
    let glucoseQuantity = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
    var sequenceNumber: String = ""


    
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

    
    func writeBloodGlucoseToHealthKit(device: String, sequence: Int, glucoseValue: Double, timestamp: Date, offsetSecs: Int, sampleType: String, sampleLocation: String, mealContext: String) {
        
        print ("Device UUID: \(device) Sequence: \(sequence)")
        
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
                                                 metadata: [HKMetadataKeyTimeZone: tz,
                                                            "BGMSequenceNumber": String(sequence),
                                                            "BloodSampleType": sampleType,
                                                            "SampleLocation": sampleLocation,
                                                            "MealContext": mealContext])
        
        healthKitDataStore?.save([glucoseSampleData]) { (success, error) in
            //print("Glucose data saved to HealthKit.")
        }
    }
    
    func findLastBloodGlucoseInHealthKit(completion: @escaping (Bool, Int) -> ()) {
        
        print ("Read last HK glucose")
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false) // StartDate is date when record enetered not the date in the record itself
        let query = HKSampleQuery(sampleType: glucoseQuantity!, predicate: nil, limit: 10, sortDescriptors: [sortDescriptor]) { (query, results, error) in
            
            guard let result = results?.first as? HKQuantitySample else {
                print("No HK records")
                completion(false, 0)
                return
            }
            
            print ("Last HK reading: \(result)")
            
            guard let num = result.metadata else {
                print("No meta data records")
                completion(false, 0)
                return
            }
            
            let seq = num["BGMSequenceNumber"]
            
            guard let seq2 = seq else {
                print("No sequence  records")
                completion(false, 0)
                return
            }
            
            self.sequenceNumber = seq2 as! String
            completion(true, Int(self.sequenceNumber) ?? 0)
            
            guard self.sequenceNumber == result.metadata!["BGMSequenceNumber"] as! String? else {
                print("No SequenceNumber")
                completion(false, 0)
                return
            }
            
        }
        self.healthKitDataStore?.execute(query)
        
        
    }
    
} // end





