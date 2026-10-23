package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothGatt.GATT_FAILURE
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
import io.github.kokemus.cross_bluetooth_api.testing.GattFixture
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeDeviceManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class StopNotificationsCommandTest {
    @Test
    fun execute_disablesNotificationsAndWaitsForDescriptorCallback() = runTest {
        val fixture = GattFixture(properties = 0)
        val result = FakeResult()
        val command = StopNotificationsCommand(fixture.manager, fixture.arguments, result)
        val job = async { command.execute() }
        runCurrent()
        assertFalse(job.isCompleted)
        assertEquals(0, result.replyCount)
        assertTrue(fixture.device.hasListener(command))
        assertEquals(listOf("notification", "descriptor"), fixture.device.operations)
        assertSame(fixture.characteristic, fixture.device.notificationCharacteristic)
        assertEquals(false, fixture.device.notificationEnabled)
        assertSame(fixture.descriptor, fixture.device.writtenDescriptor)
        assertArrayEquals(DISABLE_NOTIFICATION_VALUE, fixture.device.descriptorValue)
        fixture.device.emitDescriptorWrite(fixture.descriptor, GATT_SUCCESS)
        withTimeout(1_000) { job.await() }
        assertEquals(true, result.successValue)
        assertNull(result.errorCode)
        assertFalse(fixture.device.hasListener(command))
        command.onDescriptorWrite(fixture.device, fixture.descriptor, GATT_FAILURE)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_validatesEveryRequiredArgument() = runTest {
        val fixture = GattFixture(properties = 0)
        for (key in fixture.arguments.keys) {
            for (invalid in listOf(fixture.arguments - key, fixture.arguments + (key to 123))) {
                val result = FakeResult()
                val command = StopNotificationsCommand(fixture.manager, invalid, result)
                command.execute()
                assertEquals("NotFoundError", result.errorCode)
                assertEquals(1, result.replyCount)
                assertTrue(fixture.device.operations.isEmpty())
                assertFalse(fixture.device.hasListener(command))
            }
        }
    }

    @Test
    fun execute_returnsNotFoundForMissingDeviceServiceOrCharacteristic() = runTest {
        for (missing in 0..2) {
            val fixture = GattFixture(properties = 0)
            var arguments = fixture.arguments
            when (missing) {
                0 -> fixture.manager.devices.clear()
                1 -> fixture.device.services.clear()
                2 -> arguments = arguments + ("characteristic" to "00002a00-0000-1000-8000-00805f9b34fb")
            }
            val result = FakeResult()
            val command = StopNotificationsCommand(fixture.manager, arguments, result)
            command.execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
            assertTrue(fixture.device.operations.isEmpty())
            assertFalse(fixture.device.hasListener(command))
        }
    }

    @Test
    fun execute_returnsNotSupportedWhenCccdIsMissing() = runTest {
        val fixture = GattFixture(properties = 0, descriptorId = "00002901-0000-1000-8000-00805f9b34fb")
        val result = FakeResult()
        val command = StopNotificationsCommand(fixture.manager, fixture.arguments, result)
        command.execute()
        assertEquals("NotSupportedError", result.errorCode)
        assertEquals(1, result.replyCount)
        assertTrue(fixture.device.operations.isEmpty())
        assertFalse(fixture.device.hasListener(command))
    }

    @Test
    fun execute_returnsNetworkErrorWhenDisablingLocalNotificationsIsRejected() = runTest {
        val fixture = GattFixture(properties = 0)
        fixture.device.notificationReturnValue = false
        val result = FakeResult()
        val command = StopNotificationsCommand(fixture.manager, fixture.arguments, result)
        command.execute()
        assertEquals("NetworkError", result.errorCode)
        assertEquals(1, result.replyCount)
        assertEquals(listOf("notification"), fixture.device.operations)
        assertNull(fixture.device.writtenDescriptor)
        assertFalse(fixture.device.hasListener(command))
    }

    @Test
    fun execute_returnsNetworkErrorWhenDescriptorWriteIsRejected() = runTest {
        val fixture = GattFixture(properties = 0)
        fixture.device.descriptorReturnValue = false
        val result = FakeResult()
        val command = StopNotificationsCommand(fixture.manager, fixture.arguments, result)
        command.execute()
        assertEquals("NetworkError", result.errorCode)
        assertEquals(1, result.replyCount)
        assertEquals(listOf("notification", "descriptor"), fixture.device.operations)
        assertFalse(fixture.device.hasListener(command))
    }

    @Test
    fun execute_returnsNetworkErrorForFailedDescriptorCallback() = runTest {
        val fixture = GattFixture(properties = 0)
        val result = FakeResult()
        val command = StopNotificationsCommand(fixture.manager, fixture.arguments, result)
        val job = async { command.execute() }
        runCurrent()
        fixture.device.emitDescriptorWrite(fixture.descriptor, GATT_FAILURE)
        withTimeout(1_000) { job.await() }
        assertEquals("NetworkError", result.errorCode)
        assertNull(result.successValue)
        assertFalse(fixture.device.hasListener(command))
        command.onDescriptorWrite(fixture.device, fixture.descriptor, GATT_SUCCESS)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_ignoresDescriptorCallbacksForOtherTargets() = runTest {
        val fixture = GattFixture(properties = 0)
        val result = FakeResult()
        val command = StopNotificationsCommand(fixture.manager, fixture.arguments, result)
        val job = async { command.execute() }
        runCurrent()
        command.onDescriptorWrite(FakeDeviceManager("11:22:33:44:55:66"), fixture.descriptor, GATT_SUCCESS)
        assertEquals(0, result.replyCount)
        for (mismatch in listOf(
            GattFixture(serviceId = "0000180a-0000-1000-8000-00805f9b34fb"),
            GattFixture(characteristicId = "00002a00-0000-1000-8000-00805f9b34fb"),
            GattFixture(descriptorId = "00002901-0000-1000-8000-00805f9b34fb")
        )) {
            command.onDescriptorWrite(mismatch.device, mismatch.descriptor, GATT_SUCCESS)
            runCurrent()
            assertEquals(0, result.replyCount)
            assertFalse(job.isCompleted)
            assertTrue(fixture.device.hasListener(command))
        }
        fixture.device.emitDescriptorWrite(fixture.descriptor, GATT_SUCCESS)
        withTimeout(1_000) { job.await() }
        assertEquals(1, result.successCount)
        assertFalse(fixture.device.hasListener(command))
    }
}

