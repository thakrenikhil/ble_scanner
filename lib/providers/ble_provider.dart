import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod/riverpod.dart';

/// Provides a singleton instance of FlutterReactiveBle
final bleProvider = Provider<FlutterReactiveBle>((ref) {
  return FlutterReactiveBle();
});
