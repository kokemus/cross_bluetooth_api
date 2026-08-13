package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
import androidx.annotation.RequiresPermission
import io.github.kokemus.cross_bluetooth_api.extensions.networkError
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManagerListener
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

class WriteValueWithoutResponseCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.WRITE_VALUE_WITHOUT_RESPONSE, arguments, pendingResult), DeviceManagerListener {
    private var targetDeviceId: String? = null
    private var targetServiceUUID: String? = null
    private var targetCharacteristicUUID: String? = null
    private var targetDeviceManager: DeviceManager? = null
    private var completed = false
    private var continuation: CancellableContinuation<Unit>? = null

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override suspend fun execute() {
        suspendCancellableCoroutine { continuation ->
            this.continuation = continuation

            val deviceId = arguments["deviceId"] as? String
            val serviceUUID = arguments["serviceUUID"] as? String
            val characteristicUUID = arguments["characteristic"] as? String
            val value = arguments["value"] as? ByteArray
            if (deviceId == null || serviceUUID == null || characteristicUUID == null || value == null) {
                pendingResult.notFoundError()
                cleanupAndResume()
                return@suspendCancellableCoroutine
            }

            val deviceManager = manager.deviceManager(deviceId)
            val characteristic = deviceManager?.getCharacteristic(serviceUUID, characteristicUUID)
            if (deviceManager == null || characteristic == null) {
                pendingResult.notFoundError()
                cleanupAndResume()
                return@suspendCancellableCoroutine
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = characteristicUUID
            targetDeviceManager = deviceManager
            deviceManager.addListener(this)

            characteristic.value = value
            characteristic.writeType = WRITE_TYPE_NO_RESPONSE
            if (!deviceManager.gatt.writeCharacteristic(characteristic)) {
                pendingResult.networkError()
                cleanupAndResume()
            }
        }
    }

    override fun onCharacteristicWrite(
        deviceManager: DeviceManager,
        characteristic: BluetoothGattCharacteristic,
        status: Int
    ) {
        if (completed) {
            return
        }

        if (
            deviceManager.deviceId != targetDeviceId ||
            characteristic.service.uuid.toString() != targetServiceUUID ||
            characteristic.uuid.toString() != targetCharacteristicUUID
        ) {
            return
        }

        completed = true
        if (status == GATT_SUCCESS) {
            pendingResult.success(characteristic.value)
        } else {
            pendingResult.networkError()
        }
        cleanupAndResume()
    }

    private fun cleanupAndResume() {
        targetDeviceManager?.removeListener(this)
        continuation?.let {
            if (it.isActive) {
                it.resume(Unit)
            }
        }
        continuation = null
    }
}
