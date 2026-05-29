import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod/riverpod.dart';
import '../constants/ble_constants.dart';
import '../models/device_state.dart';
import '../models/discovered_characteristic.dart';
import 'ble_provider.dart';

class DeviceNotifier extends StateNotifier<DeviceState> {
  final FlutterReactiveBle _ble;
  final String _deviceId;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;
  bool _connectInProgress = false;

  DeviceNotifier(this._ble, this._deviceId) : super(DeviceState());

  void connect() {
    if (_connectionSub != null || _connectInProgress) return;
    _connectInProgress = true;
    state = state.copyWith(connectionError: null);
    _connectionSub = _ble
        .connectToDevice(
      id: _deviceId,
      connectionTimeout: const Duration(seconds: 10),
    )
        .listen(
      (update) {
        _onConnectionUpdate(update).catchError((Object error) {
          state = state.copyWith(
            connectionState: DeviceConnectionState.disconnected,
            connectionError: error.toString(),
          );
        });
      },
      onError: (error) {
        _connectInProgress = false;
        state = state.copyWith(
          connectionState: DeviceConnectionState.disconnected,
          connectionError: error.toString(),
        );
      },
      onDone: () {
        _connectInProgress = false;
        _connectionSub = null;
      },
    );
  }

  Future<void> _onConnectionUpdate(ConnectionStateUpdate update) async {
    state = state.copyWith(connectionState: update.connectionState);

    if (update.connectionState == DeviceConnectionState.connected) {
      _connectInProgress = false;
      await _discoverServices();
      if (state.connectionState != DeviceConnectionState.connected) return;
      await _readDeviceInfo();
      if (state.connectionState != DeviceConnectionState.connected) return;
      await _subscribeToSensorData();
      return;
    }

    if (update.connectionState == DeviceConnectionState.disconnected) {
      _connectInProgress = false;
      await _notifySub?.cancel();
      _notifySub = null;
      state = state.copyWith(
        isSubscribed: false,
        services: [],
        characteristics: [],
      );
    }
  }

  Future<void> _discoverServices() async {
    try {
      final services = await _ble.discoverServices(_deviceId);//Depricating need to fix
      final characteristics = <DiscoveredCharacteristicItem>[];

      for (final service in services) {
        for (final char in service.characteristics) {
          characteristics.add(DiscoveredCharacteristicItem(
            characteristic: QualifiedCharacteristic(
              serviceId: service.serviceId,
              characteristicId: char.characteristicId,
              deviceId: _deviceId,
            ),
            isNotifiable: char.isNotifiable,
            isReadable: char.isReadable,
            isWritable: char.isWritableWithResponse || char.isWritableWithoutResponse,
          ));
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
      // not fatal — simulator may not have this char
    }
  }

  Future<void> _subscribeToSensorData() async {
    if (state.connectionState != DeviceConnectionState.connected) return;

    final sensorUuid = Uuid.parse(kSensorDataUuid);
    final discovered = state.characteristics
        .where((item) => item.characteristic.characteristicId == sensorUuid)
        .toList();

    if (discovered.isEmpty) {
      state = state.copyWith(
        liveValue: 'Sensor characteristic not found on device',
        isSubscribed: false,
      );
      return;
    }

    if (!discovered.first.isNotifiable) {
      state = state.copyWith(
        liveValue: 'Sensor characteristic is not notifiable',
        isSubscribed: false,
      );
      return;
    }

    await _notifySub?.cancel();
    _notifySub = null;

    final char = discovered.first.characteristic;
    try {
      _notifySub = _ble
          .subscribeToCharacteristic(char)
          .handleError((Object error) {
            if (state.connectionState == DeviceConnectionState.connected) {
              state = state.copyWith(
                liveValue: 'Subscribe error: $error',
                isSubscribed: false,
              );
            }
          })
          .listen(
        (data) {
          state = state.copyWith(
            liveValue: utf8.decode(data),
            isSubscribed: true,
          );
        },
        onError: (error) {
          state = state.copyWith(
            liveValue: 'Subscribe error: $error',
            isSubscribed: false,
          );
        },
        cancelOnError: false,
      );
    } catch (e) {
      state = state.copyWith(
        liveValue: 'Subscribe error: $e',
        isSubscribed: false,
      );
    }
  }

  Future<void> writeControl(String value) async {
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(kServiceUuid),
        characteristicId: Uuid.parse(kControlUuid),
        deviceId: _deviceId,
      );
      await _ble.writeCharacteristicWithoutResponse(
        char,
        value: utf8.encode(value),
      );
    } catch (e) {
      state = state.copyWith(
        connectionError: 'Write failed: $e',
      );
    }
  }

  // Send data with response (waits for device acknowledgment)
  Future<void> writeControlWithResponse(String value) async {
    try {
      final char = QualifiedCharacteristic(
        serviceId: Uuid.parse(kServiceUuid),
        characteristicId: Uuid.parse(kControlUuid),
        deviceId: _deviceId,
      );
      await _ble.writeCharacteristicWithResponse(
        char,
        value: utf8.encode(value),
      );
    } catch (e) {
      state = state.copyWith(
        connectionError: 'Write with response failed: $e',
      );
    }
  }

  // Disconnect device properly without deinitializing BLE
  Future<void> requestMtuSize(int mtuSize) async {
    try {
      await _ble.requestMtu(deviceId: _deviceId, mtu: mtuSize);
    } catch (e) {
      state = state.copyWith(connectionError: 'MTU request failed: $e');
    }
  }

  Future<void> disconnect() async {
    _connectInProgress = false;
    await _notifySub?.cancel();
    _notifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    state = state.copyWith(
      connectionState: DeviceConnectionState.disconnected,
      isSubscribed: false,
      services: [],
      characteristics: [],
    );
    // Do NOT call _ble.deinitialize() - it prevents reconnection
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}

/// Provides device state for a specific device
final deviceProvider =
    StateNotifierProvider.family<DeviceNotifier, DeviceState, String>(
  (ref, deviceId) {
    final ble = ref.watch(bleProvider);
    final notifier = DeviceNotifier(ble, deviceId);
    ref.onDispose(notifier.dispose);
    return notifier;
  },
);
