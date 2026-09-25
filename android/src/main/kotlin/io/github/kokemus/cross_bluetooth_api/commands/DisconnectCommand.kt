package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import androidx.annotation.RequiresPermission
import io.github.kokemus.cross_bluetooth_api.extensions.networkError
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerListener
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

class DisconnectCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.DISCONNECT, arguments, pendingResult), BluetoothManagerListener {
    private var targetDeviceId: String? = null
    private var completed = false
    private var continuation: CancellableContinuation<Unit>? = null

    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override suspend fun execute() {
        suspendCancellableCoroutine { continuation ->
            this.continuation = continuation

            val deviceId = arguments["id"] as? String
            if (deviceId == null) {
                pendingResult.notFoundError()
                cleanupAndResume()
                return@suspendCancellableCoroutine
            }

            if (manager.deviceManager(deviceId) == null) {
                pendingResult.notFoundError()
                cleanupAndResume()
                return@suspendCancellableCoroutine
            }

            targetDeviceId = deviceId
            manager.addListener(this)
            if (!manager.disconnect(deviceId)) {
                completed = true
                pendingResult.networkError()
                cleanupAndResume()
            }
        }
    }

    override fun onDisconnected(deviceId: String) {
        if (deviceId != targetDeviceId || completed) {
            return
        }

        completed = true
        pendingResult.success(true)
        cleanupAndResume()
    }

    private fun cleanupAndResume() {
        manager.removeListener(this)
        continuation?.let {
            if (it.isActive) {
                it.resume(Unit)
            }
        }
        continuation = null
    }
}
