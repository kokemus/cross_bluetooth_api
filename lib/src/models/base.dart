import 'package:cross_bluetooth_api/src/channels.dart';
import 'package:flutter/services.dart';

import 'errors.dart';

class Event {
  late String name;

  Event.fromJson(Map json) {
    name = json['name'];
  }
}

class Base {
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await methodChannel.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      throw UnknownError.fromException(e);
    }
  }

  Stream<Event> get events {
    return eventChannel
        .receiveBroadcastStream()
        .cast()
        .map((event) => Event.fromJson(event));
  }
}
