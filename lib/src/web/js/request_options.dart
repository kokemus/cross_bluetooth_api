import 'dart:js_interop';
import 'dart:typed_data';

import '../../models/request_device_options.dart';

class BluetoothScanFilter {
  final List<String>? services;
  final String? name;
  final String? namePrefix;
  final List<ManufacturerData>? manufacturerData;

  const BluetoothScanFilter({
    this.services,
    this.name,
    this.namePrefix,
    this.manufacturerData,
  });

  factory BluetoothScanFilter.fromMap(Map<String, dynamic> map) {
    return BluetoothScanFilter(
      services: (map['services'] as List<dynamic>?)?.cast<String>(),
      name: map['name'] as String?,
      namePrefix: map['namePrefix'] as String?,
      manufacturerData: (map['manufacturerData'] as List<dynamic>?)
          ?.map(
            (value) => ManufacturerData.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{};
    if (services != null && services!.isNotEmpty) {
      data['services'] = services;
    }
    if (name != null) {
      data['name'] = name;
    }
    if (namePrefix != null) {
      data['namePrefix'] = namePrefix;
    }
    if (manufacturerData != null && manufacturerData!.isNotEmpty) {
      data['manufacturerData'] = manufacturerData!
          .map(
            (value) => <String, dynamic>{
              'companyIdentifier': value.companyIdentifier,
              if (value.dataPrefix != null)
                'dataPrefix': Uint8List.fromList(value.dataPrefix!).toJS,
              if (value.mask != null)
                'mask': Uint8List.fromList(value.mask!).toJS,
            },
          )
          .toList();
    }
    return data;
  }
}

class RequestOptions {
  final List<BluetoothScanFilter> filters;
  final List<String> optionalServices;
  final bool acceptAllDevices;

  const RequestOptions({
    this.filters = const [],
    this.optionalServices = const [],
    this.acceptAllDevices = false,
  });

  factory RequestOptions.fromMap(Map<String, dynamic> map) {
    final filterMaps = map['filters'] as List<dynamic>?;
    return RequestOptions(
      filters:
          filterMaps
              ?.map(
                (f) => BluetoothScanFilter.fromMap(
                  Map<String, dynamic>.from(f as Map),
                ),
              )
              .toList() ??
          const [],
      optionalServices:
          (map['optionalServices'] as List<dynamic>?)?.cast<String>() ??
          const [],
      acceptAllDevices: map['acceptAllDevices'] as bool? ?? false,
    );
  }

  bool get _hasEffectiveFilters {
    return filters.any(
      (f) =>
          (f.services?.isNotEmpty ?? false) ||
          (f.name?.isNotEmpty ?? false) ||
          (f.namePrefix?.isNotEmpty ?? false) ||
          (f.manufacturerData?.isNotEmpty ?? false),
    );
  }

  Map<String, dynamic> toMap() {
    final hasFilters = _hasEffectiveFilters;
    final shouldAcceptAll =
        acceptAllDevices || (!hasFilters && optionalServices.isNotEmpty);

    if (!hasFilters && !shouldAcceptAll) {
      throw ArgumentError(
        'RequestOptions must include at least one non-empty filter or set '
        'acceptAllDevices to true.',
      );
    }

    return <String, dynamic>{
      if (hasFilters)
        'filters': filters
            .map((f) => f.toMap())
            .where((m) => m.isNotEmpty)
            .toList(),
      if (optionalServices.isNotEmpty) 'optionalServices': optionalServices,
      // Web Bluetooth rejects requests that include both filters and acceptAllDevices=true.
      if (!hasFilters) 'acceptAllDevices': shouldAcceptAll,
    };
  }

  JSAny? toJS() => toMap().jsify();
}
