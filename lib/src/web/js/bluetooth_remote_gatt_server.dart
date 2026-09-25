import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'bluetooth_device.dart';
import 'bluetooth_remote_gatt_service.dart';

class BluetoothRemoteGATTServer {
  final JSObject _object;

  bool get connected {
    return (_object.getProperty('connected'.toJS) as JSBoolean).toDart;
  }

  BluetoothDevice? device;

  BluetoothRemoteGATTServer.fromObject(this._object, this.device);

  Future<BluetoothRemoteGATTServer> connect() async {
    final promise = _object.callMethod('connect'.toJS);
    await (promise as JSPromise<JSAny?>).toDart;
    return this;
  }

  void disconnect() {
    _object.callMethod('disconnect'.toJS);
  }

  Future<BluetoothRemoteGATTService> getPrimaryService(
      String serviceUUID) async {
    final promise =
        _object.callMethod('getPrimaryService'.toJS, serviceUUID.toJS);
    final object = await (promise as JSPromise<JSObject>).toDart;
    return BluetoothRemoteGATTService.fromObject(object, device);
  }
}
