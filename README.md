# Cross Bluetooth API

The Cross Bluetooth API provides the ability to connect and interact with Bluetooth Low Energy peripherals.

Implementation follows [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)

## Usage

```
dependencies:
  cross_bluetooth_api:
    git:
      url: git://github.com/kokemus/cross_bluetooth_api.git

```

### Example

``` dart
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

try {
    final device = await Bluetooth.requestDevice(
        RequestDeviceOptions(
            optionalServices: ['device_information'],
            acceptAllDevices: true
        )
    );
    final server = await device!.gatt.connect();
    final service = await server.getPrimaryService('device_information');
    final characteristic = await service.getCharacteristic('model_number_string');
    final value = await characteristic.readValue();
} on NotFoundError catch (e) {
    print(e);
} on TypeError catch (e) {
    print(e);
} on NetworkError catch (e) {
    print(e);
} on SecurityError catch (e) {
    print(e);
} catch (e) {
    print(e);
}
```

## Supports

* Android
* iOS
* Google Chrome