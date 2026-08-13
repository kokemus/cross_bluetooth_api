package io.github.kokemus.cross_bluetooth_api.services

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import java.util.UUID

interface DeviceManagerListener {
    fun onServicesDiscovered(deviceManager: DeviceManager, status: Int) {}

    fun onCharacteristicRead(
        deviceManager: DeviceManager,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        status: Int
    ) {
    }

    fun onCharacteristicWrite(
        deviceManager: DeviceManager,
        characteristic: BluetoothGattCharacteristic,
        status: Int
    ) {
    }

    fun onDescriptorWrite(
        deviceManager: DeviceManager,
        descriptor: BluetoothGattDescriptor,
        status: Int
    ) {
    }

    fun onCharacteristicChanged(
        deviceManager: DeviceManager,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ) {
    }
}

class DeviceManager(internal val gatt: BluetoothGatt) {
    private val listeners = mutableSetOf<DeviceManagerListener>()

    val deviceId: String
        get() = gatt.device.address

    fun addListener(delegate: DeviceManagerListener) {
        listeners.add(delegate)
    }

    fun removeListener(delegate: DeviceManagerListener) {
        listeners.remove(delegate)
    }

    fun removeAllListeners() {
        listeners.clear()
    }

    fun getService(serviceUUID: String): BluetoothGattService? {
        return gatt.getService(UUID.fromString(serviceUUID))
    }

    fun getCharacteristic(serviceUUID: String, characteristicUUID: String): BluetoothGattCharacteristic? {
        return getService(serviceUUID)?.getCharacteristic(UUID.fromString(characteristicUUID))
    }

    internal fun notifyServicesDiscovered(status: Int) {
        listeners.toList().forEach { it.onServicesDiscovered(this, status) }
    }

    internal fun notifyCharacteristicRead(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        status: Int
    ) {
        listeners.toList().forEach {
            it.onCharacteristicRead(this, characteristic, value, status)
        }
    }

    internal fun notifyCharacteristicWrite(
        characteristic: BluetoothGattCharacteristic,
        status: Int
    ) {
        listeners.toList().forEach {
            it.onCharacteristicWrite(this, characteristic, status)
        }
    }

    internal fun notifyDescriptorWrite(
        descriptor: BluetoothGattDescriptor,
        status: Int
    ) {
        listeners.toList().forEach {
            it.onDescriptorWrite(this, descriptor, status)
        }
    }

    internal fun notifyCharacteristicChanged(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray
    ) {
        listeners.toList().forEach {
            it.onCharacteristicChanged(this, characteristic, value)
        }
    }
}
