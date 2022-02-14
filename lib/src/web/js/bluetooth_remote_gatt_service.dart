import 'package:js/js_util.dart';

import 'bluetooth_device.dart';
import 'bluetooth_remote_gatt_characteristic.dart';

class BluetoothRemoteGATTService {
  final Object _object;

  bool get isPrimary {
    return getProperty(_object, 'isPrimary');
  }

  String get uuid {
    return getProperty(_object, 'uuid');
  }

  BluetoothDevice? device;

  BluetoothRemoteGATTService.fromObject(this._object, this.device);

  Future<BluetoothRemoteGATTCharacteristic> getCharacteristic(
      String characteristic) async {
    final promise = callMethod(_object, 'getCharacteristic', [characteristic]);
    final object = await promiseToFuture(promise);
    return BluetoothRemoteGATTCharacteristic.fromObject(object, this);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['uuid'] = uuid;
    data['isPrimary'] = isPrimary;
    return data;
  }
}
