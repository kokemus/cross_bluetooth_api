import 'base.dart';
import 'device.dart';
import 'remote_gatt_characteristic.dart';

class RemoteGATTService extends Base {
  Device device;
  bool isPrimary = false;
  late String uuid;

  RemoteGATTService(this.device, this.uuid);

  Future<RemoteGATTCharacteristic> getCharacteristic(
      String characteristic) async {
    final map = await invokeMethod('getCharacteristic', {
      'deviceId': device.id,
      'serviceUUID': uuid,
      'characteristic': characteristic
    });
    return RemoteGATTCharacteristic.fromJson(map.cast<String, dynamic>(), this);
  }

  RemoteGATTService.fromJson(Map<String, dynamic> json, this.device) {
    uuid = json['uuid'];
    isPrimary = json['isPrimary'];
  }
}
