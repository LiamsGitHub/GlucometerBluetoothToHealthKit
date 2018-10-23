//
//  GlucoseRecord.swift
//  Glucometer
//  This class is the Model for glucose data. It parses the raw data from the BLE glucometer to derive measurement object parameters
//
//  Created by Liam Goudge on 10/15/18.
//  tag for Git1

import Foundation
import HealthKit

class GlucoseData {
    
    var records = [Record]()
    var sensorFlags = Flags()
    
    let hk = HealthKitManager()
    
    enum GlucoseConcentrationUnits {
        case KgperL, molperL
    }
    
    enum BloodType {
        case Reserved
        case CapillaryWholeBlood
        case CapillaryPlasma
        case VenousWholeBlood
        case VenousPlasma
        case ArterialWholeBlood
        case ArterialPlasma
        case UndeterminedWholeBlood
        case UndeterminedPlasma
        case InterstitialFluid
        case ControlSolution
    }
    
    enum Location {
        case Reserved
        case Finger
        case AlternateSiteTest
        case Earlobe
        case ControlSolution
        case SampleLocationValueNotAvailable
    }
    
    enum MealPresent: Int {
        case Preprandial = 1
        case Postprandial = 2
        case Fasting = 3
        case Casual = 4
        case Bedtime = 5
        case NoMealDefined = 6
    }
    
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
        var sequenceNumber:Int
        var baseTime:Date
        var timeOffsetSecs:Int
        var glucoseConcentration:Float
        var glucoseConcentrationUnits: GlucoseConcentrationUnits
        var bloodType:BloodType
        var sampleLocation:Location
        var sensorFlags: Flags
        var mealContext: MealPresent
    }
    
    
    func writeRecord(sequenceNumber: Int, baseTime: Date, timeOffsetSecs: Int, glucoseConcentration: Float, glucoseConcentrationUnits: GlucoseConcentrationUnits, bloodType: BloodType, sampleLocation: Location, sensorFlags: Flags, mealContext: MealPresent) {
        
        let glucoseValue = glucoseConcentration * 100000 // convert to mg/dL. Should ensure not mols
        
        let theRecord = Record(sequenceNumber: sequenceNumber,
                               baseTime: baseTime,
                               timeOffsetSecs: timeOffsetSecs,
                               glucoseConcentration: glucoseConcentration,
                               glucoseConcentrationUnits: glucoseConcentrationUnits,
                               bloodType: bloodType,
                               sampleLocation: sampleLocation,
                               sensorFlags: sensorFlags,
                               mealContext: mealContext)
        
        records.append(theRecord)
        print ("Record added:")
        print (theRecord)
        
        hk.writeBloodGlucoseToHealthKit(glucoseValue: Double(glucoseValue), timestamp: baseTime, offsetSecs: timeOffsetSecs)
    }
    
    func addNewRecord(newRecord: ([Int],[Int]) ) {
        
        var newMeasurement: [Int] = newRecord.0
        
        let mealContext: MealPresent = (newRecord.1 == []) ? .NoMealDefined : MealPresent(rawValue: newRecord.1[3])! // Unwrap. Would be nice to remove later
        
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
        let glucoseUnits: GlucoseConcentrationUnits = (glucoseUnitsFlag == true) ? .molperL : .KgperL
        
        //let sensorAnnunFlag: Bool = (flagByte & 0b1000) > 0 ? parseAnnuciationFlags() : false
        //let contextFlag: Bool = (flagByte & 0b10000) > 0 ? getMoreContext() : false
        
        
        // Write the record to the Model
        self.writeRecord(sequenceNumber: (newMeasurement[2] << 8) | newMeasurement[1],
                         baseTime: UTCRecord ?? Date(),
                         timeOffsetSecs: timeOffsetSecs,
                         glucoseConcentration: glucose,
                         glucoseConcentrationUnits: glucoseUnits,
                         bloodType: BloodType.CapillaryWholeBlood,
                         sampleLocation: Location.Finger,
                         sensorFlags: sensorFlags,
                         mealContext: mealContext)
    }
    
    func parseAnnuciationFlags() -> Bool {
        
        print ("Annunciation flags")
        return true
    }
    
    func getMoreContext() -> Bool {
        
        print ("Get more context")
        return true
    }
    
}
