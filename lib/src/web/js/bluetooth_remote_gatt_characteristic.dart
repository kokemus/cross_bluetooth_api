import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';

import 'bluetooth_remote_gatt_service.dart';
import 'bluetooth_device.dart';

class BluetoothRemoteGATTCharacteristic {
  final JSObject _object;

  String get uuid {
    return (_object.getProperty('uuid'.toJS) as JSString).toDart;
  }

  BluetoothRemoteGATTService? service;

  BluetoothRemoteGATTCharacteristic.fromObject(this._object, this.service);

  Future<ByteData> readValue() async {
    final promise = _object.callMethod('readValue'.toJS);
    final object = await (promise as JSPromise<JSDataView>).toDart;
    return object.toDart;
  }

  Future writeValueWithoutResponse(ByteData value) async {
    final promise = _object.callMethod(
      'writeValueWithoutResponse'.toJS,
      value.toJS,
    );
    final object = await (promise as JSPromise<JSAny?>).toDart;
    return object;
  }

  Future startNotifications() async {
    final promise = _object.callMethod('startNotifications'.toJS);
    final object = await (promise as JSPromise<JSAny?>).toDart;
    return object;
  }

  Future stopNotifications() async {
    final promise = _object.callMethod('stopNotifications'.toJS);
    final object = await (promise as JSPromise<JSAny?>).toDart;
    return object;
  }

  void addEventListener(String event, EventListener listener) {
    _object.callMethod('addEventListener'.toJS, event.toJS, listener.toJS);
  }

  void removeEventListener(String event, EventListener listener) {
    _object.callMethod('removeEventListener'.toJS, event.toJS, listener.toJS);
  }

  ByteData? getValue() {
    final value = _object.getProperty('value'.toJS);
    if (value == null || value is! JSDataView) {
      return null;
    }
    return value.toDart;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['uuid'] = uuid;
    return data;
  }
}
