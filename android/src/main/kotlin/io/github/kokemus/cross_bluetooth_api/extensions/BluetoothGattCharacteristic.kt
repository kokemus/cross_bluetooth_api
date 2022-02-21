package io.github.kokemus.cross_bluetooth_api.extensions

import android.bluetooth.BluetoothGattCharacteristic


fun BluetoothGattCharacteristic.toMap(): Map<String, Any?> {
    return mapOf(
        "uuid" to uuid.toString()
    )
}