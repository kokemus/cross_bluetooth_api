import Foundation
import Flutter
import CoreBluetooth

public class GetCharacteristicCommand: BaseCommand, DeviceManagerDelegate {
    private let manager: BluetoothManager
    private var deviceManager: DeviceManager?
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

    deinit {
        if let deviceManager {
            deviceManager.removeDelegate(self)
        }
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            guard
                let deviceId = arguments["deviceId"] as? String,
                let serviceUUIDString = arguments["serviceUUID"] as? String,
                let characteristicUUIDString = arguments["characteristic"] as? String,
                let deviceManager = manager.deviceManager(for: deviceId)
            else {
                pendingResult(getCharacteristicNetworkError)
                continuation.resume()
                return
            }

            self.deviceManager = deviceManager
            deviceManager.addDelegate(self)

            let peripheral = deviceManager.peripheral

            let serviceUUID = CBUUID(string: serviceUUIDString)
            guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
                pendingResult(getCharacteristicNotFoundError)
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = CBUUID(string: characteristicUUIDString)
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
