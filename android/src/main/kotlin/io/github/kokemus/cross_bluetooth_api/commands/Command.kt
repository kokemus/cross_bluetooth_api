package io.github.kokemus.cross_bluetooth_api.commands

enum class CommandId(val method: String) {
    REQUEST_DEVICE("requestDevice"),
    CONNECT("connect"),
    DISCONNECT("disconnect"),
    GET_PRIMARY_SERVICE("getPrimaryService"),
    GET_CHARACTERISTIC("getCharacteristic"),
    READ_VALUE("readValue"),
    WRITE_VALUE_WITHOUT_RESPONSE("writeValueWithoutResponse"),
    WRITE_VALUE_WITH_RESPONSE("writeValueWithResponse"),
    START_NOTIFICATIONS("startNotifications"),
    STOP_NOTIFICATIONS("stopNotifications");

    companion object {
        fun fromMethod(method: String): CommandId? = entries.find { it.method == method }
    }
}

interface Command {
    suspend fun execute()
}
