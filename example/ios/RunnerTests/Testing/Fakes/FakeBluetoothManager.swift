import Foundation
import CoreBluetooth
@testable import cross_bluetooth_api

private final class FakePeripheralObject: NSObject {
    @objc let identifier: NSUUID
    @objc let name: String?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier as NSUUID
        self.name = name
    }
}

final class FakeBluetoothManager: BluetoothManager {
    var connectReturnValue: Bool
    var connectedDeviceIds: [String] = []
    var disconnectedDeviceIds: [String] = []
    var removedPeripheralCount = 0

    private var delegates: [BluetoothManagerDelegete] = []
    private let connectLock = NSLock()
    private var connectWasCalled = false
    private var connectContinuation: CheckedContinuation<Void, Never>?

    init(connectReturnValue: Bool) {
        self.connectReturnValue = connectReturnValue
    }

    func connect(_ deviceId: String) -> Bool {
        connectedDeviceIds.append(deviceId)
        connectLock.lock()
        connectWasCalled = true
        let continuation = connectContinuation
        connectContinuation = nil
        connectLock.unlock()
        continuation?.resume()
        return connectReturnValue
    }

    func waitUntilConnectCalled() async {
        await withCheckedContinuation { continuation in
            connectLock.lock()
            if connectWasCalled {
                connectLock.unlock()
                continuation.resume()
            } else {
                connectContinuation = continuation
                connectLock.unlock()
            }
        }
    }

    func disconnect(_ deviceId: String) -> Bool {
        disconnectedDeviceIds.append(deviceId)
        return true
    }

    func addDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.append(delegate)
    }

    func removeDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.removeAll { $0 === delegate }
    }

    func deviceManager(for deviceId: String) -> DeviceManager? {
        nil
    }

    @discardableResult
    func addPeripheral(_ peripheral: CBPeripheral) -> DeviceManager {
        FakeDeviceManager(deviceId: peripheral.identifier.uuidString)
    }

    func removePeripheral(_ peripheral: CBPeripheral) {
        removedPeripheralCount += 1
    }

    func emitDidFailToConnect() {
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let peripheral = unsafeBitCast(NSObject(), to: CBPeripheral.self)
        delegates.forEach {
            $0.centralManager?(central, didFailToConnect: peripheral, error: nil)
        }
    }

    func emitDidConnect(identifier: UUID = UUID(), name: String? = nil) {
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let fakePeripheral = FakePeripheralObject(identifier: identifier, name: name)
        let peripheral = unsafeBitCast(fakePeripheral, to: CBPeripheral.self)
        delegates.forEach {
            $0.centralManager?(central, didConnect: peripheral)
        }
    }
}
