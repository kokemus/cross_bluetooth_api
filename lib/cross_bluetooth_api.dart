
import 'dart:async';

import 'package:flutter/services.dart';

class CrossBluetoothApi {
  static const MethodChannel _channel = MethodChannel('cross_bluetooth_api');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
