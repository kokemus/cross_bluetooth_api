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
  bool _loading = false;

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
              StreamBuilder<Device>(
                  stream: _device?.gattserverdisconnected,
                  builder: (context, state) {
                    print(state);
                    return Text(state.hasData ? 'Disconnected' : '');
                  }),
              SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _state ?? '',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              OutlinedButton(
                  onPressed: () async {
                    try {
                      _loading = true;
                      if (!(_device?.gatt.connected ?? false)) {
                        await _connectAndRead();
                      } else {
                        await _disconnect();
                      }
                      _loading = false;
                    } on UnknownError catch (e) {
                      _loading = false;
                      setState(() {
                        _state = e.message;
                      });
                    }
                  },
                  child: !_loading
                      ? Text(!(_device?.gatt.connected ?? false)
                          ? 'Scan'
                          : 'Disconnect')
                      : const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          )))
            ],
          ),
        ),
      ),
    );
  }

  Future _connectAndRead() async {
    setState(() {
      _state = '';
    });
    _device = await Bluetooth.requestDevice(RequestDeviceOptions(
        acceptAllDevices: true,
        optionalServices: ['0000180a-0000-1000-8000-00805f9b34fb']));
    setState(() {
      _state = _device.toString();
    });
    final server = await _device!.gatt.connect();
    setState(() {
      _state = server.toString();
    });
    final service =
        await server.getPrimaryService('0000180a-0000-1000-8000-00805f9b34fb');
    setState(() {
      _state = service.uuid;
    });
    final characteristic =
        await service.getCharacteristic('00002a24-0000-1000-8000-00805f9b34fb');
    final value = await characteristic.readValue();
    setState(() {
      _state = value.getString();
    });
  }

  Future _disconnect() async {
    setState(() {
      _state = '';
    });
    await _device?.gatt.disconnect();
    setState(() {
      _state = '';
    });
  }
}
