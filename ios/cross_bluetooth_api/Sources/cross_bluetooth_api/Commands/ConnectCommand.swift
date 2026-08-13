import Foundation
import Flutter
import CoreBluetooth

public class ConnectCommand: BaseCommand, BluetoothManagerDelegete {
    private let manager: BluetoothManager
    private var continuation: CheckedContinuation<Void, Never>?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .connect, arguments: arguments, pendingResult: pendingResult)
        
        manager.addDelegate(self)
    }
    
    deinit {
        manager.removeDelegate(self)
    }

    override func execute() async {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            guard let deviceId = arguments["id"] as? String,
                  let deviceManager = manager.retrieveDeviceManager(deviceId: deviceId) else {
                pendingResult(FlutterError.networkError())
                continuation.resume()
                return
            }

            manager.central.connect(deviceManager.peripheral, options: nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        pendingResult(Device.fromPeripheral(peripheral).toMap())
        continuation?.resume()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        manager.removePeripheral(peripheral)
        pendingResult(FlutterError.networkError())
        continuation?.resume()
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
