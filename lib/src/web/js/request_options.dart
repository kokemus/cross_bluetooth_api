import 'dart:js_interop';

class BluetoothScanFilter {
  final List<String>? services;
  final String? name;
  final String? namePrefix;

  const BluetoothScanFilter({this.services, this.name, this.namePrefix});

  factory BluetoothScanFilter.fromMap(Map<String, dynamic> map) {
    return BluetoothScanFilter(
      services: (map['services'] as List<dynamic>?)?.cast<String>(),
      name: map['name'] as String?,
      namePrefix: map['namePrefix'] as String?,
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
      filters: filterMaps
              ?.map((f) => BluetoothScanFilter.fromMap(
                    Map<String, dynamic>.from(f as Map),
                  ))
              .toList() ??
          const [],
      optionalServices:
          (map['optionalServices'] as List<dynamic>?)?.cast<String>() ??
              const [],
      acceptAllDevices: map['acceptAllDevices'] as bool? ?? false,
    );
  }

  bool get _hasEffectiveFilters {
    return filters.any((f) =>
        (f.services?.isNotEmpty ?? false) ||
        (f.name?.isNotEmpty ?? false) ||
        (f.namePrefix?.isNotEmpty ?? false));
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
        'filters':
            filters.map((f) => f.toMap()).where((m) => m.isNotEmpty).toList(),
      if (optionalServices.isNotEmpty) 'optionalServices': optionalServices,
      // Web Bluetooth rejects requests that include both filters and acceptAllDevices=true.
      if (!hasFilters) 'acceptAllDevices': shouldAcceptAll,
    };
  }

  JSAny? toJS() => toMap().jsify();
}
