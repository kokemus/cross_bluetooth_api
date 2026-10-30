package io.github.kokemus.cross_bluetooth_api.commands

import android.companion.CompanionDeviceManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import io.github.kokemus.cross_bluetooth_api.models.Device
import java.util.Locale

class CompanionGetDevicesCommand(
    private val manager: CompanionDeviceManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.GET_DEVICES, arguments, pendingResult) {
    @Suppress("DEPRECATION")
    override suspend fun execute() {
        try {
            val devices = if (Build.VERSION.SDK_INT >= 33) {
                manager.myAssociations.mapNotNull { association ->
                    association.deviceMacAddress?.let {
                        Device(it.toString().uppercase(Locale.ROOT), association.displayName?.toString())
                    }
                }
            } else {
                manager.associations.map { Device(it, null) }
            }
            pendingResult.success(devices.map { it.toMap() })
        } catch (error: SecurityException) {
            pendingResult.error("SecurityError", error.message, null)
        } catch (error: IllegalArgumentException) {
            pendingResult.error("NotSupportedError", error.message, null)
        } catch (error: IllegalStateException) {
            pendingResult.error("InvalidStateError", error.message, null)
        }
    }
}
