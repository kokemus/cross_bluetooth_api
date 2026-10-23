package io.github.kokemus.cross_bluetooth_api.testing.fakes

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

@Suppress("unused") // Constructed and exercised by RequestDeviceCommandTest.
class FakeActivityPluginBinding(private val host: Activity) : ActivityPluginBinding {
    private val resultListeners = linkedSetOf<PluginRegistry.ActivityResultListener>()
    val resultListenerCount: Int
        get() = resultListeners.size

    override fun getActivity(): Activity = host
    override fun getLifecycle(): Any = host

    override fun addActivityResultListener(listener: PluginRegistry.ActivityResultListener) {
        resultListeners.add(listener)
    }

    override fun removeActivityResultListener(listener: PluginRegistry.ActivityResultListener) {
        resultListeners.remove(listener)
    }

    fun emitActivityResult(requestCode: Int, resultCode: Int, intent: Intent?) {
        resultListeners.toList().forEach { it.onActivityResult(requestCode, resultCode, intent) }
    }

    override fun addRequestPermissionsResultListener(listener: PluginRegistry.RequestPermissionsResultListener) = Unit
    override fun removeRequestPermissionsResultListener(listener: PluginRegistry.RequestPermissionsResultListener) = Unit
    override fun addOnNewIntentListener(listener: PluginRegistry.NewIntentListener) = Unit
    override fun removeOnNewIntentListener(listener: PluginRegistry.NewIntentListener) = Unit
    override fun addOnUserLeaveHintListener(listener: PluginRegistry.UserLeaveHintListener) = Unit
    override fun removeOnUserLeaveHintListener(listener: PluginRegistry.UserLeaveHintListener) = Unit
    override fun addOnWindowFocusChangedListener(listener: PluginRegistry.WindowFocusChangedListener) = Unit
    override fun removeOnWindowFocusChangedListener(listener: PluginRegistry.WindowFocusChangedListener) = Unit
    override fun addOnSaveStateListener(listener: ActivityPluginBinding.OnSaveInstanceStateListener) = Unit
    override fun removeOnSaveStateListener(listener: ActivityPluginBinding.OnSaveInstanceStateListener) = Unit
}

