package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothDevice
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerImp
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeBluetoothManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeDeviceManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.lang.reflect.InvocationTargetException

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class ForgetCommandTest {
    private val deviceId = "AA:BB:CC:DD:EE:FF"

    @Test
    fun execute_requestsBondRemovalWithoutDisconnectingDevice() = runTest {
        val manager = FakeBluetoothManager()
        val deviceManager = FakeDeviceManager(deviceId)
        manager.devices[deviceId] = deviceManager
        val result = FakeResult()

        ForgetCommand(manager, mapOf("id" to deviceId), result).execute()

        assertEquals(listOf(deviceId), manager.forgottenIds)
        assertSame(deviceManager, manager.deviceManager(deviceId))
        assertTrue(manager.disconnectedIds.isEmpty())
        assertNull(result.errorCode)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_reportsRejectedBondRemoval() = runTest {
        val manager = FakeBluetoothManager().apply { forgetReturnValue = false }
        val result = FakeResult()
        ForgetCommand(manager, mapOf("id" to deviceId), result).execute()
        assertEquals("NetworkError", result.errorCode)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_reportsUnavailableReflection() = runTest {
        for (error in listOf(NoSuchMethodException("removeBond"), IllegalAccessException("removeBond"))) {
            val manager = FakeBluetoothManager().apply { forgetException = error }
            val result = FakeResult()
            ForgetCommand(manager, mapOf("id" to deviceId), result).execute()
            assertEquals("NotSupportedError", result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_reportsMissingPermissionIncludingReflectedErrors() = runTest {
        for (error in listOf(SecurityException(), InvocationTargetException(SecurityException()))) {
            val manager = FakeBluetoothManager().apply { forgetException = error }
            val result = FakeResult()
            ForgetCommand(manager, mapOf("id" to deviceId), result).execute()
            assertEquals("SecurityError", result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_reportsReflectedPlatformFailure() = runTest {
        val manager = FakeBluetoothManager().apply {
            forgetException = InvocationTargetException(IllegalStateException("Bond removal failed"))
        }
        val result = FakeResult()
        ForgetCommand(manager, mapOf("id" to deviceId), result).execute()
        assertEquals("UnknownError", result.errorCode)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun manager_forgetRemovesBondViaReflectionWithoutGattConnection() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
        val device = bluetoothManager.adapter.getRemoteDevice(deviceId)
        shadowOf(device).setBondState(BluetoothDevice.BOND_BONDED)
        shadowOf(device).setCreatedBond(true)
        val manager = BluetoothManagerImp(context)

        assertTrue(manager.forget(deviceId))

        assertEquals(BluetoothDevice.BOND_NONE, device.bondState)
        assertNull(manager.deviceManager(deviceId))
        assertTrue(manager.forget(deviceId))
    }

    @Test
    fun manager_forgetReportsRejectedBondRemoval() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
        val device = bluetoothManager.adapter.getRemoteDevice(deviceId)
        shadowOf(device).setBondState(BluetoothDevice.BOND_BONDED)
        shadowOf(device).setCreatedBond(false)
        val manager = BluetoothManagerImp(context)

        assertFalse(manager.forget(deviceId))
        assertEquals(BluetoothDevice.BOND_BONDED, device.bondState)
    }

    @Test
    fun manager_forgetSucceedsForUnbondedDevice() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val manager = BluetoothManagerImp(context)
        assertTrue(manager.forget(deviceId))
    }

    @Test
    fun execute_succeedsForAlreadyForgottenDevice() = runTest {
        val manager = FakeBluetoothManager()
        repeat(2) {
            val result = FakeResult()
            ForgetCommand(manager, mapOf("id" to deviceId), result).execute()
            assertNull(result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_rejectsMissingOrInvalidIdentifier() = runTest {
        for (arguments in listOf(emptyMap(), mapOf("id" to 123), mapOf("id" to "invalid"))) {
            val manager = FakeBluetoothManager()
            val result = FakeResult()
            ForgetCommand(manager, arguments, result).execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
            assertTrue(manager.forgottenIds.isEmpty())
        }
    }
}
