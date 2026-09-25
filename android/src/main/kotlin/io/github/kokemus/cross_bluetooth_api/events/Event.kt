package io.github.kokemus.cross_bluetooth_api.events

enum class EventName(val rawValue: String) {
    GATT_SERVER_DISCONNECTED("gattserverdisconnected"),
    CHARACTERISTIC_VALUE_CHANGED("characteristicvaluechanged")
}

open class Event(private val name: EventName) {
    open fun toMap(): Map<String, Any> {
        return mapOf("name" to name.rawValue)
    }
}
