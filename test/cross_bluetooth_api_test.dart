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

  test('Filter round-trips product data without services', () {
    final filter = Filter(
      namePrefix: 'Sensor',
      productData: ProductData(name: 'Sensor', image: 'assets/sensor.png'),
    );
    final json = filter.toJson();

    expect(json, {
      'namePrefix': 'Sensor',
      'productData': {'name': 'Sensor', 'image': 'assets/sensor.png'},
    });

    final decoded = Filter.fromJson(json);
    expect(decoded.services, isNull);
    expect(decoded.namePrefix, 'Sensor');
    expect(decoded.productData?.name, 'Sensor');
    expect(decoded.productData?.image, 'assets/sensor.png');
    expect(decoded.toJson(), json);
  });

  test('Filter omits absent product data', () {
    final filter = Filter(services: ['180A']);
    expect(filter.toJson(), {
      'services': ['180A'],
    });
    expect(Filter.fromJson(filter.toJson()).productData, isNull);
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
}
