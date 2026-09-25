import 'package:cross_bluetooth_api_example/device_view.dart';
import 'package:cross_bluetooth_api_example/scan_view.dart';
import 'package:flutter/material.dart';

import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  final ValueNotifier<Device?> _device = ValueNotifier<Device?>(null);
  final ValueNotifier<List<String>> _services = ValueNotifier<List<String>>([]);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Cross Bluetooth API')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: ValueListenableBuilder(
              valueListenable: _device,
              builder: (context, device, child) {
                return device == null
                    ? ScanView(selectedDevice: _device, services: _services)
                    : DeviceView(device: _device, services: _services);
              },
            ),
          ),
        ),
      ),
    );
  }
}
