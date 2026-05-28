import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod/riverpod.dart';
import '../models/ble_device.dart';
import '../models/scanner_state.dart';
import 'ble_provider.dart';

class ScannerNotifier extends StateNotifier<ScannerState> {
  final FlutterReactiveBle _ble;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  final Map<String, BleDeviceItem> _devices = {};

  ScannerNotifier(this._ble) : super( ScannerState());

  void startScan() {
    _devices.clear();
    state = state.copyWith(
      devices: [],
      isScanning: true,
      errorMessage: null,
    );

    _scanSubscription = _ble.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        _devices[device.id] = BleDeviceItem.fromScanResult(device);
        final sorted = _devices.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        state = state.copyWith(devices: sorted);
      },
      onError: (error) {
        state = state.copyWith(
          errorMessage: error.toString(),
          isScanning: false,
        );
      },
    );
  }

  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}

/// Provides the scanner state and control methods
final scannerProvider =
    StateNotifierProvider<ScannerNotifier, ScannerState>((ref) {
  final ble = ref.watch(bleProvider);
  final notifier = ScannerNotifier(ble);
  ref.onDispose(notifier.dispose);
  return notifier;
});
