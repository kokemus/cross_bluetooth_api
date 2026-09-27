import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

import 'characteristics.dart';
import 'services.dart';
import 'characteristic_provider.dart';

class DeviceView extends StatefulWidget {
  const DeviceView({super.key, required this._device, required this._services});

  final ValueNotifier<Device?> _device;
  final ValueNotifier<List<String>> _services;

  @override
  State<DeviceView> createState() => _DeviceViewState();
}

class _DeviceViewState extends State<DeviceView> {
  final ValueNotifier<String> _state = ValueNotifier<String>('');
  final ValueNotifier<String> _value = ValueNotifier<String>('');
  final TextEditingController _writeValue = TextEditingController();
  final ValueNotifier<bool> _writeWithResponse = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _selectedService = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _selectedCharacteristic = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<CharacteristicProvider?> _characteristicProvider =
      ValueNotifier<CharacteristicProvider?>(null);

  @override
  Widget build(BuildContext context) {
    final device = widget._device.value;
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
              stream: widget._device.value?.gattserverdisconnected,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  return Text(
                    'disconnected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            OutlinedButton(
              onPressed: () => _disconnect(),
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
          services: widget._services.value,
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
                      ? () => _read(context)
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
                      ? () => _startNotifications(context)
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
                    final string =
                        characteristicProvider.value!.getString() ?? '';
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            TextField(
              controller: _writeValue,
              scrollPadding: const EdgeInsets.all(32),
              decoration: const InputDecoration(
                labelText: 'Bytes',
                hintText: '0, 16, 255',
              ),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                ValueListenableBuilder(
                  valueListenable: _writeWithResponse,
                  builder: (context, withResponse, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: withResponse,
                          onChanged: (value) {
                            _writeWithResponse.value = value ?? false;
                          },
                        ),
                        const Text('With response'),
                      ],
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _selectedCharacteristic,
                    _selectedService,
                    _writeValue,
                  ]),
                  builder: (context, child) {
                    return FilledButton(
                      onPressed:
                          _selectedService.value != null &&
                              _selectedCharacteristic.value != null &&
                              _writeValue.text.isNotEmpty
                          ? () => _write(context)
                          : null,
                      child: const Text('Write'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _disconnect() async {
    try {
      _loading.value = true;
      final device = widget._device.value;
      _state.value = '';
      await device?.gatt.disconnect();
      _state.value = '';
      widget._device.value = null;
      widget._services.value = [];
      _loading.value = false;
    } on UnknownError catch (e) {
      _loading.value = false;
      _state.value = e.message ?? 'Unknown error';
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Unknown error'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _read(BuildContext context) async {
    try {
      final provider = CharacteristicProvider(
        widget._device.value!,
        _selectedService.value!,
        _selectedCharacteristic.value!,
      );
      _characteristicProvider.value = provider;
      final value = await provider.readValue();
      final string = value.getString() ?? '';
      final bytes = Uint8List.sublistView(value).toString();
      _value.value = bytes + '\n$string';
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _startNotifications(BuildContext context) async {
    try {
      final provider = CharacteristicProvider(
        widget._device.value!,
        _selectedService.value!,
        _selectedCharacteristic.value!,
      );
      _characteristicProvider.value = provider;
      await provider.startNotifications();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifications started')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _write(BuildContext context) async {
    try {
      final provider = CharacteristicProvider(
        widget._device.value!,
        _selectedService.value!,
        _selectedCharacteristic.value!,
      );
      _characteristicProvider.value = provider;
      final bytes = _parseBytes(_writeValue.text);
      await provider.writeValue(
        ByteData.sublistView(bytes),
        withResponse: _writeWithResponse.value,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Value written')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Uint8List _parseBytes(String input) {
    var value = input.trim();
    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.substring(1, value.length - 1).trim();
    }

    final parts = value.split(RegExp(r'[\s,]+'));
    final bytes = parts.map(int.tryParse).toList();
    if (bytes.any((byte) => byte == null || byte < 0 || byte > 255)) {
      throw const FormatException(
        'Enter comma- or space-separated byte values from 0 to 255.',
      );
    }
    return Uint8List.fromList(bytes.cast<int>());
  }

  @override
  void dispose() {
    _characteristicProvider.value?.dispose();
    _characteristicProvider.dispose();
    _selectedCharacteristic.dispose();
    _selectedService.dispose();
    _loading.dispose();
    _writeWithResponse.dispose();
    _writeValue.dispose();
    _value.dispose();
    _state.dispose();
    super.dispose();
  }
}

extension on ByteData {
  String? getString() {
    try {
      return utf8.decode(buffer.asUint8List(offsetInBytes, lengthInBytes));
    } catch (_) {
      return null;
    }
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
