import CoreBluetooth

protocol BluetoothManagerDelegete: AnyObject, CBCentralManagerDelegate {}

final class BluetoothManager: NSObject {

    let central: CBCentralManager
    private var peripheralsById: [String: CBPeripheral] = [:]

    private let delegates = NSHashTable<AnyObject>.weakObjects()

    init(
        queue: DispatchQueue? = nil,
        options: [String: Any]? = nil
    ) {
        self.central = CBCentralManager(
            delegate: nil,
            queue: queue,
            options: options
        )

        super.init()

        central.delegate = self
    }

    func addDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.remove(delegate)
    }

    func removeAllDelegates() {
        delegates.removeAllObjects()
    }

    func peripheral(for deviceId: String) -> CBPeripheral? {
        return peripheralsById[deviceId]
    }

    func addPeripheral(_ peripheral: CBPeripheral) {
        peripheralsById[peripheral.identifier.uuidString] = peripheral
    }

    func removePeripheral(_ peripheral: CBPeripheral) {
        peripheralsById.removeValue(forKey: peripheral.identifier.uuidString)
    }

    func removePeripheral(deviceId: String) {
        peripheralsById.removeValue(forKey: deviceId)
    }

    func removeAllPeripherals() {
        peripheralsById.removeAll()
    }

    func retrievePeripheral(deviceId: String) -> CBPeripheral? {
        if let cached = peripheralsById[deviceId] {
            return cached
        }

        guard let uuid = UUID(uuidString: deviceId) else {
            return nil
        }
        let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals.first else {
            return nil
        }

        addPeripheral(peripheral)
        return peripheral
    }

    private func notify(
        _ block: (BluetoothManagerDelegete) -> Void
    ) {
        // allObjects creates a snapshot, so a listener can safely
        // add/remove itself while callbacks are being delivered.
        for listener in delegates.allObjects {
            guard let listener = listener as? BluetoothManagerDelegete else {
                continue
            }

            block(listener)
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        notify {
            $0.centralManagerDidUpdateState(central)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        notify {
            $0.centralManager?(
                central,
                didDiscover: peripheral,
                advertisementData: advertisementData,
                rssi: RSSI
            )
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        notify {
            $0.centralManager?(
                central,
                didConnect: peripheral
            )
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        notify {
            $0.centralManager?(
                central,
                didFailToConnect: peripheral,
                error: error
            )
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        notify {
            $0.centralManager?(
                central,
                didDisconnectPeripheral: peripheral,
                error: error
            )
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        connectionEventDidOccur event: CBConnectionEvent,
        for peripheral: CBPeripheral
    ) {
        notify {
            $0.centralManager?(
                central,
                connectionEventDidOccur: event,
                for: peripheral
            )
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        notify {
            $0.centralManager?(
                central,
                willRestoreState: dict
            )
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: Error?
    ) {
        notify {
            $0.centralManager?(
                central,
                didDisconnectPeripheral: peripheral,
                timestamp: timestamp,
                isReconnecting: isReconnecting,
                error: error
            )
        }
    }

    @available(iOS 13.0, *)
    func centralManager(
        _ central: CBCentralManager,
        didUpdateANCSAuthorizationFor peripheral: CBPeripheral
    ) {
        notify {
            $0.centralManager?(
                central,
                didUpdateANCSAuthorizationFor: peripheral
            )
        }
    }
}
