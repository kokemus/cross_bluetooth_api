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
    val services = mutableListOf<BluetoothGattService>()
    var readReturnValue = false
    var writeReturnValue = false
    var notificationReturnValue = false
    var descriptorReturnValue = false
    val operations = mutableListOf<String>()
    var readCharacteristic: BluetoothGattCharacteristic? = null
        private set
    var writtenCharacteristic: BluetoothGattCharacteristic? = null
        private set
    var writtenValue: ByteArray? = null
        private set
    var writtenType: Int? = null
        private set
    var notificationCharacteristic: BluetoothGattCharacteristic? = null
        private set
    var notificationEnabled: Boolean? = null
        private set
    var writtenDescriptor: BluetoothGattDescriptor? = null
        private set
    var descriptorValue: ByteArray? = null
        private set

    override fun addListener(delegate: DeviceManagerListener) {
        listeners.add(delegate)
    }

    override fun removeListener(delegate: DeviceManagerListener) {
        listeners.remove(delegate)
    }

    override fun getService(serviceUUID: String): BluetoothGattService? =
        services.find { it.uuid.toString() == serviceUUID }

    override fun getCharacteristic(
        serviceUUID: String,
        characteristicUUID: String
    ): BluetoothGattCharacteristic? = getService(serviceUUID)?.characteristics
        ?.find { it.uuid.toString() == characteristicUUID }

    override fun disconnect() = Unit

    override fun readCharacteristic(characteristic: BluetoothGattCharacteristic): Boolean {
        operations.add("read")
        readCharacteristic = characteristic
        return readReturnValue
    }

    override fun setCharacteristicNotification(
        characteristic: BluetoothGattCharacteristic,
        bool: Boolean
    ): Boolean {
        operations.add("notification")
        notificationCharacteristic = characteristic
        notificationEnabled = bool
        return notificationReturnValue
    }

    override fun writeDescriptor(descriptor: BluetoothGattDescriptor, value: ByteArray): Boolean {
        operations.add("descriptor")
        writtenDescriptor = descriptor
        descriptorValue = value
        return descriptorReturnValue
    }

    override fun writeCharacteristic(
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        writeType: Int
    ): Boolean {
        operations.add("write")
        writtenCharacteristic = characteristic
        writtenValue = value
        writtenType = writeType
        return writeReturnValue
    }

    @Suppress("unused") // Used by ReadValueCommandTest.
    fun emitCharacteristicRead(characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
        listeners.toList().forEach { it.onCharacteristicRead(this, characteristic, value, status) }
    }

    @Suppress("unused") // Used by both write command test suites.
    fun emitCharacteristicWrite(characteristic: BluetoothGattCharacteristic, status: Int) {
        listeners.toList().forEach { it.onCharacteristicWrite(this, characteristic, status) }
    }

    @Suppress("unused") // Used by the notification command test suites.
    fun emitDescriptorWrite(descriptor: BluetoothGattDescriptor, status: Int) {
        listeners.toList().forEach { it.onDescriptorWrite(this, descriptor, status) }
    }

    fun emitServicesDiscovered(status: Int) {
        listeners.toList().forEach { it.onServicesDiscovered(this, status) }
    }

    fun hasListener(listener: DeviceManagerListener): Boolean {
        return listeners.contains(listener)
    }
}
