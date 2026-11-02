package io.github.kokemus.cross_bluetooth_api.commands

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.companion.CompanionDeviceManager
import android.os.Build
import androidx.annotation.RequiresPermission
import io.flutter.plugin.common.MethodChannel
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.networkError
import io.github.kokemus.cross_bluetooth_api.extensions.notSupportedError
import io.github.kokemus.cross_bluetooth_api.extensions.securityError
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import java.lang.reflect.InvocationTargetException

class CompanionForgetCommand(
    private val manager: CompanionDeviceManager,
    private val bluetoothManager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.FORGET, arguments, pendingResult) {
    @Suppress("DEPRECATION")
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override suspend fun execute() {
        val deviceId = arguments["id"] as? String
        if (deviceId == null || !BluetoothAdapter.checkBluetoothAddress(deviceId)) {
            pendingResult.notFoundError()
            return
        }
        try {
            val hasAssociation = if (Build.VERSION.SDK_INT >= 33) {
                val associations = manager.myAssociations.filter {
                    it.deviceMacAddress?.toString()?.equals(deviceId, ignoreCase = true) == true
                }
                associations.forEach { manager.disassociate(it.id) }
                associations.isNotEmpty()
            } else {
                val associations = manager.associations.filter { it.equals(deviceId, ignoreCase = true) }
                associations.forEach { manager.disassociate(it) }
                associations.isNotEmpty()
            }
            if (hasAssociation || bluetoothManager.forget(deviceId)) {
                pendingResult.success(null)
            } else {
                pendingResult.networkError()
            }
        } catch (error: SecurityException) {
            pendingResult.error("SecurityError", error.message, null)
        } catch (error: IllegalArgumentException) {
            pendingResult.error("NotSupportedError", error.message, null)
        } catch (error: IllegalStateException) {
            pendingResult.error("InvalidStateError", error.message, null)
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
