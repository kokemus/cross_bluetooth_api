package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothAdapter
import android.companion.CompanionDeviceManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError

class CompanionForgetCommand(
    private val manager: CompanionDeviceManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.FORGET, arguments, pendingResult) {
    @Suppress("DEPRECATION")
    override suspend fun execute() {
        val deviceId = arguments["id"] as? String
        if (deviceId == null || !BluetoothAdapter.checkBluetoothAddress(deviceId)) {
            pendingResult.notFoundError()
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                manager.myAssociations.filter {
                    it.deviceMacAddress?.toString()?.equals(deviceId, ignoreCase = true) == true
                }.forEach { manager.disassociate(it.id) }
            } else {
                manager.associations.filter { it.equals(deviceId, ignoreCase = true) }
                    .forEach { manager.disassociate(it) }
            }
            pendingResult.success(null)
        } catch (error: SecurityException) {
            pendingResult.error("SecurityError", error.message, null)
        } catch (error: IllegalArgumentException) {
            pendingResult.error("NotSupportedError", error.message, null)
        } catch (error: IllegalStateException) {
            pendingResult.error("InvalidStateError", error.message, null)
        }
    }
}
