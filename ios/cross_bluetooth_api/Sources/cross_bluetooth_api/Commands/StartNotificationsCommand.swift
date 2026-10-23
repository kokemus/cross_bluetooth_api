import Foundation
import Flutter
import CoreBluetooth

public class StartNotificationsCommand: BaseCommand, DeviceManagerDelegate {
    private let manager: BluetoothManager
    private var deviceManager: DeviceManager?
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

    override func removeDelegates() {
        deviceManager?.removeDelegate(self)
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
                complete(FlutterError.networkError())
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
                complete(FlutterError.notFoundError())
                return
            }

            guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
                complete(FlutterError.notSupportedError())
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = characteristicUUID
            deviceManager.setNotifyValue(true, for: characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard
            continuation != nil,
            peripheral.identifier.uuidString == targetDeviceId,
            characteristic.service?.uuid == targetServiceUUID,
            characteristic.uuid == targetCharacteristicUUID
        else {
            return
        }

        if error != nil {
            complete(FlutterError.networkError())
            return
        }

        if !characteristic.isNotifying {
            complete(FlutterError.networkError())
            return
        }

        complete(true)
    }
}
