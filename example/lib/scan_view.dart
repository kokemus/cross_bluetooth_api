import 'dart:async';
import 'package:cross_bluetooth_api_example/services.dart';
import 'package:cross_bluetooth_api_example/device_view.dart';
import 'package:flutter/material.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

class ScanView extends StatelessWidget {
  ScanView({super.key, required this.selectedDevice, required this._services});

  final ValueNotifier<Device?> selectedDevice;
  final ValueNotifier<List<String>> _services;

  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedService = ValueNotifier<String?>(null);

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder(
          valueListenable: _selectedService,
          builder: (context, value, child) {
            return Row(
              spacing: 16,
              children: [
                Expanded(
                  child: SelectService(selectedService: _selectedService),
                ),
                OutlinedButton(
                  onPressed: _selectedService.value != null
                      ? () {
                          _services.value = List.from(_services.value)
                            ..add(_selectedService.value ?? '');
                        }
                      : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: _services,
          builder: (context, value, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var service in _services.value)
                  Text(
                    Services.names.entries
                        .firstWhere(
                          (entry) => Services.uuid(entry.key) == service,
                        )
                        .value,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
              ],
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: _loading,
          builder: (context, value, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    try {
                      _loading.value = true;
                      final device = await requestDevice(_services.value);
                      _loading.value = false;
                      selectedDevice.value = device;
                    } on UnknownError catch (e) {
                      _loading.value = false;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: !_loading.value
                      ? const Text('Scan')
                      : const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<Device> requestDevice(List<String> services) async {
    final device = await Bluetooth.requestDevice(
      RequestDeviceOptions(acceptAllDevices: true, optionalServices: services),
    );
    await device.gatt.connect();
    return device;
  }
}
