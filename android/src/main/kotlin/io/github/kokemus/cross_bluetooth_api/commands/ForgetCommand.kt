package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import android.bluetooth.BluetoothAdapter
import androidx.annotation.RequiresPermission
import io.flutter.plugin.common.MethodChannel
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.networkError
import io.github.kokemus.cross_bluetooth_api.extensions.notSupportedError
import io.github.kokemus.cross_bluetooth_api.extensions.securityError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import java.lang.reflect.InvocationTargetException

class ForgetCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.FORGET, arguments, pendingResult) {
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override suspend fun execute() {
        val deviceId = arguments["id"] as? String
        if (deviceId == null || !BluetoothAdapter.checkBluetoothAddress(deviceId)) {
            pendingResult.notFoundError()
            return
        }

        try {
            if (manager.forget(deviceId)) {
                pendingResult.success(null)
            } else {
                pendingResult.networkError()
            }
        } catch (_: SecurityException) {
            pendingResult.securityError()
        } catch (error: InvocationTargetException) {
            if (error.targetException is SecurityException) {
                pendingResult.securityError()
            } else {
                pendingResult.error(
                    "UnknownError",
                    "UnknownError: Failed to remove Bluetooth bond: ${error.targetException.message}",
                    null
                )
            }
        } catch (_: ReflectiveOperationException) {
            pendingResult.notSupportedError()
        }
    }
}
