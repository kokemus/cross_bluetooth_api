package io.github.kokemus.cross_bluetooth_api.models

import android.Manifest
import android.bluetooth.BluetoothDevice
import androidx.annotation.RequiresPermission

data class Device(
    val id: String,
    val name: String?
) {
    companion object {
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        fun fromBluetoothDevice(device: BluetoothDevice): Device {
            return Device(device.address, device.name)
        }

        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): Device = Device(
            name = map.getOrDefault("name", "") as String,
            id = map.getValue("id") as String

        )
    }

    fun toMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to name
        )
    }
}
