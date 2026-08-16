import CoreBluetooth

protocol BluetoothManagerDelegete: AnyObject, CBCentralManagerDelegate {}

protocol BluetoothManager {
    func connect(_ deviceId: String) -> Bool
    func disconnect(_ deviceId: String) -> Bool
    func addDelegate(_ delegate: BluetoothManagerDelegete)
    func removeDelegate(_ delegate: BluetoothManagerDelegete)
    func deviceManager(for deviceId: String) -> DeviceManager?

    @discardableResult
    func addPeripheral(_ peripheral: CBPeripheral) -> DeviceManager
    func removePeripheral(_ peripheral: CBPeripheral)
}

final class BluetoothManagerImp: NSObject, BluetoothManager {

    private let central: CBCentralManager
    private var deviceManagersById: [String: DeviceManager] = [:]

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

    func connect(_ deviceId: String) -> Bool {
        guard let deviceManager = retrieveDeviceManager(deviceId: deviceId) else {
            return false
        }
        deviceManager.connect()
        return true
    }

    func disconnect(_ deviceId: String) -> Bool {
        guard let deviceManager = retrieveDeviceManager(deviceId: deviceId) else {
            return false
        }
        deviceManager.disconnect()
        return true
    }

    func addDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.add(delegate)
    }

    func removeDelegate(_ delegate: BluetoothManagerDelegete) {
        delegates.remove(delegate)
    }

    func deviceManager(for deviceId: String) -> DeviceManager? {
        return deviceManagersById[deviceId]
    }

    @discardableResult
    func addPeripheral(_ peripheral: CBPeripheral) -> DeviceManager {
        let id = peripheral.identifier.uuidString
        if let existing = deviceManagersById[id] {
            return existing
        }

        let manager = DeviceManagerImp(central: central, peripheral: peripheral)
        deviceManagersById[id] = manager
        return manager
    }

    func removePeripheral(_ peripheral: CBPeripheral) {
        deviceManagersById.removeValue(forKey: peripheral.identifier.uuidString)
    }

    private func retrieveDeviceManager(deviceId: String) -> DeviceManager? {
        if let cached = deviceManagersById[deviceId] {
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
        return deviceManagersById[deviceId]
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

extension BluetoothManagerImp: CBCentralManagerDelegate {

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
