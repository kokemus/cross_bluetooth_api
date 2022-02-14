import 'package:js/js.dart';
import 'package:js/js_util.dart';

import 'bluetooth_remote_gatt_server.dart';

class BluetoothDevice {
  String? id;
  String? name;
  BluetoothRemoteGATTServer? gatt;

  final Object _object;

  BluetoothDevice.fromObject(this._object) {
    id = getProperty(_object, 'id');
    name = getProperty(_object, 'name');
    gatt = BluetoothRemoteGATTServer.fromObject(
        getProperty(_object, 'gatt'), this);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    return data;
  }
}
