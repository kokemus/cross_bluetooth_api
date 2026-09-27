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
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: _device,
                    builder: (context, device, child) {
                      return device == null
                          ? ScanView(
                              selectedDevice: _device,
                              services: _services,
                            )
                          : DeviceView(device: _device, services: _services);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
