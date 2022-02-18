package io.github.kokemus.cross_bluetooth_api.models

data class Filter(
    val services: List<String>?,
    val name: String?,
    val namePrefix: String?
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): Filter = Filter(
            services = if (map.containsKey("services")) map.getValue("services") as? List<String> else null,
            name = if (map.containsKey("name")) map.getValue("name") as? String else null,
            namePrefix = if (map.containsKey("namePrefix")) map.getValue("namePrefix") as? String else null,
        )
    }
}

data class RequestDeviceOptions(
    val filters: List<Filter>?,
    val optionalServices: List<String>?,
    val acceptAllDevices: Boolean
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): RequestDeviceOptions = RequestDeviceOptions(
            filters = if (map.containsKey("filters")) (map.getValue("filters") as? List<Map<String, Any>>)?.map { Filter.fromMap(it) } else null,
            optionalServices = map.getOrDefault("optionalServices", emptyList<String>()) as? List<String>,
            acceptAllDevices = map.getOrDefault("acceptAllDevices", false) as Boolean

        )
    }
}
