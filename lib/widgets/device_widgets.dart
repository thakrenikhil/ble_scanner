import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_state.dart';
import '../providers/device_provider.dart';

// ── Reusable Card Widget ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

// ── Connection Status Card ────────────────────────────────────────────────────

class ConnectionStatusCard extends StatelessWidget {
  final DeviceState deviceState;
  final String deviceId;
  const ConnectionStatusCard({
    required this.deviceState,
    required this.deviceId,
  });

  Color get _statusColor {
    switch (deviceState.connectionState) {
      case DeviceConnectionState.connected:
        return Colors.greenAccent;
      case DeviceConnectionState.connecting:
        return Colors.orangeAccent;
      case DeviceConnectionState.disconnecting:
        return Colors.orangeAccent;
      case DeviceConnectionState.disconnected:
        return Colors.redAccent;
    }
  }

  IconData get _statusIcon {
    switch (deviceState.connectionState) {
      case DeviceConnectionState.connected:
        return Icons.bluetooth_connected;
      case DeviceConnectionState.connecting:
        return Icons.bluetooth_searching;
      case DeviceConnectionState.disconnecting:
        return Icons.bluetooth_searching;
      case DeviceConnectionState.disconnected:
        return Icons.bluetooth_disabled;
    }
  }

  String get _statusText {
    switch (deviceState.connectionState) {
      case DeviceConnectionState.connected:
        return 'Connected';
      case DeviceConnectionState.connecting:
        return 'Connecting…';
      case DeviceConnectionState.disconnecting:
        return 'Disconnecting…';
      case DeviceConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child:
                deviceState.connectionState == DeviceConnectionState.connecting
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _statusColor,
                        ),
                      )
                    : Icon(_statusIcon, color: _statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Device ID: ${deviceId.substring(0, 8)}…',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live Stream Card ──────────────────────────────────────────────────────────

class LiveStreamCard extends StatelessWidget {
  final DeviceState deviceState;
  const LiveStreamCard({required this.deviceState});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Live Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: deviceState.isSubscribed
                      ? Colors.greenAccent
                      : Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              deviceState.liveValue,
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device Info Card ──────────────────────────────────────────────────────────

class DeviceInfoCard extends StatelessWidget {
  final String value;
  const DeviceInfoCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Device Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Control Card ──────────────────────────────────────────────────────────────

class ControlCard extends ConsumerStatefulWidget {
  final String deviceId;
  final WidgetRef ref;
  const ControlCard({
    required this.deviceId,
    required this.ref,
  });

  @override
  ConsumerState<ControlCard> createState() => _ControlCardState();
}

class _ControlCardState extends ConsumerState<ControlCard> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendCommand() async {
    if (_controller.text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(deviceProvider(widget.deviceId).notifier)
          .writeControl(_controller.text);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Sent: "${_controller.text}"'),
            backgroundColor: Colors.greenAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _controller.clear();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Send failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.send, color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Send Command',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_isSending,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., "LED_ON", "TEMP_READ", "MODE_1"',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (_) => _sendCommand(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendCommand,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Data received will appear in the "Live Data" section above.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Services Card ─────────────────────────────────────────────────────────────

class ServicesCard extends StatelessWidget {
  final DeviceState deviceState;
  const ServicesCard({required this.deviceState});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category, color: Color(0xFF00D4FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Services (${deviceState.services.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (deviceState.services.isEmpty)
            const Text(
              'No services discovered',
              style: TextStyle(color: Colors.white54),
            )
          else
            Column(
              children: [
                for (final service in deviceState.services)
                  _ServiceTile(service: service),
              ],
            ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatefulWidget {
  final DiscoveredService service;
  const _ServiceTile({required this.service});

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Service',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          subtitle: Text(
            widget.service.serviceId.toString(),
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.white54,
            size: 18,
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                for (final char in widget.service.characteristics)
                  _CharacteristicTile(characteristic: char),
              ],
            ),
          ),
        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }
}

class _CharacteristicTile extends StatelessWidget {
  final DiscoveredCharacteristic characteristic;
  const _CharacteristicTile({required this.characteristic});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        'Characteristic',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            characteristic.characteristicId.toString(),
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (characteristic.isReadable) _PropertyBadge('R', Colors.blue),
              if (characteristic.isWritableWithoutResponse)
                _PropertyBadge('W', Colors.green),
              if (characteristic.isNotifiable)
                _PropertyBadge('N', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _PropertyBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PropertyBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Error Card ────────────────────────────────────────────────────────────────

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
