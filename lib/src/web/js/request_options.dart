import 'package:js/js.dart';

@JS()
@anonymous
class BluetoothScanFilter {
  external List<String>? get services;
  external String? get name;
  external String? get namePrefix;
  external factory BluetoothScanFilter(
      {List<String>? services, String? name, String? namePrefix});
}

@JS()
@anonymous
class RequestOptions {
  external List<BluetoothScanFilter> get filters;
  external List<String> get optionalServices;
  external bool get acceptAllDevices;
  external factory RequestOptions(
      {List<BluetoothScanFilter> filters,
      List<dynamic> optionalServices,
      bool acceptAllDevices});
}
