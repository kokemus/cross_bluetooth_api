package io.github.kokemus.cross_bluetooth_api.commands

import io.github.kokemus.cross_bluetooth_api.extensions.notFoundError
import io.github.kokemus.cross_bluetooth_api.extensions.toMap
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.flutter.plugin.common.MethodChannel

class GetPrimaryServiceCommand(
    private val manager: BluetoothManager,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.GET_PRIMARY_SERVICE, arguments, pendingResult) {
    override suspend fun execute() {
        val deviceId = arguments["deviceId"] as? String
        val serviceUUID = arguments["serviceUUID"] as? String
        if (deviceId == null || serviceUUID == null) {
            pendingResult.notFoundError()
            return
        }

        val service = manager.deviceManager(deviceId)?.getService(serviceUUID)
        if (service != null) {
            pendingResult.success(service.toMap())
        } else {
            pendingResult.notFoundError()
        }
    }
}
