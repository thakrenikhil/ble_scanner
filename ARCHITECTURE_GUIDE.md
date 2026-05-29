# 📊 BLE App - Visual Architecture Guide

## App Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                                  │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                   UI Layer (Screens)                       │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │    │
│  │  │ ScanScreen   │  │DeviceScreen  │  │BleTestScreen│    │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │ (uses Consumer/ConsumerWidget)                 │
│                   ↓                                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │            Riverpod State Management                       │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │    │
│  │  │bleProvider   │  │scannerProvider  │deviceProvider│    │    │
│  │  │(BLE Instance)│  │(Scan Logic)  │  │(Device Logic)│    │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                 │
│                   ↓                                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │          Business Logic Layer                             │    │
│  │  ┌──────────────────────────────────────────────────────┐ │    │
│  │  │  • Connect/Disconnect                               │ │    │
│  │  │  • Send Commands (with/without response)            │ │    │
│  │  │  • Auto-subscribe to sensor data                    │ │    │
│  │  │  • Service discovery                                │ │    │
│  │  │  • Error handling                                   │ │    │
│  │  └──────────────────────────────────────────────────────┘ │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                 │
│                   ↓                                                 │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │        Data Models (Type-Safe)                            │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │    │
│  │  │BleDeviceItem │  │ DeviceState  │  │ScannerState  │    │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │    │
│  └────────────────┬───────────────────────────────────────────┘    │
│                   │                                                 │
│                   ↓                                                 │
└─────────────────────────────────────────────────────────────────────┘
                    │
                    ↓
    ┌───────────────────────────────────┐
    │    FlutterReactiveBle Library      │
    │  (Handles native BLE calls)        │
    └───────────────────────────────────┘
                    │
                    ↓
    ┌───────────────────────────────────┐
    │  Android/iOS BLE Stack             │
    │  (BluetoothAdapter/CoreBluetooth) │
    └───────────────────────────────────┘
                    │
                    ↓
    ╔═══════════════════════════════════╗
    ║   BLE DEVICE (Peripheral)          ║
    ║   (Arduino/nRF52/etc)              ║
    ╚═══════════════════════════════════╝
```

---

## Data Flow: Sending Command

```
                    ┌─────────────────────────────────┐
                    │  User Types "LED_ON" in UI      │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ User Clicks "Send" Button       │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ writeControl("LED_ON")          │
                    │ Called from ControlCard         │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ UTF8 Encode String to Bytes     │
                    │ "LED_ON" → [0x4C, 0x45, ...]   │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ Get Control Characteristic      │
                    │ UUID: kControlUuid              │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ writeCharacteristic() [No Wait] │
                    │ Send immediately                │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
         ╔═══════════════════════════════════════════╗
         ║  BLUETOOTH TRANSMISSION                   ║
         ║  Radio waves → Device                     ║
         ╚══════════════┬═══════════════════════════╝
                        │
                        ↓
         ╔═══════════════════════════════════════════╗
         ║  DEVICE RECEIVES                          ║
         ║  Interprets: "LED_ON"                     ║
         ║  Action: Turns on LED                     ║
         ╚═══════════════════════════════════════════╝
```

---

## Data Flow: Receiving Data

```
         ╔═══════════════════════════════════════════╗
         ║  DEVICE SENDS DATA                        ║
         ║  (Sensor reading, status, etc)            ║
         ║  Sends via Sensor UUID                    ║
         ╚══════════════┬═══════════════════════════╝
                        │
                        ↓
         ╔═══════════════════════════════════════════╗
         ║  BLUETOOTH TRANSMISSION                   ║
         ║  Radio waves → Phone/Computer             ║
         ╚══════════════┬═══════════════════════════╝
                        │
                        ↓
                    ┌─────────────────────────────────┐
                    │ subscribeToCharacteristic()     │
                    │ (Auto-called on connect)        │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ Receive Notification            │
                    │ Data as raw bytes               │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ UTF8 Decode Bytes to String     │
                    │ [0x54, 0x45, ...] → "TEMP:25"  │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ Update Riverpod State           │
                    │ liveValue = "TEMP:25"           │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ UI Rebuilds Automatically       │
                    │ (ConsumerWidget watches state)  │
                    └────────────┬────────────────────┘
                                 │
                                 ↓
                    ┌─────────────────────────────────┐
                    │ LiveStreamCard Shows New Data   │
                    │ "TEMP:25" appears in Live Data  │
                    └─────────────────────────────────┘
```

---

## State Management: Riverpod Providers

```
┌─────────────────────────────────────────────────────────────┐
│                  Riverpod Providers                          │
└─────────────────────────────────────────────────────────────┘

1. bleProvider (Singleton)
   ┌──────────────────────────────┐
   │ Returns: FlutterReactiveBle   │
   │ Scope: App-wide               │
   │ Instance: Single (shared)     │
   └──────────────────────────────┘
                 ↓
2. scannerProvider (StateNotifier)
   ┌──────────────────────────────┐
   │ State: ScannerState           │
   │ • devices: List<BleDeviceItem>│
   │ • isScanning: bool            │
   │ • errorMessage: String?       │
   │ Methods:                      │
   │ • startScan()                 │
   │ • stopScan()                  │
   └──────────────────────────────┘
                 ↓
3. deviceProvider (StateNotifier.family)
   ┌──────────────────────────────┐
   │ Param: deviceId (String)      │
   │ State: DeviceState            │
   │ • connectionState             │
   │ • services: List              │
   │ • characteristics: List       │
   │ • liveValue: String           │
   │ Methods:                      │
   │ • connect()                   │
   │ • disconnect()                │
   │ • writeControl()              │
   │ • writeControlWithResponse()  │
   │ • requestMtuSize()            │
   └──────────────────────────────┘
