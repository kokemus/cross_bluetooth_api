import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';
import 'package:flutter/material.dart';

class DevicesView extends StatefulWidget {
  const DevicesView({super.key, required this.selectedDevice});

  final ValueNotifier<Device?> selectedDevice;

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  List<Device> _devices = [];
  bool _loading = true;
  Device? _busyDevice;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _busyDevice != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(
            _error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (_devices.isEmpty)
          const Text('No available devices.')
        else
          for (final device in _devices)
            LayoutBuilder(
              builder: (context, constraints) {
                final details = Text(
                  device.name?.isNotEmpty == true
                      ? device.name!
                      : 'Unnamed device',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
                final actions = Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_busyDevice == device)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => _forget(device),
                      child: const Text('Forget'),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => _connect(device),
                      child: const Text('Connect'),
                    ),
                  ],
                );
                return Row(
                  spacing: 8,
                  children: [
                    Expanded(child: details),
                    actions,
                  ],
                );
              },
            ),
      ],
    );
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await Bluetooth.getDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
    } on NotSupportedError catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Not supported');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(Device device) async {
    setState(() => _busyDevice = device);
    try {
      await device.gatt.connect();
      if (!mounted) return;
      widget.selectedDevice.value = device;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busyDevice = null);
    }
  }

  Future<void> _forget(Device device) async {
    setState(() => _busyDevice = device);
    try {
      await device.forget();
      if (!mounted) return;
      setState(() {
        _devices.removeWhere((entry) => entry.id == device.id);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busyDevice = null);
    }
  }
}
