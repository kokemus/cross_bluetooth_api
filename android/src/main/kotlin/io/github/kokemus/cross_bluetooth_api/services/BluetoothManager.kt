package io.github.kokemus.cross_bluetooth_api.services

import android.Manifest
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.content.Context
import androidx.annotation.RequiresPermission

interface BluetoothManagerListener {
    fun onConnected(deviceManager: DeviceManager) {}
    fun onConnectFailed(deviceId: String) {}
    fun onDisconnected(deviceId: String) {}
}

class BluetoothManager(context: Context) {
    private val manager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager

    private val deviceManagersById = mutableMapOf<String, DeviceManager>()
    private val listeners = mutableSetOf<BluetoothManagerListener>()

    fun addListener(delegate: BluetoothManagerListener) {
        listeners.add(delegate)
    }

    fun removeListener(delegate: BluetoothManagerListener) {
        listeners.remove(delegate)
    }

    fun removeAllListeners() {
        listeners.clear()
    }

    fun deviceManager(deviceId: String): DeviceManager? {
        return deviceManagersById[deviceId]
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    fun retrieveDeviceManager(deviceId: String): DeviceManager? {
        return deviceManagersById[deviceId]
            ?: deviceManagersById[manager.adapter.getRemoteDevice(deviceId).address]
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    fun connect(context: Context, deviceId: String): Boolean {
        val bluetoothDevice = manager.adapter.getRemoteDevice(deviceId)
        val gatt = bluetoothDevice.connectGatt(context, false, callback)
        return gatt != null
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    fun disconnect(deviceId: String): Boolean {
        val manager = deviceManager(deviceId) ?: return false
        manager.gatt.disconnect()
        return true
    }

    private fun addGatt(gatt: BluetoothGatt): DeviceManager {
        val id = gatt.device.address
        val existing = deviceManagersById[id]
        if (existing != null) {
            return existing
        }

        val manager = DeviceManager(gatt)
        deviceManagersById[id] = manager
        return manager
    }

    private fun removeGatt(deviceId: String): DeviceManager? {
        return deviceManagersById.remove(deviceId)
    }

    private val callback = object : BluetoothGattCallback() {
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            super.onConnectionStateChange(gatt, status, newState)
            val deviceId = gatt.device.address

            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    val manager = addGatt(gatt)
                    listeners.toList().forEach { it.onConnected(manager) }
                    gatt.discoverServices()
                }

                BluetoothProfile.STATE_DISCONNECTED -> {
                    val wasConnected = removeGatt(deviceId) != null
                    gatt.close()
                    if (wasConnected) {
                        listeners.toList().forEach { it.onDisconnected(deviceId) }
                    } else if (status != GATT_SUCCESS) {
                        listeners.toList().forEach { it.onConnectFailed(deviceId) }
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            super.onServicesDiscovered(gatt, status)
            deviceManagersById[gatt.device.address]?.notifyServicesDiscovered(status)
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
            status: Int
        ) {
            super.onCharacteristicRead(gatt, characteristic, value, status)
            deviceManagersById[gatt.device.address]?.notifyCharacteristicRead(characteristic, value, status)
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            super.onCharacteristicWrite(gatt, characteristic, status)
            deviceManagersById[gatt.device.address]?.notifyCharacteristicWrite(characteristic, status)
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            super.onDescriptorWrite(gatt, descriptor, status)
            deviceManagersById[gatt.device.address]?.notifyDescriptorWrite(descriptor, status)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            super.onCharacteristicChanged(gatt, characteristic, value)
            deviceManagersById[gatt.device.address]?.notifyCharacteristicChanged(characteristic, value)
        }
    }
}
