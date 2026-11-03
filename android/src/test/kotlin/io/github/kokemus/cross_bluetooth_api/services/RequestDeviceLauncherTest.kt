package io.github.kokemus.cross_bluetooth_api.services

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeActivityPluginBinding
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class RequestDeviceLauncherTest {
    private fun withLauncher(
        test: (Activity, RequestDeviceLauncher, FakeActivityPluginBinding) -> Unit
    ) {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val activity = controller.get()
        val binding = FakeActivityPluginBinding(activity)
        val launcher = RequestDeviceLauncher()
        launcher.attach(binding)
        try {
            assertEquals(1, binding.resultListenerCount)
            test(activity, launcher, binding)
        } finally {
            launcher.detach()
            assertEquals(0, binding.resultListenerCount)
            controller.pause().stop().destroy()
        }
    }

    private fun pickerIntentSender(activity: Activity) = PendingIntent.getActivity(
        activity, 0, Intent(activity, Activity::class.java), PendingIntent.FLAG_IMMUTABLE
    ).intentSender

    @Test
    fun onActivityResult_ignoresCompanionResultsDuringCustomPicker() {
        withLauncher { _, launcher, binding ->
            val result = FakeResult()
            launcher.launch(mapOf("acceptAllDevices" to true), result)
            binding.emitActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertEquals(0, result.replyCount)
            binding.emitActivityResult(0, Activity.RESULT_CANCELED, null)
            assertEquals("NotFoundError", result.errorCode)
        }
    }

    @Test
    fun launch_rejectsOverlappingPickersAndRoutesResults() {
        withLauncher { activity, launcher, binding ->
            val sender = pickerIntentSender(activity)
            val custom = FakeResult()
            launcher.launch(mapOf("acceptAllDevices" to true), custom)
            val rejectedCompanion = FakeResult()
            launcher.launch(sender, rejectedCompanion)
            assertEquals("InvalidStateError", rejectedCompanion.errorCode)
            assertEquals(0, custom.replyCount)

            var completed = 0
            val rejectedCustom = FakeResult()
            launcher.launch(mapOf("acceptAllDevices" to true), rejectedCustom) { completed++ }
            assertEquals("InvalidStateError", rejectedCustom.errorCode)
            assertEquals(1, completed)
            binding.emitActivityResult(0, Activity.RESULT_CANCELED, null)
            assertEquals("NotFoundError", custom.errorCode)

            val companion = FakeResult()
            launcher.launch(sender, companion)
            val rejectedDuringCompanion = FakeResult()
            launcher.launch(mapOf("acceptAllDevices" to true), rejectedDuringCompanion) { completed++ }
            assertEquals("InvalidStateError", rejectedDuringCompanion.errorCode)
            assertEquals(2, completed)
            assertFalse(launcher.onActivityResult(0, Activity.RESULT_CANCELED, null))
            binding.emitActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_OK, Intent())
            assertEquals(1, companion.successCount)
            assertNull(companion.successValue)

            val nextCustom = FakeResult()
            launcher.launch(mapOf("acceptAllDevices" to true), nextCustom)
            binding.emitActivityResult(0, Activity.RESULT_CANCELED, null)
            assertEquals("NotFoundError", nextCustom.errorCode)
            assertEquals(1, companion.replyCount)
        }
    }
}
