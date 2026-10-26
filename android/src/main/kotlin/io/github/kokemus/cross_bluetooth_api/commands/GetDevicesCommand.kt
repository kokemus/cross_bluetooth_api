package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import androidx.annotation.RequiresPermission
import io.flutter.plugin.common.MethodChannel
import io.github.kokemus.cross_bluetooth_api.extensions.invalidStateError
import io.github.kokemus.cross_bluetooth_api.extensions.notSupportedError
import io.github.kokemus.cross_bluetooth_api.extensions.securityError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager

class GetDevicesCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.GET_DEVICES, arguments, pendingResult) {
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override suspend fun execute() {
        try {
            pendingResult.success(manager.getDevices().map { it.toMap() })
        } catch (_: SecurityException) {
            pendingResult.securityError()
        } catch (_: UnsupportedOperationException) {
            pendingResult.notSupportedError()
        } catch (_: IllegalStateException) {
            pendingResult.invalidStateError()
        }
    }
}
