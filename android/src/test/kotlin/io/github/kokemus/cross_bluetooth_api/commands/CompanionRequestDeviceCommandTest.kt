package io.github.kokemus.cross_bluetooth_api.commands

import android.app.Activity
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.companion.AssociationInfo
import android.companion.BluetoothLeDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.Context
import android.content.Intent
import android.os.ParcelUuid
import androidx.test.core.app.ApplicationProvider
import io.github.kokemus.cross_bluetooth_api.services.RequestDeviceLauncher
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeActivityPluginBinding
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.AssociationInfoBuilder
import org.robolectric.util.ReflectionHelpers
import java.util.regex.Pattern

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class CompanionRequestDeviceCommandTest {
    private lateinit var context: Context
    private lateinit var manager: CompanionDeviceManager
    private lateinit var launcher: RequestDeviceLauncher
    private val address = "AA:BB:CC:DD:EE:FF"
    private val options: Map<String, Any> = mapOf(
        "filters" to listOf(mapOf(
            "services" to listOf("181a")
        ))
    )

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        manager = context.getSystemService(CompanionDeviceManager::class.java)
        launcher = RequestDeviceLauncher()
    }

    private fun association(): AssociationInfo = AssociationInfoBuilder.newBuilder()
        .setId(1)
        .setUserId(0)
        .setPackageName(context.packageName)
        .setDeviceMacAddress(address)
        .setDisplayName("Tag")
        .build()

    private fun withActivity(test: (Activity, FakeActivityPluginBinding) -> Unit) {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val binding = FakeActivityPluginBinding(controller.get())
        launcher.attach(binding)
        try {
            assertEquals(1, binding.resultListenerCount)
            test(controller.get(), binding)
        } finally {
            launcher.detach()
            assertEquals(0, binding.resultListenerCount)
            controller.pause().stop().destroy()
        }
    }

    private fun requestDevice(result: FakeResult) = runTest {
        CompanionRequestDeviceCommand(manager, launcher, options, result).execute()
    }

    private fun pickerIntentSender() = PendingIntent.getActivity(
        context, 0, Intent(context, Activity::class.java), PendingIntent.FLAG_IMMUTABLE
    ).intentSender

    @Test
    fun filtersPreserveServiceManufacturerMaskAndLiteralPrefix() {
        val request = CompanionRequestDeviceCommand.makeRequest(mapOf("filters" to listOf(mapOf(
            "services" to listOf("181a"),
            "namePrefix" to "Tag.",
            "manufacturerData" to listOf(mapOf(
                "companyIdentifier" to 123,
                "dataPrefix" to listOf(128, 255),
                "mask" to listOf(255, 240)
            ))
        ), mapOf("name" to "Other"))))
        val filters = ReflectionHelpers.callInstanceMethod<List<BluetoothLeDeviceFilter>>(request, "getDeviceFilters")
        assertEquals(2, filters.size)
        val scanFilter = ReflectionHelpers.callInstanceMethod<ScanFilter>(filters[0], "getScanFilter")
        val pattern = ReflectionHelpers.callInstanceMethod<Pattern>(filters[0], "getNamePattern")
        assertEquals(ParcelUuid.fromString("0000181a-0000-1000-8000-00805f9b34fb"), scanFilter.serviceUuid)
        assertEquals(123, scanFilter.manufacturerId)
        assertArrayEquals(byteArrayOf(128.toByte(), 255.toByte()), scanFilter.manufacturerData)
        assertArrayEquals(byteArrayOf(255.toByte(), 240.toByte()), scanFilter.manufacturerDataMask)
        assertTrue(pattern.matcher("Tag.device").find())
        assertFalse(pattern.matcher("TagXdevice").find())
        assertFalse(pattern.matcher("OtherTag.device").find())
        assertEquals("Other", ReflectionHelpers.callInstanceMethod<ScanFilter>(filters[1], "getScanFilter").deviceName)
    }

    @Test
    fun unrepresentableOptionsAreRejected() {
        withActivity { _, _ ->
            val invalid = listOf(
                mapOf("acceptAllDevices" to true),
                mapOf("filters" to emptyList<Map<String, Any>>()),
                mapOf("filters" to listOf(emptyMap<String, Any>())),
                mapOf("filters" to listOf(mapOf("services" to listOf("180a", "181a")))),
                mapOf("filters" to listOf(mapOf("namePrefix" to ""))),
                mapOf("filters" to listOf(mapOf("services" to listOf("not-a-uuid"))))
            )
            for (arguments in invalid) {
                val result = FakeResult()
                runTest { CompanionRequestDeviceCommand(manager, launcher, arguments, result).execute() }
                assertEquals("NotSupportedError", result.errorCode)
                assertEquals(1, result.replyCount)
            }
        }
    }

    @Test
    fun requestWaitsForAssociationAndRepliesExactlyOnce() {
        withActivity { activity, binding ->
            val result = FakeResult()
            requestDevice(result)
            val callback = shadowOf(manager).lastAssociationCallback
            callback.onAssociationPending(pickerIntentSender())
            assertEquals(RequestDeviceLauncher.COMPANION_REQUEST_CODE, shadowOf(activity).nextStartedActivityForResult.requestCode)
            binding.emitActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_OK, Intent())
            assertEquals(0, result.replyCount)
            callback.onAssociationCreated(association())
            callback.onFailure("late failure")
            assertEquals(mapOf("id" to address, "name" to "Tag"), result.successValue)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun concurrentRequestCancellationAndStaleCallbacks() {
        withActivity { _, binding ->
            val first = FakeResult()
            requestDevice(first)
            val callback = shadowOf(manager).lastAssociationCallback
            val concurrent = FakeResult()
            requestDevice(concurrent)
            val concurrentCallback = shadowOf(manager).lastAssociationCallback
            assertEquals(0, concurrent.replyCount)
            callback.onAssociationPending(pickerIntentSender())
            concurrentCallback.onAssociationPending(pickerIntentSender())
            assertEquals("InvalidStateError", concurrent.errorCode)
            assertFalse(launcher.onActivityResult(99, Activity.RESULT_CANCELED, null))
            assertEquals(0, first.replyCount)
            binding.emitActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_CANCELED, null)
            assertEquals("NotFoundError", first.errorCode)
            val second = FakeResult()
            requestDevice(second)
            callback.onFailure("stale")
            assertEquals(0, second.replyCount)
            shadowOf(manager).lastAssociationCallback.onFailure("Discovery failed")
            assertEquals("NotFoundError: Discovery failed", second.errorMessage)
            assertEquals(1, first.replyCount)
        }
    }

    @Test
    fun detachCompletesPendingRequestButConfigurationChangeRetainsIt() {
        withActivity { _, binding ->
            val result = FakeResult()
            requestDevice(result)
            shadowOf(manager).lastAssociationCallback.onAssociationPending(pickerIntentSender())
            launcher.detach(forConfigChanges = true)
            assertEquals(0, result.replyCount)
            assertEquals(0, binding.resultListenerCount)
            launcher.attach(binding)
            binding.emitActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_OK, Intent())
            shadowOf(manager).lastAssociationCallback.onAssociationCreated(association())
            assertEquals(1, result.successCount)
            val pending = FakeResult()
            requestDevice(pending)
            shadowOf(manager).lastAssociationCallback.onAssociationPending(pickerIntentSender())
            launcher.detach()
            assertEquals("InvalidStateError", pending.errorCode)
        }
        val detached = FakeResult()
        requestDevice(detached)
        shadowOf(manager).lastAssociationCallback.onAssociationPending(pickerIntentSender())
        assertEquals("InvalidStateError", detached.errorCode)
    }

    @Test
    fun associationFailureReleasesPickerAndStaleCallbacksDoNotClearNextRequest() {
        withActivity { _, binding ->
            val failed = FakeResult()
            requestDevice(failed)
            val callback = shadowOf(manager).lastAssociationCallback
            callback.onAssociationPending(pickerIntentSender())
            callback.onFailure("Association failed")
            assertEquals("NotFoundError: Association failed", failed.errorMessage)

            var completed = 0
            val custom = FakeResult()
            launcher.launch(mapOf("acceptAllDevices" to true), custom) { completed++ }
            callback.onAssociationCreated(association())
            callback.onAssociationPending(pickerIntentSender())
            assertEquals(1, failed.replyCount)
            assertFalse(launcher.onActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_CANCELED, null))
            binding.emitActivityResult(0, Activity.RESULT_CANCELED, null)
            assertEquals("NotFoundError", custom.errorCode)
            assertEquals(1, completed)
        }
    }

    @Test
    @Config(sdk = [26, 32])
    @Suppress("DEPRECATION")
    fun legacyPickerReturnsSelectedBleDevice() {
        withActivity { _, binding ->
            val result = FakeResult()
            requestDevice(result)
            shadowOf(manager).lastAssociationCallback.onDeviceFound(pickerIntentSender())
            val selected = ScanResult(BluetoothAdapter.getDefaultAdapter().getRemoteDevice(address), null, -40, 0)
            binding.emitActivityResult(RequestDeviceLauncher.COMPANION_REQUEST_CODE, Activity.RESULT_OK,
                Intent().putExtra(CompanionDeviceManager.EXTRA_DEVICE, selected))
            assertEquals(mapOf("id" to address, "name" to null), result.successValue)
            assertEquals(1, result.replyCount)
        }
    }
}
