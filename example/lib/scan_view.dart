import 'dart:async';
import 'package:cross_bluetooth_api_example/services.dart';
import 'package:cross_bluetooth_api_example/device_view.dart';
import 'package:flutter/material.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

class ScanView extends StatefulWidget {
  const ScanView({
    super.key,
    required this.selectedDevice,
    required this._services,
  });

  final ValueNotifier<Device?> selectedDevice;
  final ValueNotifier<List<String>> _services;

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  ValueNotifier<Device?> get selectedDevice => widget.selectedDevice;
  ValueNotifier<List<String>> get _services => widget._services;

  final ValueNotifier<String?> _namePrefix = ValueNotifier<String?>(null);
  final ValueNotifier<List<String>?> _optionalServices =
      ValueNotifier<List<String>?>(null);
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedService = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _namePrefix.dispose();
    _optionalServices.dispose();
    _loading.dispose();
    _selectedService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Name prefix'),
          onChanged: (value) {
            _namePrefix.value = value.isEmpty ? null : value;
          },
        ),
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
        ListenableBuilder(
          listenable: Listenable.merge([_services, _optionalServices]),
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var service
                    in _services.value + (_optionalServices.value ?? []))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Services.names.entries
                            .firstWhere(
                              (entry) => Services.uuid(entry.key) == service,
                            )
                            .value,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Row(
                        children: [
                          const Text(("Optional")),
                          Checkbox(
                            value:
                                _optionalServices.value?.contains(service) ??
                                false,
                            onChanged: (value) {
                              if (value == true) {
                                _optionalServices.value = List.from(
                                  _optionalServices.value ?? [],
                                )..add(service);
                                _services.value = List.from(_services.value)
                                  ..remove(service);
                              } else {
                                _optionalServices.value = List.from(
                                  _optionalServices.value ?? [],
                                )..remove(service);
                                _services.value = List.from(_services.value)
                                  ..add(service);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              _services.value = List.from(_services.value)
                                ..remove(service);
                              _optionalServices.value = List.from(
                                _optionalServices.value ?? [],
                              )..remove(service);
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
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
                FilledButton(
                  onPressed: () async {
                    try {
                      _loading.value = true;
                      final device = await requestDevice(
                        namePrefix: _namePrefix.value,
                        requiredServices: _services.value,
                        optionalServices: _optionalServices.value,
                      );
                      if (!mounted) return;
                      _loading.value = false;
                      _services.value = List.from(_services.value)
                        ..addAll(_optionalServices.value ?? []);
                      selectedDevice.value = device;
                    } on UnknownError catch (e) {
                      if (!mounted) return;
                      _loading.value = false;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    } catch (e) {
                      if (!mounted) return;
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

  Future<Device> requestDevice({
    String? namePrefix,
    List<String>? requiredServices,
    List<String>? optionalServices,
  }) async {
    final acceptAllDevices =
        (requiredServices?.isEmpty ?? true) && namePrefix == null;
    final device = await Bluetooth.requestDevice(
      RequestDeviceOptions(
        filters: [
          if (requiredServices?.isNotEmpty ?? false)
            Filter(services: requiredServices),
          if (namePrefix != null) Filter(namePrefix: namePrefix),
        ],
        optionalServices: optionalServices,
        acceptAllDevices: acceptAllDevices,
      ),
    );
    await device.gatt.connect();
    return device;
  }
}
