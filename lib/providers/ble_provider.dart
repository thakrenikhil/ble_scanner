import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:riverpod/riverpod.dart';

// singleton (Singular Instance)
final bleProvider = Provider<FlutterReactiveBle>((ref) {
  return FlutterReactiveBle();
});
