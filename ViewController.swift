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
    
    // Globals
    
    let TEST_MODE = false

    var glucoseDataset: GlucoseData! // Handle to the Model
    
    var bluetoothHandle = BLE()
    var peripherals: [CBPeripheral] = []
    var glucometer: CBPeripheral!
    var RACP: CBCharacteristic! // BGM Record Access Control Point
    
    let glucometerDeviceID:String = "A2C0B9C9-5A19-7EB1-2803-13765719E15E" // Locked to one BGM. Real app would do a TableView to select device.
    
    // User Interface
    
    @IBOutlet weak var syncButton: UIButton!
    
    @IBAction func sync(_ sender: Any) {

        // These are example commands that can be sent to the glucometer
        // 1,1 get all records
        // 4,1 get number of records
        // 1,6 get last record received
        // 1,5 get first record
        // 1,3,1,45,0 extract from record 45 onwards
        
        let seq:Int = glucoseDataset.sequenceNumber + 1 // sequenceNumber is the last glucose record that was written to HK
        
        let seqLowByte: UInt8 = UInt8(0xff & (seq))
        let seqHighByte: UInt8 = UInt8(seq >> 8)
        
        textDisplay.text.append("Fetch data starting sequence #: \(glucoseDataset.sequenceNumber) \n")
        bluetoothHandle.doWrite(peripheral: glucometer, characteristic: RACP, message: [1,3,1,seqLowByte,seqHighByte]) // Ask BGM for all records since last one written to HK
        syncButton.isEnabled = false
    }
    
    
    @IBOutlet weak var textDisplay: UITextView! // console
    @IBOutlet weak var textStatus: UITextField! // one line text display for status
    
    
    // Class Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textDisplay.text = "Starting\n"
        
        glucoseDataset.viewControllerHandle = self
        
        // Find last record loaded into HealthKit
        glucoseDataset.readHK()
        textStatus.text = "Reading HealthKit"
        

        if TEST_MODE {
            textDisplay.text.append("Test mode\n")
            startTest() // use this to load dummy data without using BLE so can use the iPhone simulator
        }
        
        else {
            print ("Live mode")
            textDisplay.text.append("Live mode\n")
            textStatus.text = "Starting BlueTooth"
            bluetoothHandle.delegate = self
            bluetoothHandle.startBLE()
        }
    }
    

    func BLEactivated(state: Bool) {
        if (state) {
            textDisplay.text.append("Bluetooth activated\n")
            textStatus.text = "BlueTooth active"
            bluetoothHandle.scan() // now trigger a scan for peripherals
            textDisplay.text.append("Starting BLE scan\n")
        }
        else {
            textDisplay.text.append("Bluetooth error\n")
        }
    }
    
    func BLEfoundPeripheral(device: CBPeripheral, rssi: Int) {

        for foundDevices in peripherals {
            if (foundDevices.identifier == device.identifier) { return }
        }
        
        textDisplay.text.append("Found new device: \(device.name ?? "Unknown")     \(device.identifier)     \(rssi) \n")
        textStatus.text = "Found glucometer"
        peripherals.append(device)
        
        if (device.identifier != UUID(uuidString: glucometerDeviceID)) {return} // Only default device for now. Later add a table view and picker so the user can select any device
     
        else {
            glucometer = device
            textDisplay.text.append("Connecting to device\n")
            textStatus.text = "Connecting to glucometer"
            bluetoothHandle.connect(peripheral: glucometer)}

    }

    func BLEready(RACPcharacteristic: CBCharacteristic) {
        textDisplay.text.append("BLE device ready for commands\n")
        textStatus.text = "Glucometer ready"
        
        RACP = RACPcharacteristic
        syncButton.isEnabled = true
    }
    
    func BLEdataRx(data dataset: [([Int], [Int], String)] ) {

        textDisplay.text.append("Received Bluetooth data\n")
        textStatus.text = "Receiving glucometer data"
        
        for record in dataset {
            textDisplay.text.append("\(record.0) \(record.1) \n")
            glucoseDataset.addNewRecord(newRecord: record )
        }
        textStatus.text = "Data copied to Healthkit"
        textDisplay.text.append("BGM sync complete \n")
    }
    
    
    // Test function to allow development on downstream data handling without firing up BLE device ... so can use iPhone simulator
    func startTest() {
        
        var receivedDataSet: [ ([Int], [Int], String) ] = [] // Array of tuples with (measurement, context) as the payload
        
        // 4 records of raw data format that would come from glucometer
        receivedDataSet.append( ([19, 49, 0, 226, 7, 10, 6, 15, 47, 50, 92, 254, 126, 176, 250], [2, 49, 0, 1], glucometerDeviceID) ) // Pacific time
        receivedDataSet.append( ([19, 50, 0, 226, 7, 10, 7, 17, 11, 11, 92, 254, 118, 176, 241], [2, 50, 0, 2], glucometerDeviceID) )
        receivedDataSet.append( ([19, 51, 0, 226, 7, 10, 8, 15, 51, 56, 92, 254, 123, 176, 241], [2, 51, 0, 3], glucometerDeviceID) )
        receivedDataSet.append( ([19, 52, 0, 226, 7, 10, 9, 15, 30, 4, 92, 254, 125, 176, 241], [2, 52, 0, 4], glucometerDeviceID) )
        receivedDataSet.append( ([19, 53, 0, 226, 7, 10, 10, 17, 0, 0, 0,  0,   124, 176, 241], [2, 52, 0, 4], glucometerDeviceID)) // zero offset GMT
        receivedDataSet.append( ([19, 54, 0, 226, 7, 10, 25, 17, 0, 0, 0,  0,   150, 176, 241], [2, 52, 0, 4], glucometerDeviceID)) // newest date
        receivedDataSet.append( ([19, 55, 0, 226, 7, 10, 20, 17, 0, 0, 0,  0,   140, 176, 241], [2, 52, 0, 4], glucometerDeviceID))
        
        for (meas,context,id) in receivedDataSet {
            print ("Measure: \(meas) Context: \(context) Device: \(id)")
            glucoseDataset.addNewRecord(newRecord: (meas,context,id) )
        }
        
        
    }

}

