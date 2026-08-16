package io.github.kokemus.cross_bluetooth_api.services

import android.Manifest
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import androidx.annotation.RequiresPermission
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

interface DeviceManager {
    val deviceId: String
    fun addListener(delegate: DeviceManagerListener)
    fun removeListener(delegate: DeviceManagerListener)
    fun getService(serviceUUID: String): BluetoothGattService?
    fun getCharacteristic(serviceUUID: String, characteristicUUID: String): BluetoothGattCharacteristic?
    fun disconnect()
    fun readCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean
    fun setCharacteristicNotification(
        characteristic: BluetoothGattCharacteristic,
        bool: Boolean
    ): Boolean

    fun writeDescriptor(descriptor: BluetoothGattDescriptor): Boolean
    fun writeCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean
}

class DeviceManagerImp(private val gatt: BluetoothGatt) : DeviceManager {
    private val listeners = mutableSetOf<DeviceManagerListener>()

    override val deviceId: String
        get() = gatt.device.address

    override fun addListener(delegate: DeviceManagerListener) {
        listeners.add(delegate)
    }

    override fun removeListener(delegate: DeviceManagerListener) {
        listeners.remove(delegate)
    }

    override fun getService(serviceUUID: String): BluetoothGattService? {
        return gatt.getService(UUID.fromString(serviceUUID))
    }

    override fun getCharacteristic(serviceUUID: String, characteristicUUID: String): BluetoothGattCharacteristic? {
        return getService(serviceUUID)?.getCharacteristic(UUID.fromString(characteristicUUID))
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun disconnect() {
        gatt.disconnect()
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun readCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean {
        return gatt.readCharacteristic(characteristic)
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun setCharacteristicNotification(
        characteristic: BluetoothGattCharacteristic,
        bool: Boolean
    ): Boolean {
        return gatt.setCharacteristicNotification(characteristic, bool)
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun writeDescriptor(descriptor: BluetoothGattDescriptor): Boolean {
        return gatt.writeDescriptor(descriptor)
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun writeCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean {
        return gatt.writeCharacteristic(characteristic)
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
