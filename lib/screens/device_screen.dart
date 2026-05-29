import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ble_device.dart';
import '../providers/device_provider.dart';
import '../widgets/device_widgets.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  final BleDeviceItem device;
  const DeviceScreen({super.key, required this.device});

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceProvider(widget.device.id).notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider(widget.device.id));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D27),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            ref.read(deviceProvider(widget.device.id).notifier).disconnect();
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.device.displayName,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (deviceState.isConnected)
            TextButton.icon(
              onPressed: () {
                ref.read(deviceProvider(widget.device.id).notifier).disconnect();
                Navigator.pop(context);
              },
              icon:
                  const Icon(Icons.link_off, color: Colors.redAccent, size: 18),
              label: const Text('Disconnect',
                  style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConnectionStatusCard(
            deviceState: deviceState,
            deviceId: widget.device.id,
          ),
          const SizedBox(height: 12),
          if (deviceState.isConnected) ...[
            LiveStreamCard(deviceState: deviceState),
            const SizedBox(height: 12),
            if (deviceState.deviceInfoValue.isNotEmpty)
              DeviceInfoCard(value: deviceState.deviceInfoValue),
            if (deviceState.deviceInfoValue.isNotEmpty)
              const SizedBox(height: 12),
            ControlCard(
              deviceId: widget.device.id,
              ref: ref,
            ),
            const SizedBox(height: 12),
            ServicesCard(deviceState: deviceState),
          ],
          if (deviceState.connectionError != null)
            ErrorCard(message: deviceState.connectionError!),
        ],
      ),
    );
  }
}
