package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothGatt.GATT_FAILURE
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
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
class WriteValueWithResponseCommandTest {
    @Test
    fun execute_writesCopiedBytesWithResponseAndWaitsForCallback() = runTest {
        for (value in listOf(byteArrayOf(0, -1, 127), byteArrayOf())) {
            val fixture = GattFixture()
            val expected = value.copyOf()
            val result = FakeResult()
            val command = WriteValueWithResponseCommand(fixture.manager, fixture.arguments + ("value" to value), result)
            val job = async { command.execute() }
            runCurrent()
            assertFalse(job.isCompleted)
            assertEquals(0, result.replyCount)
            assertTrue(fixture.device.hasListener(command))
            assertEquals(listOf("write"), fixture.device.operations)
            assertSame(fixture.characteristic, fixture.device.writtenCharacteristic)
            assertEquals(WRITE_TYPE_DEFAULT, fixture.device.writtenType)
            assertArrayEquals(expected, fixture.device.writtenValue)
            assertNotSame(value, fixture.device.writtenValue)
            if (value.isNotEmpty()) value[0] = 42
            assertArrayEquals(expected, fixture.device.writtenValue)
            fixture.device.emitCharacteristicWrite(fixture.characteristic, GATT_SUCCESS)
            withTimeout(1_000) { job.await() }
            assertArrayEquals(expected, result.successValue as ByteArray)
            assertNull(result.errorCode)
            assertFalse(fixture.device.hasListener(command))
            command.onCharacteristicWrite(fixture.device, fixture.characteristic, GATT_FAILURE)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_validatesEveryRequiredArgument() = runTest {
        val fixture = GattFixture()
        val arguments = fixture.arguments + ("value" to byteArrayOf(1))
        for (key in arguments.keys) {
            for (invalid in listOf(arguments - key, arguments + (key to 123))) {
                val result = FakeResult()
                val command = WriteValueWithResponseCommand(fixture.manager, invalid, result)
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
            val fixture = GattFixture()
            var arguments = fixture.arguments + ("value" to byteArrayOf(1))
            when (missing) {
                0 -> fixture.manager.devices.clear()
                1 -> fixture.device.services.clear()
                2 -> arguments = arguments + ("characteristic" to "00002a00-0000-1000-8000-00805f9b34fb")
            }
            val result = FakeResult()
            val command = WriteValueWithResponseCommand(fixture.manager, arguments, result)
            command.execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
            assertTrue(fixture.device.operations.isEmpty())
            assertFalse(fixture.device.hasListener(command))
        }
    }

    @Test
    fun execute_returnsNetworkErrorWhenWriteIsRejected() = runTest {
        val fixture = GattFixture()
        fixture.device.writeReturnValue = false
        val result = FakeResult()
        val command = WriteValueWithResponseCommand(fixture.manager, fixture.arguments + ("value" to byteArrayOf(1)), result)
        command.execute()
        assertEquals("NetworkError", result.errorCode)
        assertEquals(1, result.replyCount)
        assertFalse(fixture.device.hasListener(command))
    }

    @Test
    fun execute_returnsNetworkErrorForFailedWriteCallback() = runTest {
        val fixture = GattFixture()
        val result = FakeResult()
        val command = WriteValueWithResponseCommand(fixture.manager, fixture.arguments + ("value" to byteArrayOf(1)), result)
        val job = async { command.execute() }
        runCurrent()
        fixture.device.emitCharacteristicWrite(fixture.characteristic, GATT_FAILURE)
        withTimeout(1_000) { job.await() }
        assertEquals("NetworkError", result.errorCode)
        assertNull(result.successValue)
        assertFalse(fixture.device.hasListener(command))
        command.onCharacteristicWrite(fixture.device, fixture.characteristic, GATT_SUCCESS)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_ignoresWriteCallbacksForOtherDevicesServicesAndCharacteristics() = runTest {
        val fixture = GattFixture()
        val result = FakeResult()
        val command = WriteValueWithResponseCommand(fixture.manager, fixture.arguments + ("value" to byteArrayOf(1)), result)
        val job = async { command.execute() }
        runCurrent()
        command.onCharacteristicWrite(FakeDeviceManager("11:22:33:44:55:66"), fixture.characteristic, GATT_SUCCESS)
        assertEquals(0, result.replyCount)
        for (mismatch in listOf(
            GattFixture(serviceId = "0000180a-0000-1000-8000-00805f9b34fb"),
            GattFixture(characteristicId = "00002a00-0000-1000-8000-00805f9b34fb")
        )) {
            command.onCharacteristicWrite(mismatch.device, mismatch.characteristic, GATT_SUCCESS)
            runCurrent()
            assertEquals(0, result.replyCount)
            assertFalse(job.isCompleted)
            assertTrue(fixture.device.hasListener(command))
        }
        fixture.device.emitCharacteristicWrite(fixture.characteristic, GATT_SUCCESS)
        withTimeout(1_000) { job.await() }
        assertEquals(1, result.successCount)
        assertFalse(fixture.device.hasListener(command))
    }
}

