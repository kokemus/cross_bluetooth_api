import 'dart:async';

import 'package:flutter/services.dart';

import 'src/models/device.dart';
import 'src/models/errors.dart';
import 'src/models/request_device_options.dart';

export 'src/models/device.dart';
export 'src/models/request_device_options.dart';
export 'src/models/errors.dart';

class Bluetooth {
  static const MethodChannel _channel = MethodChannel('cross_bluetooth_api');

  static Future<Device> requestDevice(RequestDeviceOptions options) async {
    try {
      final map =
          await _channel.invokeMethod('requestDevice', options.toJson());
      return Device.fromJson(map.cast<String, dynamic>());
    } on PlatformException catch (e) {
      if (e.message != null) {
        if (e.message!.contains('TypeError')) {
          throw TypeError();
        } else if (e.message!.contains('NotFoundError')) {
          throw NotFoundError();
        } else if (e.message!.contains('SecurityError')) {
          throw SecurityError();
        } else if (e.message!.contains('NetworkError')) {
          throw NetworkError(message: e.message);
        } else if (e.message!.contains('NotSupportedError')) {
          throw NotSupportedError(message: e.message);
        } else if (e.message!.contains('InvalidStateError')) {
          throw InvalidStateError(message: e.message);
        }
      }
      throw UnknownError(e.message);
    }
  }
}
