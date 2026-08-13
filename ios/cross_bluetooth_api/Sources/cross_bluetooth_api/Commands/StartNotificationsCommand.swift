import Foundation
import Flutter
import CoreBluetooth

public class StartNotificationsCommand: BaseCommand, DeviceManagerDelegate {
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
        super.init(id: .startNotifications, arguments: arguments, pendingResult: pendingResult)
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
                pendingResult(startNotificationsNetworkError)
                continuation.resume()
                return
            }

            self.deviceManager = deviceManager
            deviceManager.addDelegate(self)

            let peripheral = deviceManager.peripheral
            let serviceUUID = CBUUID(string: serviceUUIDString)
            guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
                pendingResult(startNotificationsNotFoundError)
                continuation.resume()
                return
            }

            let characteristicUUID = CBUUID(string: characteristicUUIDString)
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) else {
                pendingResult(startNotificationsNotFoundError)
                continuation.resume()
                return
            }

            guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
                pendingResult(startNotificationsNotSupportedError)
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = characteristicUUID
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard
            peripheral.identifier.uuidString == targetDeviceId,
            characteristic.service?.uuid == targetServiceUUID,
            characteristic.uuid == targetCharacteristicUUID
        else {
            return
        }

        defer {
            continuation?.resume()
        }

        if error != nil {
            pendingResult(startNotificationsNetworkError)
            return
        }

        if !characteristic.isNotifying {
            pendingResult(startNotificationsNetworkError)
            return
        }

        pendingResult(true)
    }
}

private let startNotificationsNetworkError = FlutterError(
    code: "NetworkError",
    message: "NetworkError: A network error occurred.",
    details: nil
)

private let startNotificationsNotFoundError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
    details: nil
)

private let startNotificationsNotSupportedError = FlutterError(
    code: "NotSupportedError",
    message: "NotSupportedError: Characteristic does not support notifications.",
    details: nil
)
