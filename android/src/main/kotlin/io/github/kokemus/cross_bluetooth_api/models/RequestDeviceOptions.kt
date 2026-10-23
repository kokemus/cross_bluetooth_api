package io.github.kokemus.cross_bluetooth_api.models

import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.os.ParcelUuid
import java.util.UUID

private fun serviceUuid(service: String): ParcelUuid {
    val expanded = when (service.length) {
        4 -> "0000$service-0000-1000-8000-00805f9b34fb"
        8 -> "$service-0000-1000-8000-00805f9b34fb"
        else -> service
    }
    return ParcelUuid(UUID.fromString(expanded))
}

data class ManufacturerData(
    val companyIdentifier: Int,
    val dataPrefix: List<Int>? = null,
    val mask: List<Int>? = null
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): ManufacturerData = ManufacturerData(
            companyIdentifier = (map.getValue("companyIdentifier") as Number).toInt(),
            dataPrefix = map["dataPrefix"] as? List<Int>,
            mask = map["mask"] as? List<Int>
        )
    }

    fun applyTo(builder: ScanFilter.Builder): ScanFilter.Builder {
        require(companyIdentifier in 0..65535)
        val prefix = dataPrefix.orEmpty()
        require(prefix.all { it in 0..255 })
        require(mask == null || (mask.size == prefix.size && mask.all { it in 0..255 }))
        val bytes = prefix.map { it.toByte() }.toByteArray()
        return if (mask == null) {
            builder.setManufacturerData(companyIdentifier, bytes)
        } else {
            builder.setManufacturerData(companyIdentifier, bytes, mask.map { it.toByte() }.toByteArray())
        }
    }
}

data class Filter(
    val services: List<String>?,
    val name: String?,
    val namePrefix: String?,
    val manufacturerData: List<ManufacturerData>? = null
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): Filter = Filter(
            services = if (map.containsKey("services")) map.getValue("services") as? List<String> else null,
            name = if (map.containsKey("name")) map.getValue("name") as? String else null,
            namePrefix = if (map.containsKey("namePrefix")) map.getValue("namePrefix") as? String else null,
            manufacturerData = (map["manufacturerData"] as? List<Map<String, Any>>)?.map { ManufacturerData.fromMap(it) }
        )
    }

    val requiresPostFiltering: Boolean
        get() = namePrefix != null || (services?.size ?: 0) > 1 || (manufacturerData?.size ?: 0) > 1

    private val nativeFilter: ScanFilter? by lazy {
        if (services.isNullOrEmpty() && name == null && manufacturerData.isNullOrEmpty()) {
            null
        } else {
            val builder = ScanFilter.Builder()
            services?.firstOrNull()?.let { builder.setServiceUuid(serviceUuid(it)) }
            name?.let { builder.setDeviceName(it) }
            manufacturerData?.firstOrNull()?.applyTo(builder)
            builder.build()
        }
    }

    fun nativeScanFilter(): ScanFilter? = nativeFilter

    fun matchesRemaining(result: ScanResult): Boolean {
        val record = result.scanRecord
        if (namePrefix != null) {
            val deviceName = record?.deviceName ?: try {
                result.device.name
            } catch (_: SecurityException) {
                null
            }
            if (deviceName?.startsWith(namePrefix) != true) return false
        }
        if (services.orEmpty().drop(1).any { record?.serviceUuids?.contains(serviceUuid(it)) != true }) return false
        return manufacturerData.orEmpty().drop(1).all {
            it.applyTo(ScanFilter.Builder()).build().matches(result)
        }
    }
}

data class RequestDeviceOptions(
    val filters: List<Filter>?,
    val optionalServices: List<String>?,
    val acceptAllDevices: Boolean
) {
    val requiresPostFiltering: Boolean
        get() = !acceptAllDevices && (filters.isNullOrEmpty() || filters.any { it.requiresPostFiltering })

    fun nativeScanFilters(): List<ScanFilter> {
        if (acceptAllDevices) return emptyList()
        val nativeFilters = filters.orEmpty().map { it.nativeScanFilter() }
        return if (nativeFilters.any { it == null }) emptyList() else nativeFilters.filterNotNull()
    }

    fun scannerFilters(nativeFilters: List<ScanFilter>): List<ScanFilter>? =
        nativeFilters.takeIf { it.isNotEmpty() }

    fun matches(result: ScanResult): Boolean =
        acceptAllDevices || filters.orEmpty().any { filter ->
            filter.nativeScanFilter()?.matches(result) != false && filter.matchesRemaining(result)
        }

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): RequestDeviceOptions = RequestDeviceOptions(
            filters = if (map.containsKey("filters")) (map.getValue("filters") as? List<Map<String, Any>>)?.map { Filter.fromMap(it) } else null,
            optionalServices = map.getOrDefault("optionalServices", emptyList<String>()) as? List<String>,
            acceptAllDevices = map.getOrDefault("acceptAllDevices", false) as Boolean

        )
    }
}
