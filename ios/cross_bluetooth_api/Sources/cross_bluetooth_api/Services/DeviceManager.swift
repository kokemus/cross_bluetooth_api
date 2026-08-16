import CoreBluetooth

protocol DeviceManagerDelegate: AnyObject, CBPeripheralDelegate {}

protocol DeviceManager: AnyObject {
    var deviceId: String { get }

    func addDelegate(_ delegate: DeviceManagerDelegate)
    func removeDelegate(_ delegate: DeviceManagerDelegate)
    func removeAllDelegates()

    func connect()
    func disconnect()

    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService)

    func getService(_ serviceUUID: CBUUID) -> CBService?
    func getCharacteristic(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBCharacteristic?

    func readValue(for characteristic: CBCharacteristic)
    func writeValue(_ value: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType)
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
}

final class DeviceManagerImp: NSObject, DeviceManager {

    private let central: CBCentralManager
    private let peripheral: CBPeripheral

    var deviceId: String {
        peripheral.identifier.uuidString
    }

    private let delegates = NSHashTable<AnyObject>.weakObjects()

    init(central: CBCentralManager, peripheral: CBPeripheral) {
        self.central = central
        self.peripheral = peripheral

        super.init()

        peripheral.delegate = self
    }

    func addDelegate(_ delegate: DeviceManagerDelegate) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: DeviceManagerDelegate) {
        delegates.remove(delegate)
    }

    func removeAllDelegates() {
        delegates.removeAllObjects()
    }

    func connect() {
        central.connect(peripheral)
    }

    func disconnect() {
        central.cancelPeripheralConnection(peripheral)
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        peripheral.discoverServices(serviceUUIDs)
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
    }

    func getService(_ serviceUUID: CBUUID) -> CBService? {
        peripheral.services?.first(where: { $0.uuid == serviceUUID })
    }

    func getCharacteristic(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBCharacteristic? {
        getService(serviceUUID)?.characteristics?.first(where: { $0.uuid == characteristicUUID })
    }

    func readValue(for characteristic: CBCharacteristic) {
        peripheral.readValue(for: characteristic)
    }

    func writeValue(_ value: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        peripheral.writeValue(value, for: characteristic, type: type)
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        peripheral.setNotifyValue(enabled, for: characteristic)
    }

    private func notify(
        _ block: (DeviceManagerDelegate) -> Void
    ) {
        // Use a snapshot so listeners can safely add/remove themselves
        // during a callback.
        for object in delegates.allObjects {
            guard let listener = object as? DeviceManagerDelegate else {
                continue
            }

            block(listener)
        }
    }
}

extension DeviceManagerImp: CBPeripheralDelegate {

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didDiscoverServices: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didDiscoverCharacteristicsFor: service,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didUpdateValueFor: characteristic,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didWriteValueFor: characteristic,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didUpdateNotificationStateFor: characteristic,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didDiscoverDescriptorsFor: characteristic,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor descriptor: CBDescriptor,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didUpdateValueFor: descriptor,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor descriptor: CBDescriptor,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didWriteValueFor: descriptor,
                error: error
            )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didReadRSSI: RSSI,
                error: error
            )
        }
    }

    func peripheralIsReady(
        _ peripheral: CBPeripheral
    ) {
        notify {
            $0.peripheralIsReady?(toSendWriteWithoutResponse: peripheral)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didModifyServices invalidatedServices: [CBService]
    ) {
        notify {
            $0.peripheral?(
                peripheral,
                didModifyServices: invalidatedServices
            )
        }
    }
}
