//
//  ViewController.swift
//  Glucometer
//
//  Created by Liam Goudge on 10/15/18.
//  This code is provided for the purpose of demonstration. Use is entirely at your own risk. No warranty is provided. No license for use in a commercial product.

import UIKit
import CoreBluetooth
import HealthKit

class ViewController: UIViewController, BLEProtocol {
    
    let TEST_MODE = false

    
    @IBAction func syncReadings () {
        print ("Sync beyond the last record in Healthkit")
    }
    
    var glucoseDataset: GlucoseData!
    
    var bluetoothHandle = BLE()
    var peripherals: [CBPeripheral] = []
    var glucometer: CBPeripheral!
    
    let glucometerDeviceID:String = "A2C0B9C9-5A19-7EB1-2803-13765719E15E" // Locked to one BGM. Real app would do a TableView to select device.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Find last record loaded into HealthKit
        glucoseDataset.readHK()
        

        if TEST_MODE {
            print ("Test mode")
            startTest() // use this to load dummy data without using BLE so can use the iPhone simulator
        }
        
        else {
            print ("Live mode")
            bluetoothHandle.delegate = self
            bluetoothHandle.startBLE()
        }


    }
    

    

    func BLEactivated(state: Bool) {
        if (state) {
            print ("Bluetooth activated")
            bluetoothHandle.scan() // now trigger a scan for peripherals
        }
        else {
            print ("Bluetooth error")
        }
    }
    
    func BLEfoundPeripheral(device: CBPeripheral, rssi: Int) {

        for foundDevices in peripherals {
            if (foundDevices.identifier == device.identifier) { return }
        }
        
        print ("Found new device: \(device.name ?? "Unknown")     \(device.identifier)     \(rssi)")
        peripherals.append(device)
        
        if (device.identifier != UUID(uuidString: glucometerDeviceID)) {return} // Only default device for now. Later add a table view and picker so the user can select any device
     
        else {
            glucometer = device
            print ("Connecting to device")
            bluetoothHandle.connect(peripheral: glucometer)}

    }

    func BLEready(characteristic: CBCharacteristic) {
        print ("BLE device ready for commands")
        
        // These are example commands that can be sent to the glucometer
        // 1,1 is all records
        // 4,1 is number of records
        // 1,6 last record received
        // 1,5 first record
        // 1,3,1,45,0 extract from record 45 onwards
        
        let seq:Int = glucoseDataset.sequenceNumber + 1
        
        let seqLowByte: UInt8 = UInt8(0xff & (seq))
        let seqHighByte: UInt8 = UInt8(seq >> 8)
        
        print ("HK Seq: \(seq) LB: \(seqLowByte) HB: \(seqHighByte)")

        print ("Fetch sequence number: \(glucoseDataset.sequenceNumber)")
        bluetoothHandle.doWrite(peripheral: glucometer, characteristic: characteristic, message: [1,3,1,seqLowByte,seqHighByte])

    }
    
    func BLEdataRx(data dataset: [([Int], [Int], String)] ) {
        print ("Received Bluetooth data")
        print (dataset)
        
        for record in dataset {
            print (record)
            glucoseDataset.addNewRecord(newRecord: record )
        }
    }
    
    
    // Test function to allow development on downstream data handling without firing up BLE device
    func startTest() {
        
        var receivedDataSet: [ ([Int], [Int], String) ] = [] // Array of tuples with (measurement, context) as the payload
        
        // 4 records of raw data format that would come from glucometer
        receivedDataSet.append( ([19, 49, 0, 226, 7, 10, 6, 15, 47, 50, 92, 254, 126, 176, 241], [2, 49, 0, 1], glucometerDeviceID) ) // Pacific time
        receivedDataSet.append( ([19, 50, 0, 226, 7, 10, 7, 17, 11, 11, 92, 254, 118, 176, 241], [2, 50, 0, 2], glucometerDeviceID) )
        receivedDataSet.append( ([19, 51, 0, 226, 7, 10, 8, 15, 51, 56, 92, 254, 123, 176, 241], [2, 51, 0, 3], glucometerDeviceID) )
        receivedDataSet.append( ([19, 52, 0, 226, 7, 10, 9, 15, 30, 4, 92, 254, 125, 176, 241], [2, 52, 0, 4], glucometerDeviceID) )
        receivedDataSet.append( ([19, 53, 0, 226, 7, 10, 10, 17, 0, 0, 0,  0,   124, 176, 241], [2, 52, 0, 4], glucometerDeviceID)) // zero offset GMT
        receivedDataSet.append( ([19, 54, 0, 226, 7, 10, 25, 17, 0, 0, 0,  0,   150, 176, 241], [2, 52, 0, 4], glucometerDeviceID)) // newest date
        receivedDataSet.append( ([19, 55, 0, 226, 7, 10, 20, 17, 0, 0, 0,  0,   140, 176, 241], [2, 52, 0, 4], glucometerDeviceID))
        
        print ("In startTest")
        

        for (meas,context,id) in receivedDataSet {
            print ("Measure: \(meas) Context: \(context) Device: \(id)")
            glucoseDataset.addNewRecord(newRecord: (meas,context,id) )
        }
        
        
    }

}

