@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cross_bluetooth_api/src/web/cross_bluetooth_api_web.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart' as api;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late CrossBluetoothApiWeb plugin;
  late JSObject device;
  var forgetCalls = 0;
  var rejectForget = false;
  var getDevicesCalls = 0;
  var disconnectCalls = 0;
  var listenerCalls = 0;
  var rejectGetDevices = false;
  late List<JSObject> authorizedDevices;

  setUp(() {
    plugin = CrossBluetoothApiWeb();
    forgetCalls = 0;
    rejectForget = false;
    getDevicesCalls = 0;
    disconnectCalls = 0;
    listenerCalls = 0;
    rejectGetDevices = false;
    device = JSObject();
    device['id'] = 'device-42'.toJS;
    device['name'] = 'Sensor'.toJS;
    final gatt = JSObject();
    gatt['disconnect'] = (() {
      disconnectCalls++;
    }).toJS;
    device['gatt'] = gatt;
    authorizedDevices = [device];
    device['addEventListener'] = ((JSString event, JSFunction listener) {
      listenerCalls++;
    }).toJS;
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
    bluetooth['getDevices'] = (() {
      getDevicesCalls++;
      return (rejectGetDevices
              ? Future<JSArray<JSObject>>.error(StateError('Access denied'))
              : Future.value(authorizedDevices.toJS))
          .toJS;
    }).toJS;
    final descriptor = JSObject();
    descriptor['value'] = bluetooth;
    descriptor['configurable'] = true.toJS;
    defineProperty(navigator, 'bluetooth'.toJS, descriptor);
  });

  test('getDevices delegates to browser and caches devices for GATT', () async {
    final devices = await plugin.getDevices();
    expect(devices, [
      {'id': 'device-42', 'name': 'Sensor'},
    ]);
    expect(getDevicesCalls, 1);
    await plugin.disconnect({'id': 'device-42'});
    expect(disconnectCalls, 1);
    await plugin.forget({'id': 'device-42'});
    expect(forgetCalls, 1);
  });

  test('getDevices works through the public method channel', () async {
    final registrar = Registrar();
    CrossBluetoothApiWeb.registerWith(registrar);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('cross_bluetooth_api', (message) {
      final response = Completer<ByteData?>();
      registrar.handleFrameworkMessage(
        'cross_bluetooth_api',
        message,
        response.complete,
      );
      return response.future;
    });
    addTearDown(() {
      messenger.setMockMessageHandler('cross_bluetooth_api', null);
    });
    final devices = await api.Bluetooth.getDevices();
    expect(devices.single.id, 'device-42');
    expect(getDevicesCalls, 1);
  });

  test('getDevices returns every device, including unnamed devices', () async {
    final unnamed = JSObject();
    unnamed['id'] = 'device-43'.toJS;
    unnamed['gatt'] = JSObject();
    unnamed['addEventListener'] =
        ((JSString event, JSFunction listener) {}).toJS;
    authorizedDevices.add(unnamed);
    expect(await plugin.getDevices(), [
      {'id': 'device-42', 'name': 'Sensor'},
      {'id': 'device-43', 'name': null},
    ]);
  });

  test(
    'getDevices returns empty results and propagates browser failures',
    () async {
      authorizedDevices.clear();
      expect(await plugin.getDevices(), isEmpty);
      rejectGetDevices = true;
      await expectLater(plugin.getDevices(), throwsA(anything));
    },
  );

  test('repeated getDevices and requests do not duplicate listeners', () async {
    await plugin.getDevices();
    await plugin.getDevices();
    await plugin.requestDevice({'acceptAllDevices': true});
    expect(listenerCalls, 1);
    await plugin.forget({'id': 'device-42'});
    await expectLater(
      plugin.disconnect({'id': 'device-42'}),
      throwsA(isA<StateError>()),
    );
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
