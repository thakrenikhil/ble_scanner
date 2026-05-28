import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'discovered_characteristic.dart';

class DeviceState {
  final DeviceConnectionState connectionState;
  final String? connectionError;
  final List<DiscoveredService> services;
  final List<DiscoveredCharacteristicItem> characteristics;
  final String liveValue;
  final bool isSubscribed;
  final String deviceInfoValue;

  DeviceState({
    this.connectionState = DeviceConnectionState.disconnected,
    this.connectionError,
    this.services = const [],
    this.characteristics = const [],
    this.liveValue = 'waiting for data ...',
    this.isSubscribed = false,
    this.deviceInfoValue = '',
  });

  bool get isConnected => connectionState == DeviceConnectionState.connected;

  DeviceState copyWith({
    DeviceConnectionState? connectionState,
    String? connectionError,
    List<DiscoveredService>? services,
    List<DiscoveredCharacteristicItem>? characteristics,
    String? liveValue,
    bool? isSubscribed,
    String? deviceInfoValue,
  }) {
    return DeviceState(
      connectionState: connectionState ?? this.connectionState,
      connectionError: connectionError ?? this.connectionError,
      services: services ?? this.services,
      characteristics: characteristics ?? this.characteristics,
      liveValue: liveValue ?? this.liveValue,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      deviceInfoValue: deviceInfoValue ?? this.deviceInfoValue,
    );
  }
}
