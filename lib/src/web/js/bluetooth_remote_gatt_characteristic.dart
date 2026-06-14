import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';

import 'bluetooth_remote_gatt_service.dart';

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
    final promise =
        _object.callMethod('writeValueWithoutResponse'.toJS, value.toJS);
    final object = await (promise as JSPromise<JSAny?>).toDart;
    return object;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['uuid'] = uuid;
    return data;
  }
}
