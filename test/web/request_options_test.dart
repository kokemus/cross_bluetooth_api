@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';
import 'package:cross_bluetooth_api/src/web/js/request_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Manufacturer-only filters reach JS with byte buffers', () {
    final options = RequestOptions.fromMap(
      RequestDeviceOptions(
        filters: [
          Filter(
            manufacturerData: [
              ManufacturerData(
                companyIdentifier: 12,
                dataPrefix: [1, 2],
                mask: [255, 240],
              ),
              ManufacturerData(companyIdentifier: 76),
            ],
          ),
        ],
      ).toJson(),
    );

    final jsOptions = options.toJS() as JSObject;
    expect(jsOptions.has('acceptAllDevices'), isFalse);
    final filters = jsOptions['filters'] as JSArray<JSObject>;
    final data = filters.toDart.single['manufacturerData'] as JSArray<JSObject>;
    final first = data.toDart.first;
    expect((first['companyIdentifier'] as JSNumber).toDartInt, 12);
    expect(first['dataPrefix'].isA<JSUint8Array>(), isTrue);
    expect(first['mask'].isA<JSUint8Array>(), isTrue);
    expect((first['dataPrefix'] as JSUint8Array).toDart, [1, 2]);
    expect((first['mask'] as JSUint8Array).toDart, [255, 240]);
    expect(data.toDart.last.has('dataPrefix'), isFalse);
    expect(data.toDart.last.has('mask'), isFalse);
  });

  test('Empty manufacturer data does not count as an effective filter', () {
    final options = RequestOptions.fromMap(
      RequestDeviceOptions(filters: [Filter(manufacturerData: [])]).toJson(),
    );
    expect(options.toMap, throwsArgumentError);
  });
}
