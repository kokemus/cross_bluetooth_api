import Foundation
import Flutter
import CoreBluetooth

public class ReadValueCommand: BaseCommand, DeviceManagerDelegate {
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
        super.init(id: .readValue, arguments: arguments, pendingResult: pendingResult)
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
                pendingResult(FlutterError.networkError())
                continuation.resume()
                return
            }

            self.deviceManager = deviceManager
            deviceManager.addDelegate(self)

            let serviceUUID = CBUUID(string: serviceUUIDString)
            let characteristicUUID = CBUUID(string: characteristicUUIDString)
            guard let characteristic = deviceManager.getCharacteristic(
                serviceUUID: serviceUUID,
                characteristicUUID: characteristicUUID
            ) else {
                pendingResult(FlutterError.notFoundError())
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = characteristicUUID
            deviceManager.readValue(for: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer {
            continuation?.resume()
        }

        if error != nil {
            pendingResult(FlutterError.networkError())
            return
        }

        guard
            peripheral.identifier.uuidString == targetDeviceId,
            characteristic.service?.uuid == targetServiceUUID,
            characteristic.uuid == targetCharacteristicUUID
        else {
            pendingResult(FlutterError.notFoundError())
            return
        }

        pendingResult(characteristic.value)
    }
}
