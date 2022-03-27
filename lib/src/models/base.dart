import 'package:cross_bluetooth_api/src/channels.dart';
import 'package:flutter/services.dart';

import 'errors.dart';

class Base {
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await methodChannel.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      throw UnknownError.fromException(e);
    }
  }
}
