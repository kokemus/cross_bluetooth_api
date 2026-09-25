import Foundation
import Flutter
import CoreBluetooth

public class WriteValueWithoutResponseCommand: BaseCommand {
    private let manager: BluetoothManager

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .writeValueWithoutResponse, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        guard
            let deviceId = arguments["deviceId"] as? String,
            let serviceUUIDString = arguments["serviceUUID"] as? String,
            let characteristicUUIDString = arguments["characteristic"] as? String,
            let value = arguments["value"] as? Data,
            let deviceManager = manager.deviceManager(for: deviceId)
        else {
            pendingResult(FlutterError.networkError())
            return
        }

        let serviceUUID = CBUUID(string: serviceUUIDString)
        let characteristicUUID = CBUUID(string: characteristicUUIDString)
        guard let characteristic = deviceManager.getCharacteristic(
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID
        ) else {
            pendingResult(FlutterError.notFoundError())
            return
        }

        deviceManager.writeValue(value, for: characteristic, type: .withoutResponse)
        pendingResult(value)
    }
}
