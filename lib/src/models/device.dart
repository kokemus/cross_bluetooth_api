import 'remote_gatt_server.dart';

class Device {
  String? id;
  String? name;
  late RemoteGATTServer gatt;

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
