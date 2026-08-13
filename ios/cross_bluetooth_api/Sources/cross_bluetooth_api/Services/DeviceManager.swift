import CoreBluetooth

protocol DeviceManagerDelegate: AnyObject, CBPeripheralDelegate {}

final class DeviceManager: NSObject {

    let peripheral: CBPeripheral

    private let delegates = NSHashTable<AnyObject>.weakObjects()

    init(peripheral: CBPeripheral) {
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

extension DeviceManager: CBPeripheralDelegate {

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
