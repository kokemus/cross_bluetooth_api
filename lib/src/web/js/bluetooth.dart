import 'package:js/js.dart';
import 'request_options.dart';

@JS('navigator.bluetooth')
class NativeBluetooth {
  external static Object getAvailability();
  external static Object getDevices();
  external static Object requestDevice(RequestOptions? options);
  external static void addEventListener(
      String type, void Function(dynamic) listener);
  external static void removeEventListener(
      String type, void Function(dynamic) listener);
}
