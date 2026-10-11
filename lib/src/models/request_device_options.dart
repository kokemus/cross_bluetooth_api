class RequestDeviceOptions {
  List<Filter>? filters;
  List<String>? optionalServices;
  bool? acceptAllDevices;

  RequestDeviceOptions({
    this.filters,
    this.optionalServices,
    this.acceptAllDevices,
  });

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
  ProductData? productData;
  List<ManufacturerData>? manufacturerData;

  Filter({
    this.services,
    this.name,
    this.namePrefix,
    this.productData,
    this.manufacturerData,
  });

  Filter.fromJson(Map<String, dynamic> json) {
    services = json['services']?.cast<String>();
    name = json['name'];
    namePrefix = json['namePrefix'];
    manufacturerData = (json['manufacturerData'] as List<dynamic>?)
        ?.map(
          (value) => ManufacturerData.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
    if (json['productData'] != null) {
      productData = ProductData.fromJson(
        Map<String, dynamic>.from(json['productData']),
      );
    }
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
    if (manufacturerData != null) {
      data['manufacturerData'] = manufacturerData!
          .map((value) => value.toJson())
          .toList();
    }
    if (productData != null) {
      data['productData'] = productData!.toJson();
    }
    return data;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class ManufacturerData {
  int companyIdentifier;
  List<int>? dataPrefix;
  List<int>? mask;

  ManufacturerData({
    required this.companyIdentifier,
    this.dataPrefix,
    this.mask,
  });

  ManufacturerData.fromJson(Map<String, dynamic> json)
    : companyIdentifier = json['companyIdentifier'] as int,
      dataPrefix = (json['dataPrefix'] as List<dynamic>?)?.cast<int>(),
      mask = (json['mask'] as List<dynamic>?)?.cast<int>();

  Map<String, dynamic> toJson() {
    return {
      'companyIdentifier': companyIdentifier,
      if (dataPrefix != null) 'dataPrefix': dataPrefix,
      if (mask != null) 'mask': mask,
    };
  }
}

class ProductData {
  String name;
  String image;

  ProductData({required this.name, required this.image});

  ProductData.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      image = json['image'] as String;

  Map<String, dynamic> toJson() {
    return {'name': name, 'image': image};
  }
}
