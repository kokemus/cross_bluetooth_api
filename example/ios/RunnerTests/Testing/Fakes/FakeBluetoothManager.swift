import Foundation
import CoreBluetooth
@testable import cross_bluetooth_api

final class FakePeripheralObject: NSObject {
    @objc let identifier: NSUUID
    @objc let name: String?

    init(identifier: UUID, name: String?) {
        self.identifier = identifier as NSUUID
        self.name = name
    }

    var peripheral: CBPeripheral { unsafeBitCast(self, to: CBPeripheral.self) }
}

final class FakeBluetoothManager: BluetoothManager {
    var state: CBManagerState = .poweredOn
    var isScanning = false
    var connectReturnValue: Bool
    var disconnectReturnValue = true
    var devices: [String: DeviceManager] = [:]
    var onOperation: (() -> Void)?
    private(set) var scannedServiceUUIDs: [CBUUID]?
    private(set) var scanOptions: [String: Any]?
    private(set) var stopScanCount = 0
    var connectedDeviceIds: [String] = []
    var disconnectedDeviceIds: [String] = []
    var removedPeripheralCount = 0

    private var delegates: [BluetoothManagerDelegete] = []
    private let connectLock = NSLock()
    private var connectWasCalled = false
    private var connectContinuation: CheckedContinuation<Void, Never>?

    init(connectReturnValue: Bool = true) {
        self.connectReturnValue = connectReturnValue
    }

    func waitUntilReady() async -> Bool { true }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        isScanning = true
        scannedServiceUUIDs = serviceUUIDs
        scanOptions = options
        onOperation?()
    }

    func stopScan() {
        isScanning = false
        stopScanCount += 1
    }

    func connect(_ deviceId: String) -> Bool {
        connectedDeviceIds.append(deviceId)
        connectLock.lock()
        connectWasCalled = true
        let continuation = connectContinuation
        connectContinuation = nil
        connectLock.unlock()
        continuation?.resume()
        onOperation?()
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
        onOperation?()
        return disconnectReturnValue
    }

    func addDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.append(delegate)
    }

    func removeDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.removeAll { $0 === delegate }
    }

    func deviceManager(for deviceId: String) -> DeviceManager? {
        devices[deviceId]
    }

    func hasDelegate(_ delegate: BluetoothManagerDelegete) -> Bool {
        delegates.contains { $0 === delegate }
    }

    @discardableResult
    func addPeripheral(_ peripheral: CBPeripheral) -> DeviceManager {
        let device = FakeDeviceManager(deviceId: peripheral.identifier.uuidString)
        devices[device.deviceId] = device
        return device
    }

    func removePeripheral(_ peripheral: CBPeripheral) {
        removedPeripheralCount += 1
        devices.removeValue(forKey: peripheral.identifier.uuidString)
    }

    func emitDidFailToConnect(identifier: UUID) {
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let peripheral = FakePeripheralObject(identifier: identifier, name: nil).peripheral
        delegates.forEach {
            $0.centralManager?(central, didFailToConnect: peripheral, error: nil)
        }
    }

    func emitDidConnect(identifier: UUID = UUID(), name: String? = nil) {
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let fakePeripheral = FakePeripheralObject(identifier: identifier, name: name)
        let peripheral = fakePeripheral.peripheral
        delegates.forEach {
            $0.centralManager?(central, didConnect: peripheral)
        }
    }

    func emitDidDisconnect(identifier: UUID, error: Error? = nil) {
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let peripheral = FakePeripheralObject(identifier: identifier, name: "Example Device").peripheral
        delegates.forEach {
            $0.centralManager?(central, didDisconnectPeripheral: peripheral, error: error)
        }
    }
}
