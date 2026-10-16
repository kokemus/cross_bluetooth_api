package io.github.kokemus.cross_bluetooth_api.models

import android.bluetooth.le.ScanRecord
import android.bluetooth.le.ScanResult
import android.os.ParcelUuid
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import android.bluetooth.BluetoothManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [35])
class RequestDeviceOptionsTest {
    private fun options(vararg filters: Filter) = RequestDeviceOptions(filters.toList(), null, false)

    private fun matches(options: RequestDeviceOptions, result: ScanResult): Boolean =
        options.matches(result)

    private fun scanResult(
        name: String? = null,
        services: List<Int> = emptyList(),
        manufacturers: Map<Int, List<Int>> = emptyMap()
    ): ScanResult {
        val bytes = mutableListOf<Byte>()
        fun addData(type: Int, data: ByteArray) {
            bytes.add((data.size + 1).toByte())
            bytes.add(type.toByte())
            bytes.addAll(data.toList())
        }
        name?.let { addData(0x09, it.toByteArray()) }
        if (services.isNotEmpty()) {
            addData(0x03, services.flatMap { listOf(it.toByte(), (it shr 8).toByte()) }.toByteArray())
        }
        manufacturers.forEach { (identifier, data) ->
            addData(0xFF, (listOf(identifier.toByte(), (identifier shr 8).toByte()) + data.map { it.toByte() }).toByteArray())
        }
        bytes.add(0)
        val record = ScanRecord::class.java.getDeclaredMethod("parseFromBytes", ByteArray::class.java)
            .invoke(null, bytes.toByteArray()) as ScanRecord
        val context = ApplicationProvider.getApplicationContext<Context>()
        val adapter = requireNotNull(context.getSystemService(BluetoothManager::class.java).adapter)
        val device = adapter.getRemoteDevice("00:11:22:33:44:55")
        return ScanResult(device, 0, 0, 0, 0, 0, 0, -50, record, 0)
    }

    @Test
    fun nativeScanFilters_combinesFieldsWithinEachBranch() {
        val options = options(Filter(listOf("180D"), "Sensor", null, listOf(ManufacturerData(76))))
        val filters = options.nativeScanFilters()
        assertEquals(1, filters.size)
        assertEquals(filters, options.scannerFilters(filters))
        assertEquals("Sensor", filters.first().deviceName)
        assertEquals(ParcelUuid.fromString("0000180d-0000-1000-8000-00805f9b34fb"), filters.first().serviceUuid)
        assertEquals(76, filters.first().manufacturerId)
        assertFalse(options.requiresPostFiltering)
        assertTrue(filters.first().matches(scanResult("Sensor", listOf(0x180D), mapOf(76 to emptyList()))))
        assertFalse(filters.first().matches(scanResult("Other", listOf(0x180D), mapOf(76 to emptyList()))))
        assertFalse(filters.first().matches(scanResult("Sensor", manufacturers = mapOf(76 to emptyList()))))
        assertFalse(filters.first().matches(scanResult("Sensor", listOf(0x180D))))
    }

    @Test
    fun filters_useOrBetweenBranches() {
        val options = options(Filter(listOf("180D"), "Sensor", null), Filter(null, "Other", null))
        assertEquals(2, options.nativeScanFilters().size)
        assertTrue(matches(options, scanResult("Sensor", listOf(0x180D))))
        assertTrue(matches(options, scanResult("Other")))
        assertFalse(matches(options, scanResult("Sensor")))
    }

    @Test
    fun namePrefix_isPostFilteredNotTreatedAsExactName() {
        val options = options(Filter(null, null, "Sensor"))
        assertTrue(options.requiresPostFiltering)
        assertNull(options.filters?.first()?.nativeScanFilter())
        assertTrue(options.nativeScanFilters().isEmpty())
        assertNull(options.scannerFilters(options.nativeScanFilters()))
        assertTrue(matches(options, scanResult("Sensor 1")))
        assertTrue(matches(options, scanResult("Sensor")))
        assertFalse(matches(options, scanResult("sensor 1")))
        assertFalse(matches(options, scanResult("Other")))
        assertFalse(matches(options, scanResult()))
    }

