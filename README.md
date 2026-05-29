# BLE Scanner & Device Monitor

A Flutter mobile app that acts as a **BLE central (GATT client)**: scan for peripherals, connect, discover services, read device info, subscribe to live notifications, and send UTF-8 commands to a writable characteristic. State is managed with **Riverpod**; BLE I/O uses **flutter_reactive_ble**.

| | |
|---|---|
| **Package name** | `ble_app` |
| **Version** | `1.0.0+1` |
| **Role** | BLE central (client) only — does not advertise or act as a peripheral |
| **Platforms** | Android (primary), iOS (supported; see [iOS notes](#ios-notes)) |

---

## Table of contents

- [Features](#features)
- [Assumptions](#assumptions)
- [Requirements](#requirements)
- [Dependencies](#dependencies)
- [BLE GATT contract](#ble-gatt-contract)
- [Project structure](#project-structure)
- [Architecture](#architecture)
- [Getting started](#getting-started)
- [How to test](#how-to-test)
- [App screens & behavior](#app-screens--behavior)
- [Permissions](#permissions)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Additional documentation](#additional-documentation)

---

## Features

### Scanner (`ScanScreen`)

- Request Bluetooth and location permissions (Android)
- Start/stop BLE scan with live device list
- Show device name (or **Unknown Device** if the advertiser sends no name), RSSI, and ID
- Tap a device to open the connection screen

### Device session (`DeviceScreen`)

- Auto-connect once when the screen opens (no repeated connect on rebuild)
- Connection status indicator (connecting / connected / disconnected)
- **Live Data** — subscribes to the sensor/notify characteristic (`…def1`) and shows UTF-8 payloads in real time
- **Device Info** — one-shot read of the read-only info characteristic (`…def2`) when present
- **Send Command** — writes UTF-8 text to the control characteristic (`…def3`) using **write without response**
- **Services** — lists discovered GATT services and characteristics with property badges (R / W / N)
- **Disconnect** — cancels subscriptions without calling `deinitialize()` so reconnect works
- In-app error card for connection, discovery, and write failures

### Optional / code utilities

- `BleTestScreen` — test console (wire into navigation if needed; not on the default home route)
- `BleTestHelper` — programmatic send, rapid-send test, MTU request, status logging

### API on `DeviceNotifier` (`deviceProvider`)

| Method | Description |
|--------|-------------|
| `connect()` | Connect with 10s timeout; discover services; read info; subscribe to sensor |
| `disconnect()` | Cancel connection and notify subscriptions |
| `writeControl(String)` | Write UTF-8 to control char (**without response**) |
| `writeControlWithResponse(String)` | Write with GATT response (for debugging) |
| `requestMtuSize(int)` | Request larger ATT MTU |

---

## Assumptions

1. **Your app is always the central.** The peripheral is hardware, firmware, or a simulator (e.g. nRF Connect GATT server on another phone).
2. **GATT layout matches** `lib/constants/ble_constants.dart` (or you update those UUIDs to match your device).
3. **Control characteristic** (`…def3`) exposes **Write Without Response** (and optionally Write). The default UI uses `writeCharacteristicWithoutResponse`.
4. **Sensor characteristic** (`…def1`) exposes **Notify** (and optionally Read). The app subscribes after connect.
5. **Payloads are UTF-8 text** (e.g. `LED_ON`, `live news`). Binary protocols need encoding changes in `device_provider.dart`.
6. **Peripheral does not auto-reply to commands.** Live Data updates only when the peripheral sends a **notification** on `…def1`. A green “Sent” snackbar means the write call completed, not that the peripheral executed logic.
7. **Two devices for nRF Connect testing** — one phone runs nRF as **SERVER/advertiser**, the other runs this Flutter app. One phone cannot be both central and peripheral for this flow.
8. **Android 12+** uses `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`; older Android may still need location for scanning.
9. **Advertised name may be empty** — the app bar can show **Unknown Device** even when GATT Device Info read works.

---

## Requirements

| | Minimum / tested |
|---|------------------|
| **Dart SDK** | `>=3.0.0 <4.0.0` (`pubspec.yaml`) |
| **Flutter** | 3.0+ recommended; developed with **Flutter 3.45.x** / **Dart 3.12.x** |
| **Hardware** | Phone/tablet with **Bluetooth LE** |
| **OS** | Android 6+ (API 23+); iOS 12+ (with Bluetooth usage keys configured) |

Check your environment:

```bash
flutter --version
dart --version
```

---

## Dependencies

Declared in `pubspec.yaml` (resolved versions from `pubspec.lock` at time of documentation):

| Package | Constraint (`pubspec.yaml`) | Resolved (lock) | Purpose |
|---------|----------------------------|-----------------|---------|
| `flutter` | SDK | — | UI framework |
| `flutter_reactive_ble` | `^5.3.0` | **5.5.0** | Scan, connect, GATT read/write/notify |
| `flutter_riverpod` | `^2.4.0` | **2.6.1** | `ProviderScope`, widgets, notifiers |
| `riverpod` | `^2.4.0` | **2.6.1** | `StateNotifier`, providers |
| `permission_handler` | `^11.3.0` | **11.4.0** | Runtime Bluetooth/location permissions |
| `flutter_lints` | `^3.0.0` (dev) | **3.0.0** | Lint rules |

Install / refresh:

```bash
flutter pub get
```

---

## BLE GATT contract

Default UUIDs in `lib/constants/ble_constants.dart`:

| Constant | UUID | Peripheral properties | App usage |
|----------|------|----------------------|-----------|
| `kServiceUuid` | `12345678-1234-5678-1234-56789abcdef0` | Primary service | Service filter / discovery |
| `kSensorDataUuid` | `…def1` | **Notify**, Read (optional) | Live Data subscription |
| `kDeviceInfoUuid` | `…def2` | **Read** | Device Info card (one-shot read) |
| `kControlUuid` | `…def3` | **Write Without Response** (+ Write optional) | Send Command |

Example nRF Connect **SERVER** layout:

```
Service  12345678-1234-5678-1234-56789abcdef0
├── …def1  NOTIFY, READ     → "live news " (notify to app)
├── …def2  READ              → "Sim device v1.0 | SN:ABC123"
└── …def3  WRITE, WRITE NO RESPONSE  ← app writes commands here
```

---

## Project structure

```
lib/
├── main.dart                          # ProviderScope, MaterialApp → ScanScreen
├── constants/
│   └── ble_constants.dart             # Service & characteristic UUIDs
├── models/
│   ├── ble_device.dart                # Discovered device (scan result)
│   ├── device_state.dart              # Connection + GATT + live data state
│   ├── discovered_characteristic.dart
│   └── scanner_state.dart
├── providers/
│   ├── ble_provider.dart              # FlutterReactiveBle singleton
│   ├── scanner_provider.dart          # Scan / stop / device list
│   └── device_provider.dart           # Connect, discover, read, write, notify
├── screens/
│   ├── scan_screen.dart               # Home — permissions + scanner
│   ├── device_screen.dart             # Connect, live data, control, services
│   └── ble_test_screen.dart           # Optional test console
├── utils/
│   └── ble_test_helper.dart           # Programmatic test helpers
└── widgets/
    └── device_widgets.dart            # Connection, live data, control, services UI
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  ScanScreen          scannerProvider  →  FlutterReactiveBle │
│  DeviceScreen        deviceProvider   →  (per deviceId)     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Peripheral (nRF / firmware)                                │
│  …def3 ← write (commands)    …def1 → notify (sensor stream) │
│  …def2 → read (device info)                                 │
└─────────────────────────────────────────────────────────────┘
```

**Riverpod providers**

- `bleProvider` — shared `FlutterReactiveBle` instance (not deinitialized on disconnect).
- `scannerProvider` — `startScan()` / `stopScan()`, device list, errors.
- `deviceProvider(deviceId)` — family notifier: connect, discover, subscribe, read, write.

---

## Getting started

1. **Clone** the repo and open the project folder.

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Use a physical device** (BLE scanning is unreliable on emulators).

4. **Run:**

   ```bash
   flutter run
   ```

5. **Grant permissions** when prompted (Bluetooth scan/connect and location on Android).

6. **Update UUIDs** in `lib/constants/ble_constants.dart` if your peripheral uses different IDs.

---

## How to test

### A. Test with nRF Connect (two phones)

| Phone | Role |
|-------|------|
| **Phone A** | nRF Connect — **Configure GATT server** + **Advertiser** |
| **Phone B** | This Flutter app — scanner + central |

**On Phone A (nRF):**

1. Menu → **Configure GATT server**.
2. Add service `12345678-1234-5678-1234-56789abcdef0` and characteristics `…def1`, `…def2`, `…def3` as in [BLE GATT contract](#ble-gatt-contract).
3. Enable **Notify** on `…def1` (set CCCD / notifications enabled).
4. Enable **Read** on `…def2`; set an initial value (e.g. `Sim device v1.0 | SN:ABC123`).
5. Enable **Write** and **Write Without Response** on `…def3`.
6. Start **advertising**. Optional: set **device name** in advertiser (avoids **Unknown Device** in the app bar).

**On Phone B (Flutter):**

1. Open app → allow permissions → start scan.
2. Tap the nRF peripheral → wait for **Connected**.
3. **Live Data** — should show the current notify payload (e.g. `live news`).
4. **Services** — expand custom service; confirm `def1` has **N**, `def3` has **W**.
5. **Device Info** card (if read succeeds) — shows `…def2` text (not the same as the app bar title).
6. **Send Command** — type `LED_ON` → **Send**.

**Verify write on nRF (Phone A):**

- Open **SERVER** tab while connected to the Flutter phone.
- There is **no “send” button on `…def3`** — the central (Flutter app) writes **in**.
- After sending, check the **Value** on characteristic `…def3` (hex `4C-45-44-5F-4F-4E` = `LED_ON`).

**Simulate a device reply:**

- On nRF, use the **upload/notify** control on `…def1` and send e.g. `ACK:LED_ON`.
- **Live Data** on Flutter should update immediately.

### B. Test reconnection

1. Connect → **Disconnect** (app bar) → go back to scanner.
2. Scan again → connect to the same peripheral.
3. Connection and live data should work without restarting the app.

### C. Programmatic tests (`BleTestHelper`)

Import in a widget with `WidgetRef`:

```dart
await BleTestHelper.sendTestCommand(ref, deviceId, 'LED_ON');
BleTestHelper.printDeviceStatus(ref, deviceId);
await BleTestHelper.testRapidSend(ref, deviceId, count: 5);
```

To use `BleTestScreen`, push it from your navigation (e.g. from `ScanScreen` or `DeviceScreen`).

### D. Debug checklist

| Symptom | Check |
|---------|--------|
| No devices in scan | Bluetooth on; permissions granted; peripheral advertising |
| Connect hangs / fails | Range; peripheral not connected to another central |
| Live Data empty | `…def1` notify enabled on peripheral; green dot on Live Data card |
| Send seems ignored | nRF `…def3` **Value** after write; red **Error** card in app |
| Title “Unknown Device” | Normal if advertiser has no name; set name in nRF Advertiser |
| No Device Info card | Read of `…def2` failed or empty; confirm READ property and value on nRF |

---

## App screens & behavior

### Scan screen

- Requests `bluetoothScan`, `bluetoothConnect`, `locationWhenInUse`.
- FAB / app bar control to start and stop scanning.

### Device screen

- Connects once in `initState` (not on every rebuild).
- On **connected**: discover services → read `…def2` → subscribe to `…def1`.
- **Send Command**: UTF-8 write without response; success snackbar does not guarantee peripheral-side handling (errors may appear in the **Error** card).
- **Disconnect**: cancels streams; does not call `FlutterReactiveBle.deinitialize()`.

---

## Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

- `BLUETOOTH_SCAN` (with `neverForLocation` where applicable)
- `BLUETOOTH_CONNECT`
- `BLUETOOTH` / `BLUETOOTH_ADMIN` (max SDK 30)
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` (scanning on older APIs)
- `uses-feature` `android.hardware.bluetooth_le` required

Runtime requests are made in `scan_screen.dart` via `permission_handler`.

### iOS notes

`Info.plist` must include Bluetooth usage descriptions for App Store and permission dialogs, for example:

- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription` (older templates)

Add these before shipping to iOS. Scanning may also require location usage keys depending on iOS version and plugin behavior.

---

## Configuration

**UUIDs** — `lib/constants/ble_constants.dart`:

```dart
const String kServiceUuid    = '12345678-1234-5678-1234-56789abcdef0';
const String kSensorDataUuid = '12345678-1234-5678-1234-56789abcdef1';
const String kDeviceInfoUuid = '12345678-1234-5678-1234-56789abcdef2';
const String kControlUuid    = '12345678-1234-5678-1234-56789abcdef3';
```

**Theme** (dark UI):

| Token | Color |
|-------|--------|
| Primary | `#00D4FF` |
| Scaffold | `#0F1117` |
| Cards | `#1A1D27` |
| Success / Error / Warning | Green / Red / Orange accents |

---

## Troubleshooting

| Issue | Suggestions |
|-------|-------------|
| App crashes on startup | Run `flutter pub get`; ensure `ProviderScope` wraps `MaterialApp` in `main.dart` |
| No devices found | Physical device; Bluetooth on; permissions; peripheral advertising |
| `service_discovery_failure` / disconnect on subscribe | Stay in range; avoid multiple `connect()` calls; wait until **Connected** before interacting |
| Write “succeeds” but nothing on nRF | Confirm write on SERVER `…def3` **Value**; try `writeControlWithResponse` if only **Write** is supported |
| Live Data never updates | Enable notifications on `…def1`; peripheral must **notify**, not only update local server value |
| Cannot reconnect | Ensure you are not calling `deinitialize()` on disconnect (current code avoids this) |
| Analyzer deprecation warning | `discoverServices` is deprecated in `flutter_reactive_ble` 5.x; migrate to `discoverAllServices` + `getDiscoveredServices` when convenient |

---

## Additional documentation

| File | Contents |
|------|----------|
| [START_HERE.md](START_HERE.md) | Onboarding index |
| [BLE_COMMUNICATION_GUIDE.md](BLE_COMMUNICATION_GUIDE.md) | Send/receive patterns, data flow |
| [COMPLETE_SOLUTION_GUIDE.md](COMPLETE_SOLUTION_GUIDE.md) | Fixes, quick start, test screen |
| [ARCHITECTURE_VISUAL_GUIDE.md](ARCHITECTURE_VISUAL_GUIDE.md) | Diagrams |
| [FIXES_AND_DATA_FLOW.md](FIXES_AND_DATA_FLOW.md) | Connection fixes and flows |
| [INDEX.md](INDEX.md) | Doc map |

---

## License

This project is for development and learning. Add a license file if you distribute it publicly.
