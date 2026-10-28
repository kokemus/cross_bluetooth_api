import 'package:cross_bluetooth_api/src/channels.dart';
import 'package:flutter/services.dart';

import 'errors.dart';

class Event {
  late String name;
  String? deviceId;
  String? serviceUUID;
  String? characteristicUUID;
  ByteData? value;

  Event.fromJson(Map<dynamic, dynamic> json) {
    name = json['name'];
    deviceId = json['deviceId'];
    serviceUUID = json['serviceUUID'];
    characteristicUUID = json['characteristicUUID'];

    final eventValue = json['value'];
    if (eventValue is ByteData) {
      value = eventValue;
    } else if (eventValue is Uint8List) {
      value = eventValue.buffer.asByteData(
        eventValue.offsetInBytes,
        eventValue.lengthInBytes,
      );
    } else if (eventValue is List<int>) {
      final bytes = Uint8List.fromList(eventValue);
      value = bytes.buffer.asByteData();
    }
  }
}

class Base {
  static final Stream<Event> _events = eventChannel
      .receiveBroadcastStream()
      .cast<Map<dynamic, dynamic>>()
      .map(Event.fromJson);

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await methodChannel.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      throw UnknownError.fromException(e);
    }
  }

  Stream<Event> get events => _events;
}
