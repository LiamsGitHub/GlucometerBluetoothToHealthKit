# GlucometerBluetoothToHealthKit
Glucometer readings downloaded to iPhone over Bluetooth and written to HealthKit

![alt text](https://i.postimg.cc/rmySQ4w2/logos.png)

While newer blood glucose monitors (BGM) have Bluetooth capability (BLE), they are often designed only to sync data to their own clouds. However many applications call for mixing glucose measurements with data like weight, activity, carb consumption from other apps to enable consumers themselves, coaching, or care teams to use the information directly.

This code pulls glucose measurements from BLE-enabled BGM and stores it both in:

* HealthKit. Many apps and EHRs have HealthKit integration and can use HK as a channel to import glucose data.
* Open format. Developer can integrate into other database systems.
	
The code was developed using a Contour Next One BGM since it was found in a study published by the Diabetes Technology Society to be the most accurate of the set of 18 BGMs tested and one of the few to meet the FDA accuracy standard for glucometers:
https://www.diabetestechnology.org/surveillance.shtml

The Bluetooth Forum developed a standard “GATT” profile for BGMs. Details can be found here:
https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.service.glucose.xml

At the top level, reads from the BGM via its “Record Access Control Point (RACP)” characteristic. The code writes to RACP requesting data from the glucose measurement and glucose measurement context characteristics. Given the asynchronous nature of the response from the BLE device, a notification system is used to let the app now when a response has been received. To subscribe to those notifications, the code needs to register for glucose measurement notifications with RACP.

Examples of RACP commands (which are sparsely undocumented in the spec and that I had to discover iteratively):

- 1,1			Read all records
- 4,1			Number of records
- 1,6			Read last record received
- 1,5			Read first record
- 1,3,1,45,0	    Read extract from record 45 onwards

These are all sent as UInt8 values.

# Code

Code is built using Model:View:Controller architecture so the classes are separable for use elsewhere. Given that the code is illustrative, it is bare bones and does not implement much error handling nor a nice UI.

The project has Swift 4 classes:
- BLE.swift manages the Bluetooth Peripheral
- GlucoseRecord.swift manages the data Model
- HealthKitManager.swift manages the HealthKit Interface
- ViewController
- AppDelegate

## AppDelegate
Instantiates the Glucose model and passes a handle on to ViewController

## BLE
Manages the process of turning on iPhone Bluetooth, scanning for the BGM, connecting to it, finding its glucose services and associated characteristics. The code should work with any BGM that implements the BLE GATT.

Code was developed as a foundational starting point demo, so scanning is tied to 1 glucometer (its UUID is embedded in the code), no UI is implemented in the ViewController, no timeout for not finding a device, minimal error handling etc.

Uses a Protocol “BLEProtocol” to enable the ViewController to receive notifications as asynchronous tasks such as data reads complete

Once connection to the BLE device is set, commands can be issued as an array of UInt8. Commands for glucometer measurement and context are sent to the RACP characteristic.

Measurement data back from the BGM is received in an array of 15 UInt8 bytes per the GATT standard and is set out like this:
https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.glucose_measurement.xml

There sometimes then follows a “context” message that supplies extra information such as device battery level of a further 4 UInt8. Example data looks like this:
```
Received update for characteristic 2A18 of value...
[19, 30, 0, 226, 7, 9, 20, 5, 27, 7, 92, 254, 111, 176, 241]
Received update for characteristic 2A34 of value...
[2, 30, 0, 2]

Received update for characteristic 2A52 of value...
[6, 0, 1, 1]
```
Where 0x2A18 is the glucose measurement characteristic, 0x2A34 glucose context and 0x2A52 is RACP

Responses generally consist of a series of measurement values each followed by it’s corresponding context and finally the RACP packet.

The output from the BLE class is a tuple of 2 arrays of UInt8 values; one for glucose measurement and the other for the measurement’s context. For example:

``` [19, 49, 0, 226, 7, 10, 6, 15, 47, 50, 92, 254, 126, 176, 241], [2, 49, 0, 1] ```

A developer test mode is provided in ViewController. Since the IOS simulator does not provide for Bluetooth, this mode is an “offline” way of testing the downstream app with example BGM data packets.

## Glucose Record
Takes raw packets from BLE and provides some basic enumerations to decode measurement states from the Context data. e.g. blood type, sample location, meal present, device status etc
Each record consists of:
- Sequence number Unique number per sample starting from zero.
- Base time This is set by default to UTC and is sent from BLE as a SInt16
- TimeOffsetMins Gives the offset in time between base time UTC and the “user facing” time. This is a way to figure out the user’s timezone.
- Glucose concentration and measurement units
- Blood type, sample location, meal context and device sensor flags
No processing of decoded flags has been implemented.
The output is written to HealthKit as a floating point mg/dL measurement along with time information.

## HealthKit Manager
To get this to work you MUST set up Privacy requests in your App’s info.plist as here.

First sets up requests to the user to allow the app to read and write glucose records to HealthKit Timezone information is sent through the meta data variables. Seems to decode correctly and allocate the correct timezone to each reading regardless of the iPhone’s location
