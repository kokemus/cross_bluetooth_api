package io.github.kokemus.cross_bluetooth_api.events

class GattServerDisconnectedEvent(private val deviceId: String) :
    Event(EventName.GATT_SERVER_DISCONNECTED) {
    override fun toMap(): Map<String, Any> {
        return super.toMap() + mapOf("deviceId" to deviceId)
    }
}
