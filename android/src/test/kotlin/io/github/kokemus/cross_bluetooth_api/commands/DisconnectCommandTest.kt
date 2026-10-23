package io.github.kokemus.cross_bluetooth_api.commands

import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeBluetoothManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeDeviceManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DisconnectCommandTest {
    private val deviceId = "AA:BB:CC:DD:EE:FF"

    @Test
    fun execute_waitsForTargetDisconnectAndCompletesOnlyOnce() = runTest {
        val manager = FakeBluetoothManager()
        manager.devices[deviceId] = FakeDeviceManager(deviceId)
        val result = FakeResult()
        val command = DisconnectCommand(manager, mapOf("id" to deviceId), result)
        val job = async { command.execute() }
        runCurrent()
        assertEquals(listOf(deviceId), manager.disconnectedIds)
        assertFalse(job.isCompleted)
        manager.emitDisconnected("11:22:33:44:55:66")
        assertEquals(0, result.replyCount)
        manager.emitDisconnected(deviceId)
        job.await()
        assertEquals(true, result.successValue)
        assertFalse(manager.hasListener(command))
        command.onDisconnected(deviceId)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_returnsNotFoundForMissingInvalidOrUnknownDevice() = runTest {
        for (arguments in listOf(emptyMap(), mapOf("id" to 123), mapOf("id" to deviceId))) {
            val manager = FakeBluetoothManager()
            val result = FakeResult()
            val command = DisconnectCommand(manager, arguments, result)
            command.execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
            assertTrue(manager.disconnectedIds.isEmpty())
            assertFalse(manager.hasListener(command))
        }
    }

    @Test
    fun execute_returnsNetworkErrorWhenDisconnectIsRejected() = runTest {
        val manager = FakeBluetoothManager(disconnectReturnValue = false)
        manager.devices[deviceId] = FakeDeviceManager(deviceId)
        val result = FakeResult()
        val command = DisconnectCommand(manager, mapOf("id" to deviceId), result)
        command.execute()
        assertEquals("NetworkError", result.errorCode)
        assertEquals(listOf(deviceId), manager.disconnectedIds)
        assertFalse(manager.hasListener(command))
        command.onDisconnected(deviceId)
        assertEquals(1, result.replyCount)
    }

}

