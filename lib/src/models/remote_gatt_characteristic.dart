import 'package:flutter/services.dart';

import 'base.dart';
import 'remote_gatt_service.dart';

class RemoteGATTCharacteristic extends Base {
  RemoteGATTService service;
  late String uuid;
  ByteData? value;

  RemoteGATTCharacteristic(this.service, this.uuid);

  Future<ByteData> readValue() async {
    final data = await invokeMethod('readValue', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid
    });
    return data.buffer.asByteData(data.offsetInBytes);
  }

  Future writeValueWithoutResponse(ByteData value) async {
    await invokeMethod('writeValueWithoutResponse', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
      'value': value.buffer.asUint8List()
    });
    this.value = value;
  }

  Future writeValueWithResponse(ByteData value) async {
    await invokeMethod('writeValueWithResponse', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
      'value': value.buffer.asUint8List()
    });
    this.value = value;
  }

  RemoteGATTCharacteristic.fromJson(Map<String, dynamic> json, this.service) {
    uuid = json['uuid'];
  }
}
