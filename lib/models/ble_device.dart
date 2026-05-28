import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleDeviceItem {
  final String id;
  final String name;
  final int rssi;
  final List<Uuid> serviceUuids;

  BleDeviceItem({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
  });

  String get displayName => name.isNotEmpty ? name : 'Unknown Device';

  factory BleDeviceItem.fromScanResult(DiscoveredDevice device) {
    return BleDeviceItem(
      id: device.id,
      name: device.name,
      rssi: device.rssi,
      serviceUuids: device.serviceUuids,
    );
  }
}
