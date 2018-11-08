//
//  GlucoseRecord.swift
//  Glucometer
//  This class is the Model for glucose data. It parses the raw data from the BLE glucometer to derive measurement object parameters
//
//  Created by Liam Goudge on 10/15/18.
//  This code is provided for the purpose of demonstration. Use is entirely at your own risk. No warranty is provided. No license for use in a commercial product.
//

import Foundation
import HealthKit

class GlucoseData {
    
    var viewControllerHandle: ViewController!
    
    var records = [Record]()
    var sensorFlags = Flags()
    
    let hk = HealthKitManager()
    var sequenceNumber = Int()
    
    struct Flags {
        var DeviceBatteryLowTrue: Bool = false
        var SensorMalfunction: Bool = false
        var SampleSizeInsufficient: Bool = false
        var StripInsertionError: Bool = false
        var IncorrectStrip: Bool = false
        var ResultTooHighForDevice: Bool = false
        var ResultTooLowForDevice: Bool = false
        var TempTooHigh: Bool = false
        var TempTooLow: Bool = false
        var ReadInterrupted: Bool = false
        var GeneralDeviceFault: Bool = false
        var TimeFault: Bool = false
        var Reserved: Bool = false
    }
    
    struct Record {
        var deviceID: String
        var sequenceNumber:Int
        var baseTime:Date
        var timeOffsetSecs:Int
        var glucoseConcentration:Float
        var glucoseConcentrationUnits: String
        var bloodType:String
        var sampleLocation:String
        //var sensorFlags: Flags
        var mealContext: String
    }
    
    func readHK() {
        
        self.hk.findLastBloodGlucoseInHealthKit(completion: { (result, sequence) -> Void in
            
            if !(result) {
                self.sequenceNumber = sequence // No HK data on iPhone so is set to zero
            }
            
            else {
                self.sequenceNumber = sequence
            }
            
        })
        
    }
    
    
    func writeRecord(deviceID: String, sequenceNumber: Int, baseTime: Date, timeOffsetSecs: Int, glucoseConcentration: Float, glucoseConcentrationUnits: String, sampleType: String, sampleLocation: String, mealContext: String) {
        
        
        var glucoseValueHK = Float()
        
        if glucoseConcentrationUnits == "KgperL" {
            glucoseValueHK = glucoseConcentration * 100000 // convert to mg/dL for HK
        }
        
        else {
            glucoseValueHK = glucoseConcentration // leave as mols/L
        }

        
        let theRecord = Record(deviceID: deviceID,
                               sequenceNumber: sequenceNumber,
                               baseTime: baseTime,
                               timeOffsetSecs: timeOffsetSecs,
                               glucoseConcentration: glucoseConcentration,
                               glucoseConcentrationUnits: glucoseConcentrationUnits,
                               bloodType: sampleType,
                               sampleLocation: sampleLocation,
                               //sensorFlags: sensorFlags,
                               mealContext: mealContext)
        
        records.append(theRecord)
        viewControllerHandle.textDisplay.text.append("Store record: \(theRecord) \n\n")
        
        hk.writeBloodGlucoseToHealthKit(device: deviceID,
                                        sequence: sequenceNumber,
                                        glucoseValue: Double(glucoseValueHK),
                                        timestamp: baseTime,
                                        offsetSecs: timeOffsetSecs,
                                        sampleType: sampleType,
                                        sampleLocation: sampleLocation,
                                        mealContext: mealContext)
    }
    
    func addNewRecord(newRecord: ([Int],[Int], String) ) {
        
        var newMeasurement: [Int] = newRecord.0
        
        // First construct the UTC date from base time
        let calendar = Calendar.current
        var components = DateComponents()
        
        components.day = newMeasurement[6]
        components.month = newMeasurement[5]
        components.year = ((newMeasurement[4] << 8) | newMeasurement[3])
        
        components.hour = newMeasurement[7]
        components.minute = newMeasurement[8]
        components.second = newMeasurement[9]
        components.timeZone = TimeZone(identifier: "UTC")
        
        let UTCRecord = calendar.date(from: components)
        
        // Figure out time offset between base time and user-facing time. Wants offset in seconds for HealthKit timezone metadata
        let value:Int = (newMeasurement[11] << 8) | (newMeasurement[10])
        var mantissa:Int = (value & 0xfff)
        mantissa = mantissa > 0x7ff ? -((~mantissa & 0xfff)+1) : (mantissa) // Decode 2's complement of 12-bit value if negative
        let timeOffsetSecs:Int = mantissa * 60
        
        // Figure out floating point glucose concentration
        let exp2c:Int = (newMeasurement[13] >> 4) // Isolate the signed 4-bit exponent in MSB
        let exponent:Int = exp2c > 0x7 ? -((~exp2c & 0b1111)+1) : (exp2c) // Decode 2's complement of 4-bit value if negative
        mantissa = ((newMeasurement[13] & 0b1111) << 8) | (newMeasurement[12])
        let glucose = Float(mantissa) * pow(10,Float(exponent))
        
        // Parse the Information Flags in Byte 0
        let flagByte: UInt8 = UInt8(newMeasurement[0])
        
        let glucoseUnitsFlag: Bool = (flagByte & 0b100) == 1 ? true : false
        let glucoseUnits: String = (glucoseUnitsFlag == true) ? "molperL" : "KgperL"
        
        var sampleLocation: String
        switch (newMeasurement[14] >> 4) { //Sample Location
        case 15: sampleLocation = "Not available"
        default: sampleLocation = "Other"
        }
        
        // These are the standard blood sample encodings from Bluetooth Glucose Service GATT
        
        var sampleType: String
        switch ((newMeasurement[14] & 0b1111)) { //Sample Location
        case 1: sampleType = "Capillary Whole blood"
        case 10: sampleType = "Control Solution"
        default: sampleType = "Other"
        }
        
        var meal = String()
        
        // These are the standard meal encodings from Bluetooth Glucose Service GATT
        
        if (newRecord.1 != [] ) { // check for meal context present
            if (newRecord.1[0] == 2) {
                let carbID = newRecord.1[3]
                switch (carbID) {
                case 1: meal = "Preprandial"
                case 2: meal = "Postprandial"
                case 3: meal = "Fasting"
                case 4: meal = "Casual"
                case 5: meal = "Bedtime"
                default: meal = "Undefined"
                }
            }
        }
        

        
        
        //let sensorAnnunFlag: Bool = (flagByte & 0b1000) > 0 ? parseAnnuciationFlags() : false
        //let contextFlag: Bool = (flagByte & 0b10000) > 0 ? getMoreContext() : false
        
        let deviceID: String = newRecord.2
        
        // Write the record to the Model
        self.writeRecord(deviceID: deviceID,
                         sequenceNumber: (newMeasurement[2] << 8) | newMeasurement[1],
                         baseTime: UTCRecord ?? Date(),
                         timeOffsetSecs: timeOffsetSecs,
                         glucoseConcentration: glucose,
                         glucoseConcentrationUnits: glucoseUnits,
                         sampleType: sampleType,
                         sampleLocation: sampleLocation,
                         //sensorFlags: sensorFlags,
                         mealContext: meal)
    }
    
}
