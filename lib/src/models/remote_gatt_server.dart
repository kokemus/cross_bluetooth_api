import 'base.dart';
import 'device.dart';
import 'remote_gatt_service.dart';

class RemoteGATTServer extends Base {
  bool connected = false;
  Device device;

  RemoteGATTServer(this.device);

  Future<RemoteGATTServer> connect() async {
    await invokeMethod('connect', device.toJson());
    connected = true;
    return this;
  }

  Future disconnect() async {
    await invokeMethod('disconnect', device.toJson());
    connected = false;
  }

  Future<RemoteGATTService> getPrimaryService(String serviceUUID) async {
    final map = await invokeMethod('getPrimaryService',
        {'deviceId': device.id, 'serviceUUID': serviceUUID});
    return RemoteGATTService.fromJson(map.cast<String, dynamic>(), device);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['devide'] = device.toJson();
    data['connected'] = connected;
    return data;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
