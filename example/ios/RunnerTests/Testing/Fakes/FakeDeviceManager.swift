import Foundation
import CoreBluetooth
@testable import cross_bluetooth_api

final class FakeDeviceManager: DeviceManager {
    let deviceId: String
    var services: [CBService] = []
    var onOperation: (() -> Void)?
    private var delegates: [DeviceManagerDelegate] = []
    private(set) var operations: [String] = []
    private(set) var discoveredServiceUUIDs: [CBUUID]?
    private(set) var discoveredCharacteristicUUIDs: [CBUUID]?
    private(set) var discoveredService: CBService?
    private(set) var readCharacteristic: CBCharacteristic?
    private(set) var writtenCharacteristic: CBCharacteristic?
    private(set) var writtenValue: Data?
    private(set) var writtenType: CBCharacteristicWriteType?
    private(set) var notificationCharacteristic: CBCharacteristic?
    private(set) var notificationEnabled: Bool?

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    func addDelegate(_ delegate: DeviceManagerDelegate) { delegates.append(delegate) }
    func removeDelegate(_ delegate: DeviceManagerDelegate) { delegates.removeAll { $0 === delegate } }
    func removeAllDelegates() { delegates.removeAll() }

    func hasDelegate(_ delegate: DeviceManagerDelegate) -> Bool {
        delegates.contains { $0 === delegate }
    }

    func connect() {}
    func disconnect() {}

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        discoveredServiceUUIDs = serviceUUIDs
        record("services")
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        discoveredCharacteristicUUIDs = characteristicUUIDs
        discoveredService = service
        record("characteristics")
    }

    func getService(_ serviceUUID: CBUUID) -> CBService? {
        services.first { $0.uuid == serviceUUID }
    }

    func getCharacteristic(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBCharacteristic? {
        getService(serviceUUID)?.characteristics?.first { $0.uuid == characteristicUUID }
    }

    func readValue(for characteristic: CBCharacteristic) {
        readCharacteristic = characteristic
        record("read")
    }

    func writeValue(_ value: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        writtenValue = value
        writtenCharacteristic = characteristic
        writtenType = type
        record("write")
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        notificationEnabled = enabled
        notificationCharacteristic = characteristic
        record("notification")
    }

    private func record(_ operation: String) {
        operations.append(operation)
        onOperation?()
    }

    func emitServicesDiscovered(_ peripheral: CBPeripheral, error: Error? = nil) {
        delegates.forEach { $0.peripheral?(peripheral, didDiscoverServices: error) }
    }

    func emitCharacteristicsDiscovered(_ peripheral: CBPeripheral, service: CBService, error: Error? = nil) {
        delegates.forEach { $0.peripheral?(peripheral, didDiscoverCharacteristicsFor: service, error: error) }
    }

    func emitValueUpdated(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error? = nil) {
        delegates.forEach { $0.peripheral?(peripheral, didUpdateValueFor: characteristic, error: error) }
    }

    func emitValueWritten(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error? = nil) {
        delegates.forEach { $0.peripheral?(peripheral, didWriteValueFor: characteristic, error: error) }
    }

    func emitNotificationState(_ peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error? = nil) {
        delegates.forEach { $0.peripheral?(peripheral, didUpdateNotificationStateFor: characteristic, error: error) }
    }
}
