import 'dart:async';
import 'dart:js_interop';
import 'package:cross_bluetooth_api/src/web/js/bluetooth_remote_gatt_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'js/bluetooth.dart';
import 'js/bluetooth_device.dart';
import 'js/bluetooth_remote_gatt_characteristic.dart';
import 'js/request_options.dart';

class CrossBluetoothApiWeb {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'cross_bluetooth_api',
      const StandardMethodCodec(),
      registrar,
    );

    const PluginEventChannel eventChannel = PluginEventChannel(
      'cross_bluetooth_api/events',
    );
    eventChannel.setController(controller);

    final pluginInstance = CrossBluetoothApiWeb();
    channel.setMethodCallHandler(pluginInstance._handleMethodCall);
  }

  static final StreamController<Map<String, dynamic>> controller =
      StreamController<Map<String, dynamic>>.broadcast();

  final Map<String, EventListener> _characteristicListeners = {};

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestDevice':
        return await requestDevice(call.arguments.cast<String, dynamic>());
      case 'connect':
        return await connect(call.arguments.cast<String, dynamic>());
      case 'disconnect':
        return await disconnect(call.arguments.cast<String, dynamic>());
      case 'getPrimaryService':
        return await getPrimaryService(call.arguments.cast<String, dynamic>());
      case 'getCharacteristic':
        return await getCharacteristic(call.arguments.cast<String, dynamic>());
      case 'readValue':
        return await readValue(call.arguments.cast<String, dynamic>());
      case 'writeValueWithoutResponse':
        return await writeValueWithoutResponse(
          call.arguments.cast<String, dynamic>(),
        );
      case 'startNotifications':
        return await startNotifications(call.arguments.cast<String, dynamic>());
      case 'stopNotifications':
        return await stopNotifications(call.arguments.cast<String, dynamic>());
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'cross_bluetooth_api for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  final List<BluetoothDevice> _devices = [];

  Future<Map<String, dynamic>> requestDevice(
    Map<String, dynamic> arguments,
  ) async {
    final options = RequestOptions.fromMap(arguments);
    final object = await nativeBluetooth.requestTypedDevice(options).toDart;
    final device = BluetoothDevice.fromObject(object);
    device.addEventListener('gattserverdisconnected', _onDisconnected);
    _devices.add(device);
    return device.toJson();
  }

  Future connect(Map<String, dynamic> arguments) async {
    final device = _getDevice(arguments['id']);
    await device?.gatt?.connect();
  }

  Future disconnect(Map<String, dynamic> arguments) async {
    final device = _getDevice(arguments['id']);
    device?.gatt?.disconnect();
  }

  Future getPrimaryService(Map<String, dynamic> arguments) async {
    final service = await _getPrimaryService(
      arguments['deviceId'],
      arguments['serviceUUID'],
    );
    return service?.toJson();
  }

  Future getCharacteristic(Map<String, dynamic> arguments) async {
    final characteristic = await _getCharacteristic(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    return characteristic?.toJson();
  }

  Future readValue(Map<String, dynamic> arguments) async {
    final characteristic = await _getCharacteristic(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    final value = await characteristic?.readValue();
    return Uint8List.view(value!.buffer);
  }

  Future writeValueWithoutResponse(Map<String, dynamic> arguments) async {
    final characteristic = await _getCharacteristic(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    await characteristic?.writeValueWithoutResponse(
      ByteData.sublistView(arguments['value']),
    );
  }

  Future startNotifications(Map<String, dynamic> arguments) async {
    final characteristic = await _getCharacteristic(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    if (characteristic == null) {
      return;
    }

    final listenerKey = _listenerKey(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    _characteristicListeners.putIfAbsent(listenerKey, () {
      return (event) {
        final value = characteristic.getValue();
        if (value == null) {
          return;
        }

        controller.add({
          'name': 'characteristicvaluechanged',
          'deviceId': arguments['deviceId'],
          'serviceUUID': arguments['serviceUUID'],
          'characteristicUUID': arguments['characteristic'],
          'value': Uint8List.view(value.buffer),
        });
      };
    });

    final listener = _characteristicListeners[listenerKey]!;
    characteristic.addEventListener('characteristicvaluechanged', listener);
    await characteristic.startNotifications();
    return true;
  }

  Future stopNotifications(Map<String, dynamic> arguments) async {
    final characteristic = await _getCharacteristic(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    if (characteristic == null) {
      return;
    }

    final listenerKey = _listenerKey(
      arguments['deviceId'],
      arguments['serviceUUID'],
      arguments['characteristic'],
    );
    final listener = _characteristicListeners.remove(listenerKey);
    if (listener != null) {
      characteristic.removeEventListener(
        'characteristicvaluechanged',
        listener,
      );
    }

    await characteristic.stopNotifications();
    return true;
  }

  void _onDisconnected(event) {
    final device = BluetoothDevice.fromObject(event.target);
    _devices.remove(device);
    controller.add({'name': 'gattserverdisconnected'});
  }

  BluetoothDevice? _getDevice(String deviceId) {
    return _devices.firstWhere((d) => d.id == deviceId);
  }

  Future<BluetoothRemoteGATTService?> _getPrimaryService(
    String deviceId,
    String serviceUUID,
  ) async {
    final device = _getDevice(deviceId);
    return await device?.gatt?.getPrimaryService(serviceUUID);
  }

  Future<BluetoothRemoteGATTCharacteristic?> _getCharacteristic(
    String deviceId,
    String serviceUUID,
    String characteristic,
  ) async {
    final service = await _getPrimaryService(deviceId, serviceUUID);
    return await service?.getCharacteristic(characteristic);
  }

  String _listenerKey(
    String deviceId,
    String serviceUUID,
    String characteristic,
  ) {
    return '$deviceId/$serviceUUID/$characteristic';
  }
}
