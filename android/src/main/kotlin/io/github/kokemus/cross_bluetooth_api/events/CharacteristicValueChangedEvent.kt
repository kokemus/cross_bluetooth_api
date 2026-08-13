package io.github.kokemus.cross_bluetooth_api.events

class CharacteristicValueChangedEvent(
    private val deviceId: String,
    private val serviceUUID: String,
    private val characteristicUUID: String,
    private val value: ByteArray
) : Event(EventName.CHARACTERISTIC_VALUE_CHANGED) {
    override fun toMap(): Map<String, Any> {
        return super.toMap() + mapOf(
            "deviceId" to deviceId,
            "serviceUUID" to serviceUUID,
            "characteristicUUID" to characteristicUUID,
            "value" to value
        )
    }
}
