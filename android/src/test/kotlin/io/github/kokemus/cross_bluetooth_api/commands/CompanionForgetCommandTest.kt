package io.github.kokemus.cross_bluetooth_api.commands

import android.bluetooth.BluetoothDevice
import android.companion.CompanionDeviceManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerImp
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeBluetoothManager
import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.AssociationInfoBuilder
import java.lang.reflect.InvocationTargetException

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class CompanionForgetCommandTest {
    private lateinit var context: Context
    private lateinit var manager: CompanionDeviceManager
    private lateinit var bluetoothManager: FakeBluetoothManager
    private val address = "AA:BB:CC:DD:EE:FF"

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        manager = context.getSystemService(CompanionDeviceManager::class.java)
        bluetoothManager = FakeBluetoothManager()
    }

    @Test
    fun execute_disassociatesDeviceAndIsIdempotent() = runTest {
        shadowOf(manager).addAssociation(AssociationInfoBuilder.newBuilder()
            .setId(1)
            .setUserId(0)
            .setPackageName(context.packageName)
            .setDeviceMacAddress(address)
            .setDisplayName("Tag")
            .build())
        val result = FakeResult()
        CompanionForgetCommand(manager, bluetoothManager, mapOf("id" to address), result).execute()
        assertEquals(1, result.successCount)
        assertTrue(manager.myAssociations.isEmpty())
        assertTrue(bluetoothManager.forgottenIds.isEmpty())
        val again = FakeResult()
        CompanionForgetCommand(manager, bluetoothManager, mapOf("id" to address), again).execute()
        assertEquals(1, again.successCount)
        assertEquals(listOf(address), bluetoothManager.forgottenIds)
    }

    @Test
    @Config(sdk = [26, 32])
    @Suppress("DEPRECATION")
    fun execute_disassociatesLegacyMacAddress() = runTest {
        shadowOf(manager).addAssociation(address.lowercase())
        val result = FakeResult()
        CompanionForgetCommand(manager, bluetoothManager, mapOf("id" to address), result).execute()
        assertEquals(1, result.successCount)
        assertTrue(manager.associations.isEmpty())
        assertTrue(bluetoothManager.forgottenIds.isEmpty())
    }

    @Test
    @Config(sdk = [26, 32, 35])
    fun execute_removesBondWhenAssociationDoesNotExistAndIsIdempotent() = runTest {
        val platformManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
        val device = platformManager.adapter.getRemoteDevice(address)
        shadowOf(device).setBondState(BluetoothDevice.BOND_BONDED)
        shadowOf(device).setCreatedBond(true)
        val bondManager = BluetoothManagerImp(context)

        repeat(2) {
            val result = FakeResult()
            CompanionForgetCommand(manager, bondManager, mapOf("id" to address), result).execute()
            assertEquals(BluetoothDevice.BOND_NONE, device.bondState)
            assertEquals(1, result.successCount)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    @Config(sdk = [26, 32, 35])
    @Suppress("DEPRECATION")
    fun execute_removesBondWithoutRemovingUnrelatedAssociation() = runTest {
        val otherAddress = "11:22:33:44:55:66"
        shadowOf(manager).addAssociation(otherAddress)
        val result = FakeResult()

        CompanionForgetCommand(manager, bluetoothManager, mapOf("id" to address), result).execute()

        assertEquals(listOf(address), bluetoothManager.forgottenIds)
        assertEquals(listOf(otherAddress), manager.associations)
        assertEquals(1, result.replyCount)
        assertEquals(1, result.successCount)
    }

    @Test
    @Config(sdk = [26, 32, 35])
    fun execute_reportsRejectedBondRemovalWithoutAssociation() = runTest {
        bluetoothManager.forgetReturnValue = false
        val result = FakeResult()

        CompanionForgetCommand(manager, bluetoothManager, mapOf("id" to address), result).execute()

        assertEquals("NetworkError", result.errorCode)
        assertEquals(1, result.replyCount)
    }

    @Test
    @Config(sdk = [26, 32, 35])
    fun execute_reportsBondRemovalErrorsWithoutAssociation() = runTest {
        val errors = listOf(
            SecurityException() to "SecurityError",
            InvocationTargetException(SecurityException()) to "SecurityError",
            NoSuchMethodException("removeBond") to "NotSupportedError",
            IllegalAccessException("removeBond") to "NotSupportedError",
            InvocationTargetException(IllegalStateException("Bond removal failed")) to "UnknownError"
        )
        for ((error, expectedCode) in errors) {
            bluetoothManager.forgetException = error
            val result = FakeResult()
            CompanionForgetCommand(manager, bluetoothManager, mapOf("id" to address), result).execute()
            assertEquals(expectedCode, result.errorCode)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun execute_returnsErrorForInvalidDeviceId() = runTest {
        for (arguments in listOf(emptyMap(), mapOf("id" to "invalid"))) {
            val result = FakeResult()
            CompanionForgetCommand(manager, bluetoothManager, arguments, result).execute()
            assertEquals("NotFoundError", result.errorCode)
            assertEquals(1, result.replyCount)
            assertTrue(bluetoothManager.forgottenIds.isEmpty())
        }
    }
}
