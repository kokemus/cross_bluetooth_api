import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'bluetooth_device.dart';
import 'bluetooth_remote_gatt_characteristic.dart';

class BluetoothRemoteGATTService {
  final JSObject _object;

  bool get isPrimary {
    return (_object.getProperty('isPrimary'.toJS) as JSBoolean).toDart;
  }

  String get uuid {
    return (_object.getProperty('uuid'.toJS) as JSString).toDart;
  }

  BluetoothDevice? device;

  BluetoothRemoteGATTService.fromObject(this._object, this.device);

  Future<BluetoothRemoteGATTCharacteristic> getCharacteristic(
      String characteristic) async {
    final promise =
        _object.callMethod('getCharacteristic'.toJS, characteristic.toJS);
    final object = await (promise as JSPromise<JSObject>).toDart;
    return BluetoothRemoteGATTCharacteristic.fromObject(object, this);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['uuid'] = uuid;
    data['isPrimary'] = isPrimary;
    return data;
  }
}
