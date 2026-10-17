package io.github.kokemus.cross_bluetooth_api.testing

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeBluetoothManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeDeviceManager
import java.util.UUID

class GattFixture(
    properties: Int = BluetoothGattCharacteristic.PROPERTY_NOTIFY,
    serviceId: String = "0000180f-0000-1000-8000-00805f9b34fb",
    characteristicId: String = "00002a19-0000-1000-8000-00805f9b34fb",
    serviceType: Int = BluetoothGattService.SERVICE_TYPE_PRIMARY,
    descriptorId: String = "00002902-0000-1000-8000-00805f9b34fb"
) {
    val service = BluetoothGattService(UUID.fromString(serviceId), serviceType)
    val characteristic = BluetoothGattCharacteristic(
        UUID.fromString(characteristicId), properties,
        BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
    )
    val descriptor = BluetoothGattDescriptor(UUID.fromString(descriptorId), BluetoothGattDescriptor.PERMISSION_WRITE)
    val device = FakeDeviceManager("AA:BB:CC:DD:EE:FF").apply {
        services.add(service)
        readReturnValue = true
        writeReturnValue = true
        notificationReturnValue = true
        descriptorReturnValue = true
    }
    val manager = FakeBluetoothManager().apply { devices[device.deviceId] = device }
    val arguments: Map<String, Any> = mapOf(
        "deviceId" to device.deviceId,
        "serviceUUID" to serviceId,
        "characteristic" to characteristicId
    )

    init {
        service.addCharacteristic(characteristic)
        characteristic.addDescriptor(descriptor)
    }
}
