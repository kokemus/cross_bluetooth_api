package io.github.kokemus.cross_bluetooth_api.commands

import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.BluetoothLeDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.IntentSender
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel
import io.github.kokemus.cross_bluetooth_api.extensions.*
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.github.kokemus.cross_bluetooth_api.models.RequestDeviceOptions
import io.github.kokemus.cross_bluetooth_api.services.RequestDeviceLauncher
import java.util.Locale
import java.util.regex.Pattern

class CompanionRequestDeviceCommand(
    private val manager: CompanionDeviceManager,
    private val launcher: RequestDeviceLauncher,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.REQUEST_DEVICE, arguments, pendingResult) {
    private var completed = false
    private val pickerResult = object : MethodChannel.Result {
        override fun success(result: Any?) {
            // Android 13+ completes through onAssociationCreated, not picker dismissal.
            if (Build.VERSION.SDK_INT < 33) finish { it.success(result) }
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            finish { it.error(errorCode, errorMessage, errorDetails) }
        }

        override fun notImplemented() {
            finish { it.notImplemented() }
        }
    }

    override suspend fun execute() {
        try {
            val request = makeRequest(arguments)
            manager.associate(request, object : CompanionDeviceManager.Callback() {
                @Deprecated("Used by Android 12L and earlier")
                override fun onDeviceFound(chooserLauncher: IntentSender) {
                    showPicker(chooserLauncher)
                }

                override fun onAssociationPending(intentSender: IntentSender) {
                    showPicker(intentSender)
                }

                @RequiresApi(33)
                override fun onAssociationCreated(associationInfo: AssociationInfo) {
                    val address = associationInfo.deviceMacAddress
                    if (address == null) {
                        finish { it.notFoundError() }
                    } else {
                        finish {
                            it.success(Device(address.toString().uppercase(Locale.ROOT), associationInfo.displayName?.toString()).toMap())
                        }
                    }
                }

                override fun onFailure(error: CharSequence?) {
                    finish { it.notFoundError(error?.toString() ?: "Companion device association failed.") }
                }
            }, Handler(Looper.getMainLooper()))
        } catch (error: SecurityException) {
            finish { it.securityError(error.message) }
        } catch (error: IllegalArgumentException) {
            finish { it.notSupportedError(error.message) }
        } catch (error: IllegalStateException) {
            finish { it.invalidStateError(error.message) }
        }
    }

    private fun showPicker(intentSender: IntentSender) {
        if (completed) return
        launcher.launch(intentSender, pickerResult)
    }

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        if (completed) return
        completed = true
        launcher.finish(pickerResult)
        reply(pendingResult)
    }

    companion object {
        fun makeRequest(arguments: Map<String, Any>): AssociationRequest {
            val options = RequestDeviceOptions.fromMap(arguments)
            require(!options.acceptAllDevices && !options.filters.isNullOrEmpty()) {
                "Companion setup requires discovery filters."
            }
            val builder = AssociationRequest.Builder().setSingleDevice(false)
            for (filter in options.filters) {
                require((filter.services?.size ?: 0) <= 1 && (filter.manufacturerData?.size ?: 0) <= 1) {
                    "Companion setup supports at most one service and manufacturer per filter."
                }
                require(filter.namePrefix == null || filter.namePrefix.isNotEmpty())
                val nativeFilter = filter.nativeScanFilter()
                require(nativeFilter != null || filter.namePrefix != null) {
                    "Companion setup requires a service, name, name prefix, or manufacturer filter."
                }
                val deviceFilter = BluetoothLeDeviceFilter.Builder()
                nativeFilter?.let { deviceFilter.setScanFilter(it) }
                filter.namePrefix?.let {
                    deviceFilter.setNamePattern(Pattern.compile("^${Pattern.quote(it)}", Pattern.DOTALL))
                }
                builder.addDeviceFilter(deviceFilter.build())
            }
            return builder.build()
        }
    }
}
