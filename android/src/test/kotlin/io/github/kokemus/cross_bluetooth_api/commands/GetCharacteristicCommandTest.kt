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
class GetCharacteristicCommandTest {
    @Test
    fun execute_returnsOnlyCharacteristicUuid() = runTest {
        for (type in listOf(BluetoothGattService.SERVICE_TYPE_PRIMARY, BluetoothGattService.SERVICE_TYPE_SECONDARY)) {
            val fixture = GattFixture(serviceType = type)
            val result = FakeResult()
            val command = GetCharacteristicCommand(fixture.manager, fixture.arguments, result)
            command.execute()
            assertEquals(mapOf("uuid" to fixture.characteristic.uuid.toString()), result.successValue)
            assertNull(result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_validatesEachRequiredArgument() = runTest {
        val fixture = GattFixture()
        for (key in fixture.arguments.keys) {
            for (invalid in listOf(fixture.arguments - key, fixture.arguments + (key to 123))) {
                val result = FakeResult()
                val command = GetCharacteristicCommand(fixture.manager, invalid, result)
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
            val command = GetCharacteristicCommand(fixture.manager, fixture.arguments, result)
            command.execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_doesNotReturnItemsFromAnotherServiceOrCharacteristic() = runTest {
        val fixture = GattFixture()
        for (key in listOf("serviceUUID", "characteristic")) {
            val result = FakeResult()
            val arguments = fixture.arguments + (key to "0000180a-0000-1000-8000-00805f9b34fb")
            val command = GetCharacteristicCommand(fixture.manager, arguments, result)
            command.execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }
}

