import 'dart:async';

import 'package:cross_bluetooth_api/src/channels.dart';
import 'package:flutter/services.dart';

import 'src/models/device.dart';
import 'src/models/errors.dart';
import 'src/models/request_device_options.dart';

export 'src/models/device.dart';
export 'src/models/request_device_options.dart';
export 'src/models/errors.dart';
export 'src/models/remote_gatt_server.dart';
export 'src/models/remote_gatt_service.dart';
export 'src/models/remote_gatt_characteristic.dart';

class Bluetooth {
  static Future<List<Device>> getDevices() async {
    try {
      final devices = await methodChannel.invokeMethod<List<dynamic>>(
        'getDevices',
      );
      return devices!
          .map((map) => Device.fromJson((map as Map).cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      throw UnknownError.fromException(e);
    }
  }

  static Future<Device> requestDevice(RequestDeviceOptions options) async {
    try {
      final map = await methodChannel.invokeMethod(
        'requestDevice',
        options.toJson(),
      );
      return Device.fromJson(map.cast<String, dynamic>());
    } on PlatformException catch (e) {
      throw UnknownError.fromException(e);
    }
  }
}