    @Test
    fun namePrefix_fallsBackToCachedNameWhenAdvertisementHasNoName() {
        val options = options(Filter(null, null, "Sensor"))
        val result = scanResult()
        shadowOf(result.device).setName("Sensor cached")
        assertTrue(options.nativeScanFilters().isEmpty())
        assertEquals("Sensor cached", result.device.name)
        assertTrue(matches(options, result))
    }

    @Test
    fun namePrefix_prefersAdvertisementOverCachedName() {
        val options = options(Filter(null, null, "Sensor"))
        val result = scanResult("Other")
        shadowOf(result.device).setName("Sensor cached")
        assertFalse(matches(options, result))
    }

    @Test
    fun namePrefix_matchesGalaxyWatchFromSerializedOptions() {
        val options = RequestDeviceOptions.fromMap(mapOf(
            "filters" to listOf(mapOf("namePrefix" to "Gal", "services" to emptyList<String>())),
            "optionalServices" to emptyList<String>(),
            "acceptAllDevices" to false
        ))
        assertTrue(options.nativeScanFilters().isEmpty())
        assertTrue(options.matches(scanResult("Galaxy Watch8")))
        val result = scanResult()
        shadowOf(result.device).setName("Galaxy Watch8")
        assertTrue(options.matches(result))
    }

    @Test
    fun postFiltering_preservesNativeBranchAssociation() {
        val options = options(
            Filter(listOf("180D"), null, "Sensor"),
            Filter(listOf("180F"), null, "Other")
        )
        assertFalse(matches(options, scanResult("Other 1", listOf(0x180D))))
        assertFalse(matches(options, scanResult("Sensor 1", listOf(0x180F))))
        assertTrue(matches(options, scanResult("Sensor 1", listOf(0x180D))))
        assertTrue(matches(options, scanResult("Other 1", listOf(0x180F))))
    }

    @Test
    fun postFiltering_doesNotExcludeNativeOnlyBranch() {
        val options = options(Filter(null, null, "Sensor"), Filter(null, "Other", null))
        assertTrue(options.nativeScanFilters().isEmpty())
        assertNull(options.scannerFilters(options.nativeScanFilters()))
        assertTrue(matches(options, scanResult("Sensor 1")))
        assertTrue(matches(options, scanResult("Other")))
        assertFalse(matches(options, scanResult("Unrelated")))
    }

    @Test
    fun scannerFilters_mixedServiceAndPrefixBranchesScanWithoutNativeFilters() {
        val options = options(Filter(listOf("180D"), null, null), Filter(null, null, "Sensor"))
        val nativeFilters = options.nativeScanFilters()
        assertTrue(nativeFilters.isEmpty())
        assertNull(options.scannerFilters(nativeFilters))
        assertTrue(options.matches(scanResult("Sensor 1")))
        assertTrue(options.matches(scanResult("Other", listOf(0x180D))))
        assertFalse(options.matches(scanResult("Other")))
    }

    @Test
    fun scannerFilters_retainsConstrainedNativeBranches() {
        val options = options(Filter(listOf("180D"), null, "Sensor"), Filter(listOf("180F"), "Other", null))
        val nativeFilters = options.nativeScanFilters()
        assertEquals(nativeFilters, options.scannerFilters(nativeFilters))
    }

    @Test
    fun multipleServices_useFirstNativelyAndRequireAllAfterDiscovery() {
        val options = options(Filter(listOf("180D", "180F"), null, null))
        assertEquals(1, options.nativeScanFilters().size)
        assertTrue(options.requiresPostFiltering)
        assertFalse(matches(options, scanResult(services = listOf(0x180D))))
        assertFalse(matches(options, scanResult(services = listOf(0x180F))))
        assertTrue(matches(options, scanResult(services = listOf(0x180D, 0x180F))))
    }

