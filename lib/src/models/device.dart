import 'package:cross_bluetooth_api/src/models/base.dart';

import 'remote_gatt_server.dart';

class Device extends Base {
  String? id;
  String? name;
  late RemoteGATTServer gatt;

  Stream<Device> get gattserverdisconnected {
    return events
        .where((e) => e.name == "gattserverdisconnected")
        .map((_) => this);
  }

  Device.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    gatt = RemoteGATTServer(this);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    return data;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
