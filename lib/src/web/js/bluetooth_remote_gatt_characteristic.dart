import 'package:flutter/services.dart';
import 'package:js/js_util.dart';

import 'bluetooth_remote_gatt_service.dart';

class BluetoothRemoteGATTCharacteristic {
  final Object _object;

  String get uuid {
    return getProperty(_object, 'uuid');
  }

  BluetoothRemoteGATTService? service;

  BluetoothRemoteGATTCharacteristic.fromObject(this._object, this.service);

  Future<ByteData> readValue() async {
    final promise = callMethod(_object, 'readValue', []);
    final object = await promiseToFuture(promise);
    return object;
  }

  Future writeValueWithoutResponse(ByteData value) async {
    final promise = callMethod(_object, 'writeValueWithoutResponse', [value]);
    final object = await promiseToFuture(promise);
    return object;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['uuid'] = uuid;
    return data;
  }
}
