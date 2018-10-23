//
//  ViewController.swift
//  Glucometer
//
//  Created by Liam Goudge on 10/15/18.
//  tag for Git1

import UIKit
import CoreBluetooth
import HealthKit

class ViewController: UIViewController, BLEProtocol {
    
    var glucoseDataset: GlucoseData!
    
    var bluetoothHandle = BLE()
    var peripherals: [CBPeripheral] = []
    var glucometer: CBPeripheral!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bluetoothHandle.delegate = self

        // startTest() // Use this to load dummy data without using BLE so can use the iPhone simulator.

        print ("Start BLE")
        bluetoothHandle.startBLE()

    }
    

    

    func BLEactivated(state: Bool) {
        if (state) {
            print ("Bluetooth activated")
            bluetoothHandle.scan()
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
        
        if (device.identifier != UUID(uuidString: "A2C0B9C9-5A19-7EB1-2803-13765719E15E")) {return} // Default device for now. Later add a table view and picker so the user can select any device
     
        else {
            glucometer = device
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
        
        bluetoothHandle.doWrite(peripheral: glucometer, characteristic: characteristic, message: [1,3,1,60,0])
        

    }
    
    func BLEdataRx(data dataset: [([Int], [Int])] ) {
        print ("Received Bluetooth data")
        print (dataset)
        
        for record in dataset {
            print (record)
            glucoseDataset.addNewRecord(newRecord: record )
        }
    }
    
    
    // Test function to allow development on downstream data handling without firing up BLE device
    func startTest() {
        
        var receivedDataSet: [ ([Int], [Int]) ] = [] // Array of tuples with (measurement, context) as the payload
        
        // 4 records of raw data format that would come from glucometer
        receivedDataSet.append( ([19, 49, 0, 226, 7, 10, 6, 15, 47, 50, 92, 254, 126, 176, 241], [2, 49, 0, 1]) ) // Pacific time
        receivedDataSet.append( ([19, 50, 0, 226, 7, 10, 7, 17, 11, 11, 92, 254, 118, 176, 241], [2, 50, 0, 2]) )
        receivedDataSet.append( ([19, 51, 0, 226, 7, 10, 8, 15, 51, 56, 92, 254, 123, 176, 241], [2, 51, 0, 3]) )
        receivedDataSet.append( ([19, 52, 0, 226, 7, 10, 9, 15, 30, 4, 92, 254, 125, 176, 241], [2, 52, 0, 4]) )
        receivedDataSet.append( ([19, 53, 0, 226, 7, 10, 10, 17, 0, 0, 0,  0,   124, 176, 241], [2, 52, 0, 4])) // zero offset GMT
        
        print ("In startTest")

        for (meas,context) in receivedDataSet {
            print ("Measure: \(meas) Context: \(context)")
            glucoseDataset.addNewRecord(newRecord: (meas,context) )
        }
        
        
    }

}

