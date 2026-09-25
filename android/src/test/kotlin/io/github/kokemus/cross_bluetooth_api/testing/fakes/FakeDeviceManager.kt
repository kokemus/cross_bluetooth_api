package io.github.kokemus.cross_bluetooth_api.testing.fakes

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import io.github.kokemus.cross_bluetooth_api.services.DeviceManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManagerListener

class FakeDeviceManager(
    override val deviceId: String
) : DeviceManager {
    private val listeners = linkedSetOf<DeviceManagerListener>()

    override fun addListener(delegate: DeviceManagerListener) {
        listeners.add(delegate)
    }

    override fun removeListener(delegate: DeviceManagerListener) {
        listeners.remove(delegate)
    }

    override fun getService(serviceUUID: String): BluetoothGattService? = null

    override fun getCharacteristic(
        serviceUUID: String,
        characteristicUUID: String
    ): BluetoothGattCharacteristic? = null

    override fun disconnect() = Unit

    override fun readCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean = false

    override fun setCharacteristicNotification(
        characteristic: BluetoothGattCharacteristic,
        bool: Boolean
    ): Boolean = false

    override fun writeDescriptor(descriptor: BluetoothGattDescriptor): Boolean = false

    override fun writeCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean = false

    fun emitServicesDiscovered(status: Int) {
        listeners.toList().forEach { it.onServicesDiscovered(this, status) }
    }

    fun hasListener(listener: DeviceManagerListener): Boolean {
        return listeners.contains(listener)
    }
}
