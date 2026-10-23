import Foundation
import Flutter
import CoreBluetooth

public class GetCharacteristicCommand: BaseCommand, DeviceManagerDelegate {
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
        super.init(id: .getCharacteristic, arguments: arguments, pendingResult: pendingResult)
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
            guard let service = deviceManager.getService(serviceUUID) else {
                complete(FlutterError.notFoundError())
                return
            }

            targetDeviceId = deviceId
            targetServiceUUID = serviceUUID
            targetCharacteristicUUID = CBUUID(string: characteristicUUIDString)
            deviceManager.discoverCharacteristics([targetCharacteristicUUID!], for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard continuation != nil,
              peripheral.identifier.uuidString == targetDeviceId,
              service.uuid == targetServiceUUID else { return }

        if error != nil {
            complete(FlutterError.notFoundError())
            return
        }

        guard
            let characteristicUUID = targetCharacteristicUUID,
            let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID })
        else {
            complete(FlutterError.notFoundError())
            return
        }

        complete(characteristic.toMap())
    }
}
