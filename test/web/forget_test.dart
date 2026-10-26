@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cross_bluetooth_api/src/web/cross_bluetooth_api_web.dart';
import 'package:flutter_test/flutter_test.dart';

@JS('navigator')
external JSObject get navigator;

@JS('Object.defineProperty')
external JSObject defineProperty(
  JSObject object,
  JSString name,
  JSObject descriptor,
);

void main() {
  late CrossBluetoothApiWeb plugin;
  late JSObject device;
  var forgetCalls = 0;
  var rejectForget = false;

  setUp(() {
    plugin = CrossBluetoothApiWeb();
    forgetCalls = 0;
    rejectForget = false;
    device = JSObject();
    device['id'] = 'device-42'.toJS;
    device['name'] = 'Sensor'.toJS;
    device['gatt'] = JSObject();
    device['addEventListener'] =
        ((JSString event, JSFunction listener) {}).toJS;
    device['forget'] = (() {
      forgetCalls++;
      return (rejectForget
              ? Future<JSAny?>.error(StateError('Permission revocation failed'))
              : Future<JSAny?>.value(null))
          .toJS;
    }).toJS;
    final bluetooth = JSObject();
    bluetooth['requestDevice'] = ((JSAny? options) => Future.value(
      device,
    ).toJS).toJS;
    final descriptor = JSObject();
    descriptor['value'] = bluetooth;
    descriptor['configurable'] = true.toJS;
    defineProperty(navigator, 'bluetooth'.toJS, descriptor);
  });

  test('forget calls browser API and removes the cached device', () async {
    await plugin.requestDevice({'acceptAllDevices': true});
    await plugin.forget({'id': 'device-42'});
    await expectLater(
      plugin.forget({'id': 'device-42'}),
      throwsA(isA<StateError>()),
    );
    expect(forgetCalls, 1);
  });

  test('failed forget preserves device for retry', () async {
    await plugin.requestDevice({'acceptAllDevices': true});
    rejectForget = true;
    await expectLater(plugin.forget({'id': 'device-42'}), throwsA(anything));
    rejectForget = false;
    await plugin.forget({'id': 'device-42'});
    expect(forgetCalls, 2);
  });

  test('re-requested device can be forgotten again', () async {
    await plugin.requestDevice({'acceptAllDevices': true});
    await plugin.forget({'id': 'device-42'});
    await plugin.requestDevice({'acceptAllDevices': true});
    await plugin.forget({'id': 'device-42'});
    expect(forgetCalls, 2);
  });

  test('forget revokes access once for repeated requests', () async {
    await plugin.requestDevice({'acceptAllDevices': true});
    await plugin.requestDevice({'acceptAllDevices': true});
    await plugin.forget({'id': 'device-42'});
    expect(forgetCalls, 1);
  });

  test('forget rejects invalid identifiers', () async {
    for (final id in [null, 123]) {
      await expectLater(plugin.forget({'id': id}), throwsA(isA<TypeError>()));
    }
    await expectLater(plugin.forget({'id': ''}), throwsA(isA<StateError>()));
  });
}
