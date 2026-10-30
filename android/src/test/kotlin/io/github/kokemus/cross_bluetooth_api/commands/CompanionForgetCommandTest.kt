package io.github.kokemus.cross_bluetooth_api.commands

import android.companion.CompanionDeviceManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
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

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class CompanionForgetCommandTest {
    private lateinit var context: Context
    private lateinit var manager: CompanionDeviceManager
    private val address = "AA:BB:CC:DD:EE:FF"

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        manager = context.getSystemService(CompanionDeviceManager::class.java)
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
        CompanionForgetCommand(manager, mapOf("id" to address), result).execute()
        assertEquals(1, result.successCount)
        assertTrue(manager.myAssociations.isEmpty())
        val again = FakeResult()
        CompanionForgetCommand(manager, mapOf("id" to address), again).execute()
        assertEquals(1, again.successCount)
    }

    @Test
    @Config(sdk = [26, 32])
    @Suppress("DEPRECATION")
    fun execute_disassociatesLegacyMacAddress() = runTest {
        shadowOf(manager).addAssociation(address)
        val result = FakeResult()
        CompanionForgetCommand(manager, mapOf("id" to address), result).execute()
        assertEquals(1, result.successCount)
        assertTrue(manager.associations.isEmpty())
    }

    @Test
    fun execute_returnsErrorForInvalidDeviceId() = runTest {
        for (arguments in listOf(emptyMap(), mapOf("id" to "invalid"))) {
            val result = FakeResult()
            CompanionForgetCommand(manager, arguments, result).execute()
            assertEquals("NotFoundError", result.errorCode)
        }
    }
}
