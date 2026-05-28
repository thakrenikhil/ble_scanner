import 'package:ble_vitals_scanner/models/ble_device.dart';


class ScannerState {
  final List<BleDeviceItem> devices;
  final bool isScanning;
  final String? errorMessage;

  ScannerState({
    this.devices = const [],
    this.isScanning = false,
    this.errorMessage,
  });

  ScannerState copyWith({
    List<BleDeviceItem>? devices,
    bool? isScanning,
    String? errorMessage,
  }) {
    return ScannerState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
