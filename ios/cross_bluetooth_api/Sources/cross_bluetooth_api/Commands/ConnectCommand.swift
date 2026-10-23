import Foundation
import Flutter
import CoreBluetooth

public class ConnectCommand: BaseCommand, BluetoothManagerDelegete {
    private let manager: BluetoothManager
    private var targetDeviceId: UUID?

    init(
        manager: BluetoothManager,
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult
    ) {
        self.manager = manager
        super.init(id: .connect, arguments: arguments, pendingResult: pendingResult)
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
            guard let deviceId = arguments["id"] as? String,
                  let identifier = UUID(uuidString: deviceId) else {
                complete(FlutterError.networkError())
                return
            }

            targetDeviceId = identifier
            manager.addDelegate(self)
            if !manager.connect(deviceId) {
                complete(FlutterError.networkError())
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard continuation != nil, peripheral.identifier == targetDeviceId else { return }
        complete(Device.fromPeripheral(peripheral).toMap())
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard continuation != nil, peripheral.identifier == targetDeviceId else { return }
        manager.removePeripheral(peripheral)
        complete(FlutterError.networkError())
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