```

---

## UUID Configuration & Usage

```
┌────────────────────────────────────────────────────────────────┐
│           Constants File (ble_constants.dart)                  │
└────────────────────────────────────────────────────────────────┘

const String kServiceUuid = "12345678-..."
                ↓
        ┌──────────────────────────────────┐
        │    BLE Service (Container)       │
        │  Contains all characteristics    │
        └──────────────────────────────────┘

        Contains 4 Characteristics:

        1. kSensorDataUuid → Read/Notify
           ├─ Device sends sensor data
           ├─ App receives notifications
           └─ Auto-subscribed on connect

        2. kDeviceInfoUuid → Read
           ├─ Read device info
           ├─ Called once on connect
           └─ Shows in "Device Info" card

        3. kControlUuid → Write/Write-No-Response
           ├─ App sends commands
           ├─ Device processes commands
           └─ Respond via kSensorDataUuid

        4. (Optional) Other characteristics
           └─ Your custom data channels
```

---

## Connection State Machine

```
              ┌──────────────────┐
              │   DISCONNECTED   │
              │ (Initial State)  │
              └────────┬─────────┘
                       │
                       │ connect()
                       ↓
              ┌──────────────────┐
              │   CONNECTING     │
              │ (10s timeout)    │
              └────────┬─────────┘
                       │
              ┌────────┴────────┐
              │                 │
         (success)          (error/timeout)
              │                 │
              ↓                 ↓
    ┌──────────────────┐  ┌──────────────────┐
    │   CONNECTED      │  │   DISCONNECTED   │
    │ • Discover svcs  │  │ • Show error     │
    │ • Auto-subscribe │  │ • Close streams  │
    │ • Ready for I/O  │  │                  │
    └────────┬─────────┘  └──────────────────┘
             │                    ↑
             │                    │
             │ disconnect()       │
             │                    │
             ↓────────────────────┘
    ┌──────────────────┐
    │ DISCONNECTING    │
    └────────┬─────────┘
             │
             ↓
    ┌──────────────────┐
    │   DISCONNECTED   │
    │ • Cleanup subs   │
    │ • Ready to retry │
    └──────────────────┘
```

---

## File Organization & Dependencies

```
lib/
│
├── main.dart
│   └─ Entry point
│      └─ ProviderScope wrapper
│         └─ MaterialApp config
│
├── constants/
│   └─ ble_constants.dart (UPDATE THIS!)
│      └─ UUIDs for your device
│
├── models/
│   ├─ ble_device.dart
│   │  └─ BleDeviceItem (discovered device)
│   ├─ device_state.dart
│   │  └─ DeviceState (connection + data)
│   ├─ scanner_state.dart
│   │  └─ ScannerState (scan status)
│   └─ discovered_characteristic.dart
│      └─ DiscoveredCharacteristicItem
│
├── providers/ (CORE LOGIC)
│   ├─ ble_provider.dart
│   │  └─ bleProvider (singleton)
│   ├─ scanner_provider.dart
│   │  └─ scannerProvider (scan logic)
│   └─ device_provider.dart [FIXED ✓]
│      └─ deviceProvider (connect/send/receive)
│
├── screens/ (UI)
│   ├─ scan_screen.dart
│   │  └─ Device discovery screen
│   ├─ device_screen.dart
│   │  └─ Device detail screen
│   └─ ble_test_screen.dart [NEW]
│      └─ Testing console
│
├── widgets/ [IMPROVED]
│   └─ device_widgets.dart
│      └─ Reusable UI cards
│
└── utils/ [NEW]
    └─ ble_test_helper.dart
       └─ Testing utilities

External Dependencies:
  • flutter_reactive_ble ← BLE communication
  • flutter_riverpod ← State management
  • permission_handler ← Permissions
```

---

## Troubleshooting Diagram

```
┌─────────────────────────────────────┐
│  Can't Reconnect After Disconnect?  │
└────────────┬────────────────────────┘
             │
             └─ ✅ FIXED in device_provider.dart
                └─ Removed _ble.deinitialize()
                   └─ Now you can reconnect!

┌─────────────────────────────────────┐
│  Command Not Received by Device?    │
└────────────┬────────────────────────┘
             │
             ├─ Check kControlUuid matches device
             ├─ Verify characteristic is WRITABLE
             ├─ Ensure device is connected
             └─ Check command encoding (UTF-8)

┌─────────────────────────────────────┐
│  No Data in "Live Data" Section?    │
└────────────┬────────────────────────┘
             │
             ├─ Check kSensorDataUuid is correct
             ├─ Verify characteristic is NOTIFY
             ├─ Device must send notifications
             ├─ Check UTF-8 encoding
             └─ Green dot should show "Receiving..."

┌─────────────────────────────────────┐
│  Send Command Shows "Connecting..."? │
└────────────┬────────────────────────┘
             │
             └─ Connection still in progress
                └─ Wait for green "Connected" status
                   └─ Then send command
```

---

## Success Indicators ✅

When everything is working:

1. **Connection**
   - Green "Connected" badge
   - Can read device info
   - Green dot in Live Data

2. **Sending**
   - Command sends without error
   - Green success snackbar appears
   - Device processes command

3. **Receiving**
   - Live Data updates with device responses
   - Green indicator shows "Receiving"
   - Updates happen automatically

4. **Reconnection** [NOW WORKS]
   - Can disconnect
   - Can disconnect and reconnect
   - State clears properly
   - No "Connecting..." stuck state
