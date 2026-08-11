import Foundation
import Flutter
import CoreBluetooth

public class GetCharacteristicCommand: BaseCommand, CBPeripheralDelegate {
    private let manager: BluetoothManager
    private var continuation: CheckedContinuation<Void, Never>?
    private var targetDeviceId: String?
    private var targetServiceUUID: CBUUID?
    private var targetCharacteristicUUID: CBUUID?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .getCharacteristic, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            guard
                let deviceId = arguments["deviceId"] as? String,
                let serviceUUIDString = arguments["serviceUUID"] as? String,
                let characteristicUUIDString = arguments["characteristic"] as? String,
                let peripheral = manager.peripheral(for: deviceId)
            else {
                pendingResult(getCharacteristicNetworkError)
                continuation.resume()
                return
            }

            let serviceUUID = CBUUID(string: serviceUUIDString)
            guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
                pendingResult(getCharacteristicNotFoundError)
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = CBUUID(string: characteristicUUIDString)

            peripheral.delegate = self
            peripheral.discoverCharacteristics([targetCharacteristicUUID!], for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        defer {
            continuation?.resume()
        }

        if error != nil {
            pendingResult(getCharacteristicNotFoundError)
            return
        }

        guard
            peripheral.identifier.uuidString == targetDeviceId,
            service.uuid == targetServiceUUID,
            let characteristicUUID = targetCharacteristicUUID,
            let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID })
        else {
            pendingResult(getCharacteristicNotFoundError)
            return
        }

        pendingResult(characteristic.toMap())
    }
}

private let getCharacteristicNetworkError = FlutterError(
    code: "NetworkError",
    message: "NetworkError: A network error occurred.",
    details: nil
)

private let getCharacteristicNotFoundError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
    details: nil
)
