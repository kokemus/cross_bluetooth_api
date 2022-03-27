import 'dart:async';

import 'package:cross_bluetooth_api/src/channels.dart';
import 'package:flutter/services.dart';

import 'src/models/device.dart';
import 'src/models/errors.dart';
import 'src/models/request_device_options.dart';

export 'src/models/device.dart';
export 'src/models/request_device_options.dart';
export 'src/models/errors.dart';

class Bluetooth {
  static Future<Device> requestDevice(RequestDeviceOptions options) async {
    try {
      final map =
          await methodChannel.invokeMethod('requestDevice', options.toJson());
      return Device.fromJson(map.cast<String, dynamic>());
    } on PlatformException catch (e) {
      throw UnknownError.fromException(e);
    }
  }
}
