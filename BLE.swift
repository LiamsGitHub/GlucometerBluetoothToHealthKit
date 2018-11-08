//
//  BLE.swift
//  Glucometer
//  This class is the driver for the Bluetooth Low Energy BLE interface to a glucometer
//
//  Created by Liam Goudge on 10/15/18.
//  This code is provided for the purpose of demonstration. Use is entirely at your own risk. No warranty is provided. No license for use in a commercial product.
//

import Foundation
import CoreBluetooth

// Protocol to allow BLE event notification in ViewController
protocol BLEProtocol {
    func BLEactivated(state: Bool)
    func BLEfoundPeripheral(device: CBPeripheral, rssi: Int)
    func BLEready(RACPcharacteristic: CBCharacteristic )
    func BLEdataRx(data:[ ([Int], [Int], String) ])
}

class BLE: NSObject {
    
    let tempDeviceID: String = "tempDeviceIDValue"
    
    var delegate: BLEProtocol?
    
    // Members to interact with the Model
    var dataReceived: ([Int], [Int], String) = ([], [],"") // tuple for a single glucose reading
    var receivedDataSet: [ ([Int], [Int], String) ] = [] // Array of tuples with (measurement, context, device ID) as the payload
 
    // Members related to BLE
    let glucoseServiceCBUUID = CBUUID(string: "0x1808")
    
    let glucoseMeasurementCharacteristicCBUUID = CBUUID(string: "0x2A18")
    let glucoseMeasurementContextCharacteristicCBUUID = CBUUID(string: "0x2A34")
    let glucoseFeatureCharacteristicCBUUID = CBUUID(string: "0x2A51")
    let recordAccessControlPointCharacteristicCBUUID = CBUUID(string: "0x2A52")

    // Members
    var centralManager: CBCentralManager!
    var glucosePeripheral: CBPeripheral?
    
    override init() {
        super.init()
    }
    
    
    func startBLE() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scan() {
        centralManager.scanForPeripherals(withServices: [glucoseServiceCBUUID]) // if BLE is powered, kick off scan for BGMs
    }
    
    func connect(peripheral: CBPeripheral) {
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }
    
    
    // Write 1 byte message to the BLE peripheral
    func doWrite(peripheral: CBPeripheral, characteristic: CBCharacteristic, message: [UInt8]) {
        
        let data = NSData(bytes: message, length: message.count)
        peripheral.writeValue(data as Data, for: characteristic, type: .withResponse)
    }
    
}

// Delegate functions to manage Central
extension BLE: CBCentralManagerDelegate {
    
    // This is the delegate when starting centralManager
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let state: Bool = central.state == .poweredOn ? true : false
        delegate?.BLEactivated(state: state)
    }
    
    // Scan found a peripheral delegate
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {

        glucosePeripheral = peripheral
        glucosePeripheral?.delegate = self
        delegate?.BLEfoundPeripheral(device: peripheral, rssi: RSSI.intValue)
    }
    
    
    // Triggered when Connection happens to peripheral delegate function
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        glucosePeripheral?.discoverServices([glucoseServiceCBUUID]) // Now look for glucose services offered by the glucometer
    }
    
}


// Delegate functions to manage Peripheral
extension BLE: CBPeripheralDelegate {
    
    // Discovered services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service) // Now find the Characteristics of these Services
            
        }
    }
    
    // Discovered characteristics for a service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        
        // Set notifications for glucose measurement and context
        // 0x2a18 is glucose measurement, 0x2a34 is context, 0x2a52 is RACP
        for characteristic in characteristics {
            
            if (characteristic.uuid == glucoseMeasurementCharacteristicCBUUID ||
                characteristic.uuid == glucoseMeasurementContextCharacteristicCBUUID ||
                characteristic.uuid == recordAccessControlPointCharacteristicCBUUID) {
                
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            if (characteristic.uuid == recordAccessControlPointCharacteristicCBUUID) {
                delegate?.BLEready(RACPcharacteristic: characteristic)
            }
        }
        
    }
    
    
    // For notified characteristics, here's the triggered method when a value comes in from the Peripheral
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if let dataBuffer: Data = characteristic.value {
            let buffLen: Int = dataBuffer.count
            
            var dataInArray = [UInt8](repeating:0, count:buffLen)
            dataBuffer.copyBytes(to: &dataInArray, count: buffLen)
            
            // Turn input stream of UInt8 to an array of Ints so that can use standard methods in Model
            var outputDataArray:[Int] = []
            
            for byte in dataInArray {
                outputDataArray.append(Int(byte))
            }
            
            
            switch characteristic.uuid {
                
            case glucoseMeasurementCharacteristicCBUUID:
                // Glucose measurement value
                dataReceived.0 = outputDataArray
                dataReceived.2 = tempDeviceID
                
                if (outputDataArray[0] & 0b10000) == 0 {
                    // No context attached, just do the write
                    receivedDataSet.append(dataReceived)
                    dataReceived = ([],[], "") // reset the received tuple
                }
                
            case glucoseMeasurementContextCharacteristicCBUUID:
                // Glucose context value
                dataReceived.1 = outputDataArray
                receivedDataSet.append(dataReceived)
                dataReceived = ([],[], "") // reset the received tuple
                
            case recordAccessControlPointCharacteristicCBUUID:
                // RACP. Transfer complete. Write to Model.
                
                delegate?.BLEdataRx(data: receivedDataSet)
                
            default:
                print ("Default")
            }
            
        }
        
    }
    
}
