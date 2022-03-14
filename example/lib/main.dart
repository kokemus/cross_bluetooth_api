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
                                acceptAllDevices: true,
                                optionalServices: [
                              '0000180a-0000-1000-8000-00805f9b34fb'
                            ]));
                        setState(() {
                          _state = _device.toString();
                        });
                        final server = await _device!.gatt.connect();
                        setState(() {
                          _state = server.toString();
                        });
                        final service = await server.getPrimaryService(
                            '0000180a-0000-1000-8000-00805f9b34fb');
                        setState(() {
                          _state = service.uuid;
                        });
                        final characteristic = await service.getCharacteristic(
                            '00002a24-0000-1000-8000-00805f9b34fb');
                        final value = await characteristic.readValue();
                        setState(() {
                          _state = value.getString();
                        });
                      } else {
                        await _device?.gatt.disconnect();
                        setState(() {
                          _state = '';
                        });
                      }
                    } on UnknownError catch (e) {
                      setState(() {
                        _state = e.message;
                      });
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
