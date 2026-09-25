import Foundation
import Flutter
import CoreBluetooth

public class GetPrimaryServiceCommand: BaseCommand, DeviceManagerDelegate {
    private let manager: BluetoothManager
    private var deviceManager: DeviceManager?
    private var continuation: CheckedContinuation<Void, Never>?
    private var targetDeviceId: String?
    private var targetServiceUUID: CBUUID?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .getPrimaryService, arguments: arguments, pendingResult: pendingResult)
    }

    deinit {
        if let deviceManager {
            deviceManager.removeDelegate(self)
        }
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            guard let deviceId = arguments["deviceId"] as? String,
                  let serviceUUIDString = arguments["serviceUUID"] as? String,
                  let deviceManager = manager.deviceManager(for: deviceId) else {
                pendingResult(FlutterError.networkError())
                continuation.resume()
                return
            }

            self.deviceManager = deviceManager
            deviceManager.addDelegate(self)
            targetDeviceId = deviceId
            targetServiceUUID = CBUUID(string: serviceUUIDString)
            deviceManager.discoverServices([targetServiceUUID!])
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        defer {
            continuation?.resume()
        }

        if error != nil {
            pendingResult(FlutterError.notFoundError())
            return
        }

        guard
            peripheral.identifier.uuidString == targetDeviceId,
            let serviceUUID = targetServiceUUID,
            let service = deviceManager?.getService(serviceUUID)
        else {
            pendingResult(FlutterError.notFoundError())
            return
        }

        pendingResult(service.toMap())
    }
}
