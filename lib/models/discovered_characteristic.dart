import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class DiscoveredCharacteristicItem {
  final QualifiedCharacteristic characteristic;
  final bool isNotifiable;
  final bool isReadable;
  final bool isWritable;

  DiscoveredCharacteristicItem({
    required this.characteristic,
    required this.isNotifiable,
    required this.isReadable,
    required this.isWritable,
  });

  String get uuidShort {
    final full = characteristic.characteristicId.toString();
    return full.length > 8 ? '...${full.substring(full.length - 8)}' : full;
  }
}
