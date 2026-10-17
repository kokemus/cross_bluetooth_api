package io.github.kokemus.cross_bluetooth_api.commands

import android.app.Activity
import android.content.Intent
import io.github.kokemus.cross_bluetooth_api.services.RequestDeviceLauncher
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeActivityPluginBinding
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import io.github.kokemus.cross_bluetooth_api.views.RequestDeviceActivity
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.Serializable

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class RequestDeviceCommandTest {
    private suspend fun withLauncher(
        test: suspend (Activity, RequestDeviceLauncher, FakeActivityPluginBinding) -> Unit
    ) {
        val controller = Robolectric.buildActivity(Activity::class.java)
        controller.get().setTheme(android.R.style.Theme_DeviceDefault)
        controller.setup()
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

    @Test
    fun execute_forwardsOptionsAndWaitsForSelection() = runTest {
        withLauncher { activity, launcher, binding ->
            val options: Map<String, Any> = mapOf("acceptAllDevices" to true, "optionalServices" to arrayListOf("battery_service"))
            val result = FakeResult()
            val command = RequestDeviceCommand(launcher, options, result)
            val job = async { command.execute() }
            runCurrent()
            assertFalse(job.isCompleted)
            assertEquals(0, result.replyCount)
            val started = shadowOf(activity).nextStartedActivityForResult
            assertEquals(RequestDeviceActivity::class.java.name, started.intent.component!!.className)
            assertEquals(options, started.intent.getSerializableExtra("options", Serializable::class.java))
            val selected = hashMapOf("id" to "AA:BB:CC:DD:EE:FF", "name" to "Test device")
            val response = Intent().putExtra("selected", selected as Serializable)
            binding.emitActivityResult(started.requestCode, Activity.RESULT_OK, response)
            withTimeout(1_000) { job.await() }
            assertEquals(selected, result.successValue)
            assertNull(result.errorCode)
            assertEquals(1, result.replyCount)
            binding.emitActivityResult(started.requestCode, Activity.RESULT_OK, response)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_returnsInvalidStateWhenLauncherIsDetached() = runTest {
        val result = FakeResult()
        RequestDeviceCommand(RequestDeviceLauncher(), emptyMap(), result).execute()
        assertEquals("InvalidStateError", result.errorCode)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_propagatesCancellationAndEveryChooserErrorAndResumes() = runTest {
        withLauncher { activity, launcher, binding ->
            val errors = listOf(
                Activity.RESULT_CANCELED to "NotFoundError",
                RequestDeviceActivity.RESULT_TYPE_ERROR to "TypeError",
                RequestDeviceActivity.RESULT_NOT_FOUND_ERROR to "NotFoundError",
                RequestDeviceActivity.RESULT_SECURITY_ERROR to "SecurityError",
                RequestDeviceActivity.RESULT_NOT_SUPPORTED_ERROR to "NotSupportedError",
                RequestDeviceActivity.RESULT_INVALID_STATE_ERROR to "InvalidStateError"
            )
            for ((code, expected) in errors) {
                val result = FakeResult()
                val command = RequestDeviceCommand(launcher, mapOf("acceptAllDevices" to true), result)
                val job = async { command.execute() }
                runCurrent()
                val started = shadowOf(activity).nextStartedActivityForResult
                assertFalse(job.isCompleted)
                binding.emitActivityResult(started.requestCode, code, null)
                withTimeout(1_000) { job.await() }
                assertEquals(expected, result.errorCode)
                assertEquals(1, result.replyCount)
                assertNull(result.successValue)
                if (code == Activity.RESULT_CANCELED) {
                    assertTrue(result.errorMessage!!.contains("User cancelled"))
                }
            }
        }
    }
}

