package io.github.kokemus.cross_bluetooth_api.services

import android.app.Activity
import android.bluetooth.le.ScanResult
import android.companion.CompanionDeviceManager
import android.content.Intent
import android.content.IntentSender
import android.os.Build
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.github.kokemus.cross_bluetooth_api.views.RequestDeviceActivity
import io.github.kokemus.cross_bluetooth_api.extensions.invalidStateError
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.notSupportedError
import io.github.kokemus.cross_bluetooth_api.extensions.securityError
import io.github.kokemus.cross_bluetooth_api.extensions.typeError
import io.github.kokemus.cross_bluetooth_api.extensions.userCancelledError
import io.github.kokemus.cross_bluetooth_api.models.Device

class RequestDeviceLauncher : PluginRegistry.ActivityResultListener {
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCompletion: (() -> Unit)? = null
    private var pendingRequestCode: Int? = null

    fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    fun detach(forConfigChanges: Boolean = false) {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
        if (!forConfigChanges) {
            complete { it.invalidStateError() }
        }
    }

    fun launch(arguments: Map<String, Any>, result: MethodChannel.Result, onCompleted: (() -> Unit)? = null) {
        launch(0, result, onCompleted) {
            it.startActivityForResult(
                Intent(it, RequestDeviceActivity::class.java).putExtra("options", HashMap(arguments)),
                0
            )
        }
    }

    fun launch(intentSender: IntentSender, result: MethodChannel.Result, onCompleted: (() -> Unit)? = null) {
        launch(COMPANION_REQUEST_CODE, result, onCompleted) {
            it.startIntentSenderForResult(intentSender, COMPANION_REQUEST_CODE, null, 0, 0, 0)
        }
    }

    private fun launch(
        requestCode: Int,
        result: MethodChannel.Result,
        onCompleted: (() -> Unit)?,
        start: (Activity) -> Unit
    ) {
        val currentActivity = activity
        if (currentActivity == null || pendingResult != null) {
            result.invalidStateError()
            onCompleted?.invoke()
            return
        }

        pendingResult = result
        pendingCompletion = onCompleted
        pendingRequestCode = requestCode
        try {
            start(currentActivity)
        } catch (error: IntentSender.SendIntentException) {
            complete { it.error("UnknownError", error.message, null) }
        } catch (error: IllegalStateException) {
            complete { it.error("InvalidStateError", error.message, null) }
        }
    }

    fun finish(result: MethodChannel.Result) {
        if (pendingResult !== result) return
        pendingResult = null
        pendingCompletion = null
        pendingRequestCode = null
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?): Boolean {
        if (requestCode != pendingRequestCode) return false
        complete { result ->
            when {
                resultCode == Activity.RESULT_CANCELED -> result.userCancelledError()
                requestCode == COMPANION_REQUEST_CODE -> when {
                    resultCode != Activity.RESULT_OK -> result.notFoundError()
                    Build.VERSION.SDK_INT >= 33 -> result.success(null)
                    else -> {
                        val selected = intent?.getParcelableExtra<ScanResult>(CompanionDeviceManager.EXTRA_DEVICE)
                        if (selected == null) {
                            result.notFoundError()
                        } else {
                            result.success(Device(selected.device.address, selected.scanRecord?.deviceName).toMap())
                        }
                    }
                }
                else -> when (resultCode) {
                    Activity.RESULT_OK -> result.success(intent?.getSerializableExtra("selected"))
                    RequestDeviceActivity.RESULT_TYPE_ERROR -> result.typeError()
                    RequestDeviceActivity.RESULT_NOT_FOUND_ERROR -> result.notFoundError()
                    RequestDeviceActivity.RESULT_SECURITY_ERROR -> result.securityError()
                    RequestDeviceActivity.RESULT_NOT_SUPPORTED_ERROR -> result.notSupportedError()
                    RequestDeviceActivity.RESULT_INVALID_STATE_ERROR -> result.invalidStateError()
                    else -> result.error("UnknownError", "Unexpected device chooser result: $resultCode.", null)
                }
            }
        }
        return true
    }

    private fun complete(reply: (MethodChannel.Result) -> Unit) {
        val result = pendingResult ?: return
        val completion = pendingCompletion
        finish(result)
        reply(result)
        completion?.invoke()
    }

    companion object {
        const val COMPANION_REQUEST_CODE = 0x4342
    }
}
