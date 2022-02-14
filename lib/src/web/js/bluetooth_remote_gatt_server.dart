import 'package:js/js_util.dart';

import 'bluetooth_device.dart';
import 'bluetooth_remote_gatt_service.dart';

class BluetoothRemoteGATTServer {
  final Object _object;

  bool get connected {
    return getProperty(_object, 'connected');
  }

  BluetoothDevice? device;

  BluetoothRemoteGATTServer.fromObject(this._object, this.device);

  Future<BluetoothRemoteGATTServer> connect() async {
    final promise = callMethod(_object, 'connect', []);
    await promiseToFuture(promise);
    return this;
  }

  void disconnect() {
    callMethod(_object, 'disconnect', []);
  }

  Future<BluetoothRemoteGATTService> getPrimaryService(
      String serviceUUID) async {
    final promise = callMethod(_object, 'getPrimaryService', [serviceUUID]);
    final object = await promiseToFuture(promise);
    return BluetoothRemoteGATTService.fromObject(object, device);
  }
}
