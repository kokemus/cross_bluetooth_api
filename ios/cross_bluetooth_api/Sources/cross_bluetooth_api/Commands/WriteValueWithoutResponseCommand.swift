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
            pendingResult(writeValueWithoutResponseNetworkError)
            return
        }

        let peripheral = deviceManager.peripheral

        let serviceUUID = CBUUID(string: serviceUUIDString)
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            pendingResult(writeValueWithoutResponseNotFoundError)
            return
        }

        let characteristicUUID = CBUUID(string: characteristicUUIDString)
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) else {
            pendingResult(writeValueWithoutResponseNotFoundError)
            return
        }

        peripheral.writeValue(value, for: characteristic, type: .withoutResponse)
        pendingResult(value)
    }
}

private let writeValueWithoutResponseNetworkError = FlutterError(
    code: "NetworkError",
    message: "NetworkError: A network error occurred.",
    details: nil
)

private let writeValueWithoutResponseNotFoundError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
    details: nil
)
