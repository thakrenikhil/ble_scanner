import 'package:ble_vitals_scanner/models/scanner_state.dart' show ScannerState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/ble_device.dart';
import '../providers/scanner_provider.dart';
import 'device_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
      (s) => s == PermissionStatus.granted,
    );

    setState(() => _permissionsGranted = allGranted);

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth & Location permissions are required.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerProvider);
    final scanner = ref.read(scannerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D27),
        title: const Text(
          'BLE Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (scannerState.isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00D4FF),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              scannerState.isScanning ? Icons.stop_circle : Icons.radar,
              color: scannerState.isScanning
                  ? Colors.redAccent
                  : const Color(0xFF00D4FF),
            ),
            onPressed: _permissionsGranted
                ? () {
                    if (scannerState.isScanning) {
                      scanner.stopScan();
                    } else {
                      scanner.startScan();
                    }
                  }
                : null,
            tooltip: scannerState.isScanning ? 'Stop Scan' : 'Start Scan',
          ),
        ],
      ),
      body: !_permissionsGranted
          ? _buildPermissionDenied()
          : scannerState.devices.isEmpty
              ? _buildEmptyState(scannerState, scanner)
              : _buildDeviceList(scannerState),
      floatingActionButton: !scannerState.isScanning && _permissionsGranted
          ? FloatingActionButton.extended(
              onPressed: scanner.startScan,
              backgroundColor: const Color(0xFF00D4FF),
              icon: const Icon(Icons.bluetooth_searching, color: Colors.black),
              label: const Text('Scan',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled,
              size: 80, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text(
            'Permissions Required',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bluetooth & Location permissions\nare needed to scan for devices.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _requestPermissions,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF)),
            child: const Text('Grant Permissions',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ScannerState state, ScannerNotifier scanner) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            state.isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
            size: 80,
            color: state.isScanning ? const Color(0xFF00D4FF) : Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            state.isScanning ? 'Scanning for devices…' : 'No devices found',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceList(ScannerState state) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = state.devices[index];
        return _DeviceCard(device: device);
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final BleDeviceItem device;
  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceScreen(device: device),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bluetooth, color: Color(0xFF00D4FF)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RSSI: ${device.rssi} dBm',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
