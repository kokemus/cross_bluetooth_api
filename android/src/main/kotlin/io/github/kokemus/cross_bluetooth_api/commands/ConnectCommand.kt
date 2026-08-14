package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import androidx.annotation.RequiresPermission
import io.github.kokemus.cross_bluetooth_api.extensions.networkError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerListener
import io.github.kokemus.cross_bluetooth_api.services.DeviceManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManagerListener
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

class ConnectCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.CONNECT, arguments, pendingResult), BluetoothManagerListener,
    DeviceManagerListener {
    private var targetDeviceId: String? = null
    private var targetDeviceManager: DeviceManager? = null
    private var completed = false
    private var continuation: CancellableContinuation<Unit>? = null

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override suspend fun execute() {
        suspendCancellableCoroutine { continuation ->
            this.continuation = continuation

            val device = Device.fromMap(arguments)
            targetDeviceId = device.id
            manager.addListener(this)

            if (!manager.connect(device.id)) {
                pendingResult.networkError()
                cleanupAndResume()
            }
        }
    }

    override fun onConnected(deviceManager: DeviceManager) {
        if (deviceManager.deviceId != targetDeviceId || completed) {
            return
        }

        targetDeviceManager = deviceManager
        deviceManager.addListener(this)
    }

    override fun onConnectFailed(deviceId: String) {
        if (deviceId != targetDeviceId || completed) {
            return
        }

        completed = true
        pendingResult.networkError()
        cleanupAndResume()
    }

    override fun onDisconnected(deviceId: String) {
        if (deviceId != targetDeviceId || completed) {
            return
        }

        completed = true
        pendingResult.networkError()
        cleanupAndResume()
    }

    override fun onServicesDiscovered(deviceManager: DeviceManager, status: Int) {
        if (deviceManager.deviceId != targetDeviceId || completed) {
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
        manager.removeListener(this)
        continuation?.let {
            if (it.isActive) {
                it.resume(Unit)
            }
        }
        continuation = null
    }
}
