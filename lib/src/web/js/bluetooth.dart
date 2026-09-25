import 'dart:js_interop';

import 'request_options.dart';

@JS('navigator.bluetooth')
external NativeBluetooth get nativeBluetooth;

@JS()
@staticInterop
class NativeBluetooth {}

extension NativeBluetoothInterop on NativeBluetooth {
  external JSAny? getAvailability();
  external JSAny? getDevices();
  external JSPromise<JSObject> requestDevice(JSAny? options);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension NativeBluetoothApi on NativeBluetooth {
  JSPromise<JSObject> requestTypedDevice(RequestOptions options) {
    return requestDevice(options.toJS());
  }
}
