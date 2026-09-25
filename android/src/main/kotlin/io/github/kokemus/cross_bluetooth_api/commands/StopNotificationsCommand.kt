package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattDescriptor
import androidx.annotation.RequiresPermission
import io.github.kokemus.cross_bluetooth_api.extensions.networkError
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.notSupportedError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManagerListener
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

class StopNotificationsCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.STOP_NOTIFICATIONS, arguments, pendingResult), DeviceManagerListener {
    companion object {
        private val clientCharacteristicConfigUuid =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

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
            if (deviceId == null || serviceUUID == null || characteristicUUID == null) {
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

            val cccd = characteristic.getDescriptor(clientCharacteristicConfigUuid)
            if (cccd == null) {
                pendingResult.notSupportedError()
                cleanupAndResume()
                return@suspendCancellableCoroutine
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = characteristicUUID
            targetDeviceManager = deviceManager
            deviceManager.addListener(this)

            if (deviceManager.setCharacteristicNotification(characteristic, false)) {
                cccd.value = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                if (!deviceManager.writeDescriptor(cccd)) {
                    pendingResult.networkError()
                    cleanupAndResume()
                }
            } else {
                pendingResult.networkError()
                cleanupAndResume()
            }
        }
    }

    override fun onDescriptorWrite(
        deviceManager: DeviceManager,
        descriptor: BluetoothGattDescriptor,
        status: Int
    ) {
        if (completed) {
            return
        }

        if (
            descriptor.uuid != clientCharacteristicConfigUuid ||
            deviceManager.deviceId != targetDeviceId
        ) {
            return
        }

        val characteristic = descriptor.characteristic
        if (
            characteristic.service.uuid.toString() != targetServiceUUID ||
            characteristic.uuid.toString() != targetCharacteristicUUID
        ) {
            return
        }

        completed = true
        if (status == GATT_SUCCESS) {
            pendingResult.success(true)
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
