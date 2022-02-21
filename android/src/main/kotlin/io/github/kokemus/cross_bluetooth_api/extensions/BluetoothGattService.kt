package io.github.kokemus.cross_bluetooth_api.extensions

import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothGattService.SERVICE_TYPE_PRIMARY

fun BluetoothGattService.toMap(): Map<String, Any?> {
    return mapOf(
        "uuid" to uuid.toString(),
        "isPrimary" to (type == SERVICE_TYPE_PRIMARY)
    )
}