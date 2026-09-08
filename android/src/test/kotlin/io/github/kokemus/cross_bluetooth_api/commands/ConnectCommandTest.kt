package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeBluetoothManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeDeviceManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.async
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ConnectCommandTest {

    @Test
    fun execute_returnsSuccessTrue_whenConnectedAndServicesDiscovered() = runTest {
        val result = FakeResult()
        val manager = FakeBluetoothManager(connectReturnValue = true)
        val deviceManager = FakeDeviceManager(deviceId = "AA:BB:CC:DD")

        val command = ConnectCommand(
            manager = manager,
            arguments = mapOf("id" to "AA:BB:CC:DD"),
            pendingResult = result
        )

        val job = async { command.execute() }
        runCurrent()

        manager.emitConnected(deviceManager)
        deviceManager.emitServicesDiscovered(GATT_SUCCESS)
        job.await()

        assertEquals(true, result.successValue)
        assertNull(result.errorCode)
        assertFalse(manager.hasListener(command))
        assertFalse(deviceManager.hasListener(command))
    }

    @Test
    fun execute_returnsNetworkError_whenConnectReturnsFalse() = runTest {
        val result = FakeResult()
        val manager = FakeBluetoothManager(connectReturnValue = false)

        val command = ConnectCommand(
            manager = manager,
            arguments = mapOf("id" to "AA:BB:CC:DD"),
            pendingResult = result
        )

        command.execute()

        assertEquals("NetworkError", result.errorCode)
        assertNull(result.successValue)
        assertFalse(manager.hasListener(command))
    }

    @Test
    fun execute_returnsNetworkError_whenConnectFailedEventArrives() = runTest {
        val result = FakeResult()
        val manager = FakeBluetoothManager(connectReturnValue = true)

        val command = ConnectCommand(
            manager = manager,
            arguments = mapOf("id" to "AA:BB:CC:DD"),
            pendingResult = result
        )

        val job = async { command.execute() }
        runCurrent()

        manager.emitConnectFailed("AA:BB:CC:DD")
        job.await()

        assertEquals("NetworkError", result.errorCode)
        assertNull(result.successValue)
        assertFalse(manager.hasListener(command))
    }

    @Test
    fun execute_ignoresEventsFromOtherDevices() = runTest {
        val result = FakeResult()
        val manager = FakeBluetoothManager(connectReturnValue = true)
        val targetDevice = FakeDeviceManager(deviceId = "AA:BB:CC:DD")
        val otherDevice = FakeDeviceManager(deviceId = "11:22:33:44")

        val command = ConnectCommand(
            manager = manager,
            arguments = mapOf("id" to "AA:BB:CC:DD"),
            pendingResult = result
        )

        val job = async { command.execute() }
        runCurrent()

        manager.emitConnected(otherDevice)
        otherDevice.emitServicesDiscovered(GATT_SUCCESS)
        assertNull(result.successValue)
        assertNull(result.errorCode)

        manager.emitConnected(targetDevice)
        targetDevice.emitServicesDiscovered(GATT_SUCCESS)
        job.await()

        assertEquals(true, result.successValue)
        assertNull(result.errorCode)
        assertFalse(manager.hasListener(command))
        assertFalse(targetDevice.hasListener(command))
    }
}
