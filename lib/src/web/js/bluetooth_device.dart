import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'bluetooth_remote_gatt_server.dart';

class BluetoothDevice {
  String? id;
  String? name;
  BluetoothRemoteGATTServer? gatt;

  final JSObject _object;

  BluetoothDevice.fromObject(this._object) {
    id = (_object.getProperty('id'.toJS) as JSString?)?.toDart;
    name = (_object.getProperty('name'.toJS) as JSString?)?.toDart;
    gatt = BluetoothRemoteGATTServer.fromObject(
        _object.getProperty('gatt'.toJS) as JSObject, this);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    return data;
  }
}
