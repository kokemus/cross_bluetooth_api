package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothAdapter
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerImp
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeBluetoothManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class GetDevicesCommandTest {
    @Test
    fun execute_returnsAllDevicesIncludingUnnamedDevices() = runTest {
        val manager = FakeBluetoothManager().apply {
            bondedDevices = listOf(Device("AA:BB:CC:DD:EE:FF", "Sensor"), Device("AA:BB:CC:DD:EE:00", null))
        }
        val result = FakeResult()
        GetDevicesCommand(manager, emptyMap(), result).execute()
        assertEquals(manager.bondedDevices.map { it.toMap() }, result.successValue)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_returnsEmptyList() = runTest {
        val result = FakeResult()
        GetDevicesCommand(FakeBluetoothManager(), emptyMap(), result).execute()
        assertEquals(emptyList<Any>(), result.successValue)
        assertEquals(1, result.replyCount)
    }

    @Test
    fun execute_reportsPermissionSupportAndStateErrors() = runTest {
        for ((error, code) in listOf(
            SecurityException() to "SecurityError",
            UnsupportedOperationException() to "NotSupportedError",
            IllegalStateException() to "InvalidStateError"
        )) {
            val manager = FakeBluetoothManager().apply { getDevicesException = error }
            val result = FakeResult()
            GetDevicesCommand(manager, emptyMap(), result).execute()
            assertEquals(code, result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun manager_returnsAdapterBondedDevicesWithoutGattConnection() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val systemManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
        val adapter = systemManager.adapter
        shadowOf(adapter).setState(BluetoothAdapter.STATE_ON)
        val named = adapter.getRemoteDevice("AA:BB:CC:DD:EE:FF")
        val unnamed = adapter.getRemoteDevice("AA:BB:CC:DD:EE:00")
        shadowOf(named).setName("Sensor")
        shadowOf(adapter).setBondedDevices(linkedSetOf(named, unnamed))
        val manager = BluetoothManagerImp(context)

        assertEquals(
            setOf(Device(named.address, "Sensor"), Device(unnamed.address, null)),
            manager.getDevices().toSet()
        )
        assertNull(manager.deviceManager(named.address))
        shadowOf(adapter).setBondedDevices(emptySet())
        assertTrue(manager.getDevices().isEmpty())
    }

    @Test
    fun manager_rejectsDisabledBluetooth() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val systemManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
        shadowOf(systemManager.adapter).setState(BluetoothAdapter.STATE_OFF)
        assertThrows(IllegalStateException::class.java) { BluetoothManagerImp(context).getDevices() }
    }
}
