import 'package:flutter/services.dart';

import 'errors.dart';

class Base {
  final MethodChannel _channel = const MethodChannel('cross_bluetooth_api');

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await _channel.invokeMethod(method, arguments);
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
        }
      }
      throw UnknownError(e.message);
    }
  }
}
