import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

void main() {
  const MethodChannel channel = MethodChannel('cross_bluetooth_api');
  TestWidgetsFlutterBinding.ensureInitialized();
  final binaryMessenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    binaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall methodCall,
    ) async {
      return {'id': 'device-42', 'name': 'Test Device'};
    });
  });

  tearDown(() {
    binaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getDevices sends no arguments and parses all devices', () async {
    binaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDevices');
      expect(call.arguments, isNull);
      return [
        {'id': 'device-42', 'name': 'Sensor'},
        {'id': 'device-43', 'name': null},
      ];
    });

    final devices = await Bluetooth.getDevices();

    expect(devices.map((device) => device.id), ['device-42', 'device-43']);
    expect(devices.map((device) => device.name), ['Sensor', null]);
    expect(devices.first.gatt.device, same(devices.first));
  });

  test(
    'getDevices returns an empty list when no devices are available',
    () async {
      binaryMessenger.setMockMethodCallHandler(channel, (_) async => []);
      expect(await Bluetooth.getDevices(), isEmpty);
    },
  );

  test('getDevices maps platform errors', () async {
    for (final error in [
      SecurityError(),
      NotSupportedError(),
      InvalidStateError(),
      UnknownError('failed'),
    ]) {
      binaryMessenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: error.runtimeType.toString(),
          message: error.toString(),
        );
      });
      await expectLater(
        Bluetooth.getDevices(),
        throwsA(predicate((value) => value.runtimeType == error.runtimeType)),
      );
    }
  });

  test('requestDevice sends product data to the platform', () async {
    binaryMessenger.setMockMethodCallHandler(channel, (methodCall) async {
      expect(methodCall.arguments['filters'], [
        {
          'services': ['180A'],
          'productData': {'name': 'Sensor', 'image': 'assets/sensor.png'},
        },
      ]);
      return {'id': 'device-42', 'name': 'Sensor'};
    });

    await Bluetooth.requestDevice(
      RequestDeviceOptions(
        filters: [
          Filter(
            services: ['180A'],
            productData: ProductData(
              name: 'Sensor',
              image: 'assets/sensor.png',
            ),
          ),
        ],
      ),
    );
  });

  test('requestDevice returns parsed device', () async {
    final device = await Bluetooth.requestDevice(
      RequestDeviceOptions(acceptAllDevices: true),
    );

    expect(device.id, 'device-42');
    expect(device.name, 'Test Device');
  });

  test('requestDevice maps platform errors', () async {
    binaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall methodCall,
    ) async {
      throw PlatformException(
        code: '1',
        message: 'NotFoundError: no device found',
      );
    });

    expect(
      () =>
          Bluetooth.requestDevice(RequestDeviceOptions(acceptAllDevices: true)),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('forget sends the device without changing connected state', () async {
    final device = Device.fromJson({'id': 'device-42', 'name': 'Sensor'});
    device.gatt.connected = true;
    binaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'forget');
      expect(call.arguments, {'id': 'device-42', 'name': 'Sensor'});
      expect(device.gatt.connected, isTrue);
      return null;
    });

    await device.forget();

    expect(device.gatt.connected, isTrue);
    expect(device.id, 'device-42');
  });

  test('forget propagates failure without changing connected state', () async {
    final device = Device.fromJson({'id': 'device-42'});
    device.gatt.connected = true;
    binaryMessenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'NetworkError',
        message: 'NetworkError: Unable to forget device.',
      );
    });

    await expectLater(device.forget(), throwsA(isA<NetworkError>()));
    expect(device.gatt.connected, isTrue);
  });

  test('forget may be called repeatedly', () async {
    final device = Device.fromJson({'id': 'device-42'});
    var calls = 0;
    binaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'forget');
      calls++;
      return null;
    });

    await device.forget();
    await device.forget();
    expect(calls, 2);
  });
}
