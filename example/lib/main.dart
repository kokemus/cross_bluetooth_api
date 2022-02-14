import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

extension on ByteData {
  String getString() {
    return utf8.decode(buffer.asUint8List(offsetInBytes, lengthInBytes));
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _state;
  Device? _device;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Cross Bluetooth API'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _state ?? '',
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                  onPressed: () async {
                    try {
                      setState(() {
                        _state = '';
                      });
                      if (!(_device?.gatt.connected ?? false)) {
                        _device = await Bluetooth.requestDevice(
                            RequestDeviceOptions(
                                optionalServices: ['device_information'],
                                acceptAllDevices: true));
                        setState(() {
                          _state = _device.toString();
                        });
                        final server = await _device!.gatt.connect();
                        setState(() {
                          _state = server.toString();
                        });
                        final service = await server
                            .getPrimaryService('device_information');
                        final characteristic = await service
                            .getCharacteristic('model_number_string');
                        final value = await characteristic.readValue();
                        setState(() {
                          _state = value.getString();
                        });
                      } else {
                        await _device?.gatt.disconnect();
                        setState(() {
                          _state = _device?.gatt.toString();
                        });
                      }
                    } on NotFoundError catch (e) {
                      setState(() {
                        _state = e.message;
                      });
                    } on TypeError catch (e) {
                      setState(() {
                        _state = e.message;
                      });
                    } on NetworkError catch (e) {
                      setState(() {
                        _state = e.message;
                      });
                    } on SecurityError catch (e) {
                      setState(() {
                        _state = e.message;
                      });
                    } catch (e) {
                      _state = e.toString();
                    }
                  },
                  child: Text(!(_device?.gatt.connected ?? false)
                      ? 'Scan'
                      : 'Disconnect')),
            ],
          ),
        ),
      ),
    );
  }
}
