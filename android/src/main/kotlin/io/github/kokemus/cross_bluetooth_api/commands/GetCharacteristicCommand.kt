package io.github.kokemus.cross_bluetooth_api.commands

import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.toMap
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.flutter.plugin.common.MethodChannel

class GetCharacteristicCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.GET_CHARACTERISTIC, arguments, pendingResult) {
    override suspend fun execute() {
        val deviceId = arguments["deviceId"] as? String
        val serviceUUID = arguments["serviceUUID"] as? String
        val characteristicUUID = arguments["characteristic"] as? String
        if (deviceId == null || serviceUUID == null || characteristicUUID == null) {
            pendingResult.notFoundError()
            return
        }

        val characteristic = manager.deviceManager(deviceId)?.getCharacteristic(serviceUUID, characteristicUUID)
        if (characteristic != null) {
            pendingResult.success(characteristic.toMap())
        } else {
            pendingResult.notFoundError()
        }
    }
}
