package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothGattService
import io.github.kokemus.cross_bluetooth_api.testing.GattFixture
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class GetPrimaryServiceCommandTest {
    @Test
    fun execute_returnsServiceUuidAndPrimaryFlag() = runTest {
        for (type in listOf(BluetoothGattService.SERVICE_TYPE_PRIMARY, BluetoothGattService.SERVICE_TYPE_SECONDARY)) {
            val fixture = GattFixture(serviceType = type)
            val result = FakeResult()
            val command = GetPrimaryServiceCommand(fixture.manager, fixture.arguments, result)
            command.execute()
            assertEquals(
                mapOf("uuid" to fixture.service.uuid.toString(), "isPrimary" to (type == BluetoothGattService.SERVICE_TYPE_PRIMARY)),
                result.successValue
            )
            assertNull(result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_validatesEachRequiredArgument() = runTest {
        val fixture = GattFixture()
        val arguments = fixture.arguments - "characteristic"
        for (key in arguments.keys) {
            for (invalid in listOf(arguments - key, arguments + (key to 123))) {
                val result = FakeResult()
                val command = GetPrimaryServiceCommand(fixture.manager, invalid, result)
                command.execute()
                assertEquals("NotFoundError", result.errorCode)
                assertEquals(1, result.replyCount)
            }
        }
    }

    @Test
    fun execute_returnsNotFoundWhenDeviceOrServiceIsMissing() = runTest {
        for (missingDevice in listOf(true, false)) {
            val fixture = GattFixture()
            if (missingDevice) fixture.manager.devices.clear() else fixture.device.services.clear()
            val result = FakeResult()
            val command = GetPrimaryServiceCommand(fixture.manager, fixture.arguments, result)
            command.execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_doesNotReturnAnotherService() = runTest {
        val fixture = GattFixture()
        val result = FakeResult()
        val arguments = fixture.arguments + ("serviceUUID" to "0000180a-0000-1000-8000-00805f9b34fb")
        val command = GetPrimaryServiceCommand(fixture.manager, arguments, result)
        command.execute()
        assertEquals("NotFoundError", result.errorCode)
        assertEquals(1, result.replyCount)
    }
}

