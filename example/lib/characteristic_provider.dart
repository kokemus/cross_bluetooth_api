import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

class BaseCharacteristicProvider<T> with ChangeNotifier {
  BaseCharacteristicProvider(
    this._device,
    this._serviceUuid,
    this._characteristicUuid,
  );

  final Device _device;
  final String _serviceUuid;
  final String _characteristicUuid;
  StreamSubscription<RemoteGATTCharacteristic>? _subscription;
  RemoteGATTCharacteristic? _characteristic;

  T? _value;
  DateTime? _lastUpdated;

  T? get value => _value;
  DateTime? get lastUpdated => _lastUpdated;

  T convertValue(ByteData value) {
    return value as T;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<ByteData> readValue() async {
    _characteristic =
        _characteristic ??
        await _device.gatt
            .getPrimaryService(_serviceUuid)
            .then((service) => service.getCharacteristic(_characteristicUuid));
    return await _characteristic!.readValue();
  }

  Future<void> startNotifications() async {
    _characteristic =
        _characteristic ??
        await _device.gatt
            .getPrimaryService(_serviceUuid)
            .then((service) => service.getCharacteristic(_characteristicUuid));

    await _subscription?.cancel();
    _subscription = _characteristic!.characteristicvaluechanged.listen((c) {
      final currentValue = c.value;
      if (currentValue == null || currentValue.lengthInBytes == 0) {
        return;
      }

      _value = convertValue(currentValue);
      _lastUpdated = DateTime.now();
      notifyListeners();
    });
    await _characteristic!.startNotifications();
  }

  Future<void> stopNotifications() async {
    await _subscription?.cancel();
    _subscription = null;

    _characteristic =
        _characteristic ??
        await _device.gatt
            .getPrimaryService(_serviceUuid)
            .then((service) => service.getCharacteristic(_characteristicUuid));
    await _characteristic!.stopNotifications();
  }
}

typedef CharacteristicProvider = BaseCharacteristicProvider<ByteData>;

class StringCharacteristicProvider extends BaseCharacteristicProvider<String> {
  StringCharacteristicProvider(
    Device device,
    String serviceUuid,
    String characteristicUuid,
  ) : super(device, serviceUuid, characteristicUuid);

  @override
  String convertValue(ByteData value) {
    return String.fromCharCodes(value.buffer.asUint8List());
  }
}

class BatteryLevelCharacteristicProvider
    extends BaseCharacteristicProvider<int> {
  BatteryLevelCharacteristicProvider(Device device)
    : super(
        device,
        '0000180f-0000-1000-8000-00805f9b34fb',
        '00002a19-0000-1000-8000-00805f9b34fb',
      );

  @override
  int convertValue(ByteData value) {
    return value.getUint8(0);
  }
}