    @Test
    fun manufacturerData_parsesAndUsesNativeMaskedPrefix() {
        val options = RequestDeviceOptions.fromMap(mapOf(
            "filters" to listOf(mapOf("manufacturerData" to listOf(mapOf(
                "companyIdentifier" to 0x1234, "dataPrefix" to listOf(0xA0, 0x05), "mask" to listOf(0xF0, 0xFF)
            ))))
        ))
        assertEquals(0x1234, options.filters?.first()?.manufacturerData?.first()?.companyIdentifier)
        assertFalse(options.requiresPostFiltering)
        assertTrue(matches(options, scanResult(manufacturers = mapOf(0x1234 to listOf(0xAB, 0x05, 0xFF)))))
        assertFalse(matches(options, scanResult(manufacturers = mapOf(0x1234 to listOf(0xAB, 0x06)))))
        assertFalse(matches(options, scanResult(manufacturers = mapOf(0x3412 to listOf(0xAB, 0x05)))))
        assertFalse(matches(options, scanResult(manufacturers = mapOf(0x1234 to listOf(0xAB)))))
        assertFalse(matches(options, scanResult()))
    }

    @Test
    fun manufacturerPrefix_withoutMaskUsesExactBytes() {
        val options = options(Filter(null, null, null, listOf(ManufacturerData(76, listOf(0xAB)))))
        assertTrue(matches(options, scanResult(manufacturers = mapOf(76 to listOf(0xAB)))))
        assertFalse(matches(options, scanResult(manufacturers = mapOf(76 to listOf(0xAC)))))
    }

    @Test
    fun multipleManufacturerConstraints_areAllRequired() {
        val options = options(Filter(null, null, null, listOf(
            ManufacturerData(76, listOf(1)), ManufacturerData(77, listOf(2))
        )))
        assertEquals(76, options.nativeScanFilters().first().manufacturerId)
        assertTrue(options.requiresPostFiltering)
        assertFalse(matches(options, scanResult(manufacturers = mapOf(76 to listOf(1)))))
        assertFalse(matches(options, scanResult(manufacturers = mapOf(76 to listOf(1), 77 to listOf(3)))))
        assertTrue(matches(options, scanResult(manufacturers = mapOf(76 to listOf(1), 77 to listOf(2)))))
    }

    @Test
    fun acceptAllDevices_bypassesBothNativeAndPostFiltering() {
        val options = options(Filter(listOf("180D"), "Sensor", "Sen")).copy(acceptAllDevices = true)
        assertTrue(options.nativeScanFilters().isEmpty())
        assertNull(options.scannerFilters(options.nativeScanFilters()))
        assertFalse(options.requiresPostFiltering)
        assertTrue(matches(options, scanResult()))
    }

    @Test
    fun noFilters_doesNotMatchUnlessAcceptAllDevices() {
        for (filters in listOf(null, emptyList<Filter>())) {
            val options = RequestDeviceOptions(filters, null, false)
            assertTrue(options.requiresPostFiltering)
            assertFalse(matches(options, scanResult("Sensor")))
        }
    }

    @Test
    fun optionalServicesAndProductData_doNotConstrainDiscovery() {
        val options = RequestDeviceOptions.fromMap(mapOf(
            "filters" to listOf(mapOf("name" to "Sensor", "productData" to mapOf("name" to "Product", "image" to "sensor.png"))),
            "optionalServices" to listOf("180D")
        ))
        assertFalse(options.requiresPostFiltering)
        assertTrue(matches(options, scanResult("Sensor")))
    }

    @Test
    fun nativeServices_supportShortAndFullUuidFormats() {
        val filters = listOf("180D", "0000180D", "0000180D-0000-1000-8000-00805F9B34FB")
            .map { Filter(listOf(it), null, null).nativeScanFilter()!! }
        assertEquals(1, filters.map { it.serviceUuid }.distinct().size)
        assertTrue(filters.all { it.matches(scanResult(services = listOf(0x180D))) })
    }
}