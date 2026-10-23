import Foundation
import Flutter
import CoreBluetooth

public class DisconnectCommand: BaseCommand, BluetoothManagerDelegete {
    private let manager: BluetoothManager
    private var targetDeviceId: String?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .disconnect, arguments: arguments, pendingResult: pendingResult)
    }

    deinit {
        manager.removeDelegate(self)
    }

    override func removeDelegates() {
        manager.removeDelegate(self)
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            guard let deviceId = arguments["id"] as? String else {
                complete(FlutterError.networkError())
                return
            }

            targetDeviceId = deviceId
            manager.addDelegate(self)
            if !manager.disconnect(deviceId) {
                complete(FlutterError.networkError())
            }
        }
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard continuation != nil, peripheral.identifier.uuidString == targetDeviceId else {
            return
        }

        if error != nil {
            complete(FlutterError.networkError())
        } else {
            complete(Device.fromPeripheral(peripheral).toMap())
        }
    }
}
