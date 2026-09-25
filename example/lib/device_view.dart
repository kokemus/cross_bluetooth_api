import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

import 'characteristics.dart';
import 'services.dart';
import 'characteristic_provider.dart';

class DeviceView extends StatelessWidget {
  DeviceView({super.key, required this._device, required this._services});

  final ValueNotifier<Device?> _device;
  final ValueNotifier<List<String>> _services;
  final ValueNotifier<String> _state = ValueNotifier<String>('');
  final ValueNotifier<String> _value = ValueNotifier<String>('');
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedService = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _selectedCharacteristic = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<CharacteristicProvider?> _characteristicProvider =
      ValueNotifier<CharacteristicProvider?>(null);

  @override
  Widget build(BuildContext context) {
    final device = _device.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            Text(
              device?.name ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            StreamBuilder(
              stream: _device.value?.gattserverdisconnected,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  return Text(
                    '${_device.value?.name} disconnected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            OutlinedButton(
              onPressed: () async {
                try {
                  _loading.value = true;
                  await _disconnect();
                  _loading.value = false;
                } on UnknownError catch (e) {
                  _loading.value = false;
                  _state.value = e.message ?? 'Unknown error';
                }
              },
              child: !_loading.value
                  ? const Text('Disconnect')
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          ],
        ),
        SelectService(
          selectedService: _selectedService,
          services: _services.value,
        ),
        SelectCharacteristic(selectedCharacteristic: _selectedCharacteristic),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                _selectedCharacteristic,
                _selectedService,
              ]),
              builder: (context, child) {
                return FilledButton(
                  onPressed:
                      _selectedService.value != null &&
                          _selectedCharacteristic.value != null
                      ? () async {
                          _characteristicProvider.value =
                              CharacteristicProvider(
                                _device.value!,
                                _selectedService.value!,
                                _selectedCharacteristic.value!,
                              );
                          final value = await _characteristicProvider.value!
                              .readValue();
                          final bytes = Uint8List.sublistView(value).toString();
                          final string = value.getString();
                          _value.value = bytes + '\n$string';
                        }
                      : null,
                  child: const Text('Read'),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _value,
              builder: (context, value, child) {
                return Expanded(child: Text(_value.value));
              },
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                _selectedCharacteristic,
                _selectedService,
              ]),
              builder: (context, child) {
                return FilledButton(
                  onPressed:
                      _selectedService.value != null &&
                          _selectedCharacteristic.value != null
                      ? () async {
                          _characteristicProvider.value =
                              CharacteristicProvider(
                                _device.value!,
                                _selectedService.value!,
                                _selectedCharacteristic.value!,
                              );
                          _characteristicProvider.value!.startNotifications();
                        }
                      : null,
                  child: const Text('Notify'),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _characteristicProvider,
              builder: (context, provider, child) {
                if (provider == null) {
                  return const Expanded(child: Text(''));
                }
                return ListenableBuilder(
                  listenable: provider,
                  builder: (context, child) {
                    final characteristicProvider =
                        _characteristicProvider.value;
                    if (characteristicProvider?.value == null) {
                      return const Expanded(child: Text(''));
                    }
                    final bytes = Uint8List.sublistView(
                      characteristicProvider!.value!,
                    ).toString();
                    final string = characteristicProvider.value!.getString();
                    final lastUpdated = characteristicProvider.lastUpdated;
                    return Expanded(
                      child: Text(bytes + '\n$string' + '\n$lastUpdated'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future _disconnect() async {
    final device = _device.value;
    _state.value = '';
    await device?.gatt.disconnect();
    _state.value = '';
    _device.value = null;
    _services.value = [];
  }
}

extension on ByteData {
  String getString() {
    return utf8.decode(buffer.asUint8List(offsetInBytes, lengthInBytes));
  }
}

class SelectService extends StatelessWidget {
  const SelectService({
    super.key,
    required this.selectedService,
    this._services,
  });

  final ValueNotifier<String?> selectedService;
  final List<String>? _services;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: selectedService.value,
      decoration: const InputDecoration(labelText: 'Service'),
      items:
          _services
              ?.map(
                (service) => DropdownMenuItem(
                  value: service,
                  child: Text(
                    Services.names.entries
                        .firstWhere(
                          (entry) => Services.uuid(entry.key) == service,
                        )
                        .value,
                  ),
                ),
              )
              .toList() ??
          Services.names.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: Services.uuid(entry.key),
                  child: Text(entry.value),
                ),
              )
              .toList(),
      onChanged: (service) {
        selectedService.value = service;
      },
    );
  }
}

class SelectCharacteristic extends StatelessWidget {
  const SelectCharacteristic({super.key, required this.selectedCharacteristic});

  final ValueNotifier<String?> selectedCharacteristic;
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: selectedCharacteristic.value,
      decoration: const InputDecoration(labelText: 'Characteristic'),
      items: Characteristics.names.entries
          .map(
            (entry) => DropdownMenuItem(
              value: Characteristics.uuid(entry.key),
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: (characteristic) {
        selectedCharacteristic.value = characteristic;
      },
    );
  }
}
