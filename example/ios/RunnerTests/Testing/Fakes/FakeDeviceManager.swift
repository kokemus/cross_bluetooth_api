import Foundation
import CoreBluetooth
@testable import cross_bluetooth_api

final class FakeDeviceManager: DeviceManager {
    let deviceId: String

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    func addDelegate(_ delegate: DeviceManagerDelegate) {}
    func removeDelegate(_ delegate: DeviceManagerDelegate) {}
    func removeAllDelegates() {}

    func connect() {}
    func disconnect() {}

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {}
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {}

    func getService(_ serviceUUID: CBUUID) -> CBService? { nil }
    func getCharacteristic(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBCharacteristic? { nil }

    func readValue(for characteristic: CBCharacteristic) {}
    func writeValue(_ value: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {}
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {}
}
