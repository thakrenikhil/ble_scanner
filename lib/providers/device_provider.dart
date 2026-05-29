import 'dart:async';
import 'dart:convert';

import 'package:ble_vitals_scanner/constants/ble_constants.dart';
import 'package:ble_vitals_scanner/models/device_state.dart';
import 'package:ble_vitals_scanner/models/discovered_characteristic.dart';
import 'package:ble_vitals_scanner/providers/ble_provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceNotifier extends StateNotifier<DeviceState> {
  final FlutterReactiveBle _ble;
  final String _deviceId;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;

  DeviceNotifier(this._ble, this._deviceId) : super(DeviceState());

  //connect to the device
  void connect() {
    state = state.copyWith(connectionError: null);
    _connectionSub = _ble
        .connectToDevice(
          id: _deviceId,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          _onConnectionUpdate,
          onError: (error) {
            state = state.copyWith(
              connectionState: DeviceConnectionState.disconnected,
              connectionError: error.toString(),
            );
          },
        );
  }

  Future<void> _onConnectionUpdate(ConnectionStateUpdate update) async {
    state = state.copyWith(connectionState: update.connectionState);

    if (update.connectionState == DeviceConnectionState.connected) {
      await _discoverServices();
      await _readDeviceInfo();
      _subscribeToSensorData();
    }

    if (update.connectionState == DeviceConnectionState.disconnected) {
      _notifySub?.cancel();
      state = state.copyWith(
        isSubscribed: false,
        services: [],
        characteristics: [],
      );
    }
  }

  //discover services
  Future<void> _discoverServices() async {
    try {
      final services = await _ble.discoverServices(_deviceId);
      final characteristics = <DiscoveredCharacteristicItem>[];

      for (final service in services) {
        for (final char in service.characteristics) {
          characteristics.add(
            DiscoveredCharacteristicItem(
              characteristic: QualifiedCharacteristic(
                serviceId: service.serviceId,
                characteristicId: char.characteristicId,
                deviceId: _deviceId,
              ),
              isNotifiable: char.isNotifiable,
              isReadable: char.isReadable,
              isWritable:
                  char.isWritableWithResponse ||
                  char.isWritableWithoutResponse,
            ),
          );
        }
      }

      state = state.copyWith(
        services: services,
        characteristics: characteristics,
      );
    } catch (e) {
      state = state.copyWith(connectionError: 'Service discovery failed: $e');
    }
  }

  //read characteristic

  //read device info
  Future<void> _readDeviceInfo() async {
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(kServiceUuid),
        characteristicId: Uuid.parse(kDeviceInfoUuid),
        deviceId: _deviceId,
      );
      final bytes = await _ble.readCharacteristic(char);
      state = state.copyWith(deviceInfoValue: utf8.decode(bytes));
    } catch (_) {
      //  errors for device info
    }
  }

  //subscribe to sensor data
  void _subscribeToSensorData() {
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(kServiceUuid),
        characteristicId: Uuid.parse(kSensorDataUuid),
        deviceId: _deviceId,
      );

      _notifySub = _ble
          .subscribeToCharacteristic(char)
          .listen(
            (data) {
              final decoded = utf8.decode(data);
              state = state.copyWith(liveValue: decoded, isSubscribed: true);
            },
            onError: (error) {
              state = state.copyWith(
                liveValue: 'Error: $error',
                isSubscribed: false,
              );
            },
          );
    } catch (e) {
      state = state.copyWith(liveValue: 'Subscribe error: $e');
    }
  }

  //disconnect and dispose
  void disconnect() {
    _connectionSub?.cancel();
    _notifySub?.cancel();
    _ble.deinitialize();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

final deviceProvider =
    StateNotifierProvider.family<DeviceNotifier, DeviceState, String>((
      ref,
      deviceId,
    ) {
      final ble = ref.watch(bleProvider);
      final notifier = DeviceNotifier(ble, deviceId);
      ref.onDispose(notifier.dispose);
      return notifier;
    });
