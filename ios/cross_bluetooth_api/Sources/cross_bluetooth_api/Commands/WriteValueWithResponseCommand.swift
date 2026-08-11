import Foundation
import Flutter
import CoreBluetooth

public class WriteValueWithResponseCommand: BaseCommand, CBPeripheralDelegate {
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
        super.init(id: .writeValueWithResponse, arguments: arguments, pendingResult: pendingResult)
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            guard
                let deviceId = arguments["deviceId"] as? String,
                let serviceUUIDString = arguments["serviceUUID"] as? String,
                let characteristicUUIDString = arguments["characteristic"] as? String,
                let value = arguments["value"] as? Data,
                let peripheral = manager.peripheral(for: deviceId)
            else {
                pendingResult(writeValueWithResponseNetworkError)
                continuation.resume()
                return
            }

            let serviceUUID = CBUUID(string: serviceUUIDString)
            guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
                pendingResult(writeValueWithResponseNotFoundError)
                continuation.resume()
                return
            }

            let characteristicUUID = CBUUID(string: characteristicUUIDString)
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) else {
                pendingResult(writeValueWithResponseNotFoundError)
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = characteristicUUID

            peripheral.delegate = self
            peripheral.writeValue(value, for: characteristic, type: .withResponse)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        defer {
            continuation?.resume()
        }

        if error != nil {
            pendingResult(writeValueWithResponseNetworkError)
            return
        }

        guard
            peripheral.identifier.uuidString == targetDeviceId,
            characteristic.service?.uuid == targetServiceUUID,
            characteristic.uuid == targetCharacteristicUUID
        else {
            pendingResult(writeValueWithResponseNotFoundError)
            return
        }

        pendingResult(characteristic.value)
    }
}

private let writeValueWithResponseNetworkError = FlutterError(
    code: "NetworkError",
    message: "NetworkError: A network error occurred.",
    details: nil
)

private let writeValueWithResponseNotFoundError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
    details: nil
)
