import Foundation
import Flutter
import CoreBluetooth

public class DisconnectCommand: BaseCommand, BluetoothManagerDelegete {
    private let manager: BluetoothManager
    private var continuation: CheckedContinuation<Void, Never>?
    private var targetDeviceId: String?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .disconnect, arguments: arguments, pendingResult: pendingResult)

        manager.addDelegate(self)
    }

    deinit {
        manager.removeDelegate(self)
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            guard let deviceId = arguments["id"] as? String else {
                pendingResult(FlutterError.networkError())
                continuation.resume()
                return
            }

            targetDeviceId = deviceId
            if !manager.disconnect(deviceId) {
                pendingResult(FlutterError.networkError())
                continuation.resume()
            }
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier.uuidString == targetDeviceId else {
            return
        }

        if error != nil {
            pendingResult(FlutterError.networkError())
        } else {
            pendingResult(Device.fromPeripheral(peripheral).toMap())
        }
        continuation?.resume()
    }
}
