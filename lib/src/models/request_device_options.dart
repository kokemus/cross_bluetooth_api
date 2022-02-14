class RequestDeviceOptions {
  List<Filter>? filters;
  List<String>? optionalServices;
  bool? acceptAllDevices;

  RequestDeviceOptions(
      {this.filters, this.optionalServices, this.acceptAllDevices});

  RequestDeviceOptions.fromJson(Map<String, dynamic> json) {
    if (json['filters'] != null) {
      filters = <Filter>[];
      json['filters'].forEach((v) {
        filters!.add(Filter.fromJson(v));
      });
    }
    optionalServices = json['optionalServices'].cast<String>();
    acceptAllDevices = json['acceptAllDevices'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (filters != null) {
      data['filters'] = filters!.map((v) => v.toJson()).toList();
    }
    if (optionalServices != null) {
      data['optionalServices'] = optionalServices;
    }
    if (acceptAllDevices != null) {
      data['acceptAllDevices'] = acceptAllDevices;
    }
    return data;
  }
}

class Filter {
  List<String>? services;
  String? name;
  String? namePrefix;

  Filter({this.services, this.name, this.namePrefix});

  Filter.fromJson(Map<String, dynamic> json) {
    services = json['services'].cast<String>();
    name = json['name'];
    namePrefix = json['namePrefix'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (services != null) {
      data['services'] = services;
    }
    if (name != null) {
      data['name'] = name;
    }
    if (namePrefix != null) {
      data['namePrefix'] = namePrefix;
    }
    return data;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
