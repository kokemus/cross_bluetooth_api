import 'dart:async';
import 'dart:typed_data';
import 'package:js/js_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'js/bluetooth.dart';
import 'js/bluetooth_device.dart';

/// A web implementation of the CrossBluetoothApi plugin.
class CrossBluetoothApiWeb {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'cross_bluetooth_api',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = CrossBluetoothApiWeb();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
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
            call.arguments.cast<String, dynamic>());
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'kd_ble_api for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  final List<BluetoothDevice> _devices = [];

  Future<Map<String, dynamic>> requestDevice(
      Map<String, dynamic> arguments) async {
    final object =
        await promiseToFuture(NativeBluetooth.requestDevice(jsify(arguments)));
    final device = BluetoothDevice.fromObject(object);
    _devices.add(device);
    return device.toJson();
  }

  Future connect(Map<String, dynamic> arguments) async {
    final device = _devices.firstWhere((d) => d.id == arguments['id']);
    await device.gatt?.connect();
  }

  Future disconnect(Map<String, dynamic> arguments) async {
    final device = _devices.firstWhere((d) => d.id == arguments['id']);
    _devices.remove(device);
    device.gatt?.disconnect();
  }

  Future getPrimaryService(Map<String, dynamic> arguments) async {
    final device = _devices.firstWhere((d) => d.id == arguments['deviceId']);
    final service =
        await device.gatt?.getPrimaryService(arguments['serviceUUID']);
    return service?.toJson();
  }

  Future getCharacteristic(Map<String, dynamic> arguments) async {
    final device = _devices.firstWhere((d) => d.id == arguments['deviceId']);
    final service =
        await device.gatt?.getPrimaryService(arguments['serviceUUID']);
    final characteristic =
        await service?.getCharacteristic(arguments['characteristic']);
    return characteristic?.toJson();
  }

  Future readValue(Map<String, dynamic> arguments) async {
    final device = _devices.firstWhere((d) => d.id == arguments['deviceId']);
    final service =
        await device.gatt?.getPrimaryService(arguments['serviceUUID']);
    final characteristic =
        await service?.getCharacteristic(arguments['characteristic']);
    final value = await characteristic?.readValue();
    return Uint8List.view(value!.buffer);
  }

  Future writeValueWithoutResponse(Map<String, dynamic> arguments) async {
    final device = _devices.firstWhere((d) => d.id == arguments['deviceId']);
    final service =
        await device.gatt?.getPrimaryService(arguments['serviceUUID']);
    final characteristic =
        await service?.getCharacteristic(arguments['characteristic']);
    await characteristic
        ?.writeValueWithoutResponse(ByteData.sublistView(arguments['value']));
  }
}
