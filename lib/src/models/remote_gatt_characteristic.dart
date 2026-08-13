import 'package:flutter/services.dart';

import 'base.dart';
import 'remote_gatt_service.dart';

class RemoteGATTCharacteristic extends Base {
  RemoteGATTService service;
  late String uuid;
  ByteData? value;

  RemoteGATTCharacteristic(this.service, this.uuid);

  Stream<RemoteGATTCharacteristic> get characteristicvaluechanged {
    return events
        .where(
          (e) =>
              e.name == 'characteristicvaluechanged' &&
              e.deviceId == service.device.id &&
              e.serviceUUID == service.uuid &&
              e.characteristicUUID == uuid,
        )
        .map((event) {
          if (event.value != null) {
            value = event.value;
          }
          return this;
        });
  }

  Future<ByteData> readValue() async {
    final data = await invokeMethod('readValue', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
    });
    return data.buffer.asByteData(data.offsetInBytes);
  }

  Future writeValueWithoutResponse(ByteData value) async {
    await invokeMethod('writeValueWithoutResponse', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
      'value': value.buffer.asUint8List(),
    });
    this.value = value;
  }

  Future writeValueWithResponse(ByteData value) async {
    await invokeMethod('writeValueWithResponse', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
      'value': value.buffer.asUint8List(),
    });
    this.value = value;
  }

  Future<RemoteGATTCharacteristic> startNotifications() async {
    await invokeMethod('startNotifications', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
    });
    return this;
  }

  Future<RemoteGATTCharacteristic> stopNotifications() async {
    await invokeMethod('stopNotifications', {
      'deviceId': service.device.id,
      'serviceUUID': service.uuid,
      'characteristic': uuid,
    });
    return this;
  }

  RemoteGATTCharacteristic.fromJson(Map<String, dynamic> json, this.service) {
    uuid = json['uuid'];
  }
}
