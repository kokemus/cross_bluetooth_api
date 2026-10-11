# Cross Bluetooth API

The Cross Bluetooth API provides the ability to connect and interact with Bluetooth Low Energy peripherals.

Implementation follows [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)

## Usage

```
dependencies:
  cross_bluetooth_api:
    git:
      url: https://github.com/kokemus/cross_bluetooth_api.git

```
### Android

> minSdkVersion 26

### iOS

> The app's Info.plist must contain an NSBluetoothAlwaysUsageDescription key with a string value explaining to the user how the app uses this data.

The plugin uses AccessorySetupKit for `Bluetooth.requestDevice` on iOS 18 and newer when at least one filter contains `productData`. ProductData is used to configure the AccessorySetupKit picker.

Requests without product data and requests on older iOS versions, use the custom picker.

For example to discover the Environmental Sensing service:

```xml
<key>NSAccessorySetupKitSupports</key>
<array>
    <string>Bluetooth</string>
</array>
<key>NSAccessorySetupBluetoothServices</key>
<array>
    <string>0x181A-0000-1000-8000-00805F9B34FB</string>
</array>
```

```dart
final device = await Bluetooth.requestDevice(
    RequestDeviceOptions(
        filters: [
            Filter(
                services: ['0000181a-0000-1000-8000-00805f9b34fb'],
                productData: ProductData(name: 'Tag', image: 'images/tag.png'),
            )
        ]
    ),
);
```

### Example

``` dart
import 'package:cross_bluetooth_api/cross_bluetooth_api.dart';

try {
    final device = await Bluetooth.requestDevice(
        RequestDeviceOptions(
            optionalServices: ['0000180a-0000-1000-8000-00805f9b34fb'],
            acceptAllDevices: true
        )
    );
    final server = await device.gatt.connect();
    final service = await server.getPrimaryService('0000180a-0000-1000-8000-00805f9b34fb');
    final characteristic = await service.getCharacteristic('00002a24-0000-1000-8000-00805f9b34fb');
    final value = await characteristic.readValue();
} on NotFoundError catch (e) {
    print(e);
} on TypeError catch (e) {
    print(e);
} on NetworkError catch (e) {
    print(e);
} on SecurityError catch (e) {
    print(e);
} on UnknownError catch (e) {
    print(e);
} catch (e) {
    print(e);
}
```

## Support

| Bluetooth  |  Android | iOS  | Chrome |
|---|:---:|:---:|:---:|
| getAvailability |   |   |   |
| getDevices |   |   |   |
| requestDevice | x | x | x |

</br>

| BluetoothDevice  |  Android | iOS  | Chrome |
|---|:---:|:---:|:---:|
| gatt | x | x | x |
| gattserverdisconnected | x | x | x |
| id | x | x | x |
| name | x | x | x |
| watchAdvertisements |   |   |   |
| forget |   |   |   |

</br>

| BluetoothRemoteGATTServer  |  Android | iOS  | Chrome |
|---|:---:|:---:|:---:|
| connect | x | x | x |
| connected | x | x | x |
| device | x | x | x |
| disconnect | x | x | x |
| getPrimaryService | x | x | x |
| getPrimaryServices |   |   |   |

</br>

| BluetoothRemoteGATTService  |  Android | iOS  | Chrome |
|---|:---:|:---:|:---:|
| device | x | x | x |
| isPrimary | x | x | x |
| uuid | x | x | x |
| getCharacteristic | x | x | x |
| getCharacteristics |   |   |   |

</br>

| BluetoothRemoteGATTCharacteristic  |  Android | iOS  | Chrome |
|---|:---:|:---:|:---:|
| service | x | x | x |
| uuid | x | x | x |
| properties |  |   |  |
| value | x | x | x |
| characteristicvaluechanged | x  | x | x |
| getDescriptor |   |   |   |
| getDescriptors |   |   |   |
| readValue | x | x | x |
| writeValueWithResponse | x | x | x |
| writeValueWithoutResponse | x | x | x |
| startNotifications | x | x | x |
| stopNotifications | x | x | x |