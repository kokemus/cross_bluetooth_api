package io.github.kokemus.cross_bluetooth_api.services

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.github.kokemus.cross_bluetooth_api.RequestDeviceActivity
import io.github.kokemus.cross_bluetooth_api.extensions.invalidStateError
import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.notSupportedError
import io.github.kokemus.cross_bluetooth_api.extensions.securityError
import io.github.kokemus.cross_bluetooth_api.extensions.typeError
import io.github.kokemus.cross_bluetooth_api.extensions.userCancelledError

class RequestDeviceLauncher : PluginRegistry.ActivityResultListener {
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCompletion: (() -> Unit)? = null

    fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    fun detach() {
        pendingResult = null
        pendingCompletion = null
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    fun launch(arguments: Map<String, Any>, result: MethodChannel.Result, onCompleted: (() -> Unit)? = null) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.invalidStateError()
            onCompleted?.invoke()
            return
        }

        pendingResult = result
        pendingCompletion = onCompleted
        currentActivity.startActivityForResult(
            Intent(currentActivity, RequestDeviceActivity::class.java).putExtra("options", HashMap(arguments)),
            0
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?): Boolean {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val selected = intent?.getSerializableExtra("selected")
                pendingResult?.success(selected)
            }

            Activity.RESULT_CANCELED -> pendingResult?.userCancelledError()
            RequestDeviceActivity.RESULT_TYPE_ERROR -> pendingResult?.typeError()
            RequestDeviceActivity.RESULT_NOT_FOUND_ERROR -> pendingResult?.notFoundError()
            RequestDeviceActivity.RESULT_SECURITY_ERROR -> pendingResult?.securityError()
            RequestDeviceActivity.RESULT_NOT_SUPPORTED_ERROR -> pendingResult?.notSupportedError()
            RequestDeviceActivity.RESULT_INVALID_STATE_ERROR -> pendingResult?.invalidStateError()
        }

        pendingResult = null
        pendingCompletion?.invoke()
        pendingCompletion = null
        return false
    }
}
