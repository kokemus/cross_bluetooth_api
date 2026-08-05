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
