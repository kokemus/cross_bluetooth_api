import Flutter
import UIKit
import CoreBluetooth

public class SwiftCrossBluetoothApiPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cross_bluetooth_api", binaryMessenger: registrar.messenger())
        let instance = SwiftCrossBluetoothApiPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var viewController: UIViewController {
        get {
            return UIApplication.shared.delegate!.window!!.rootViewController!
        }
    }

    private var manager: CBCentralManager!
    private var pendingResult: FlutterResult?
    private var peripherals: [CBPeripheral] = []

    override init() {
        super.init()
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (call.method == "requestDevice") {
            requestDevice(arguments: call.arguments as? Dictionary<String, AnyObject>, result: result)
        } else if (call.method == "connect") {
            connect(arguments: call.arguments as? [String : AnyObject], result: result)
        } else if (call.method == "disconnect") {
            disconnect(arguments: call.arguments as? [String : AnyObject], result: result)
        } else if (call.method == "getPrimaryService") {
            getPrimaryService(arguments: call.arguments as? [String : AnyObject], result: result)
        } else if (call.method == "getCharacteristic") {
            getCharacteristic(arguments: call.arguments as? [String : AnyObject], result: result)
        } else if (call.method == "readValue") {
            readValue(arguments: call.arguments as? [String : AnyObject], result: result)
        } else if (call.method == "writeValueWithoutResponse") {
            writeValueWithoutResponse(arguments: call.arguments as? [String : AnyObject], result: result)
        } else if (call.method == "writeValueWithResponse") {
            writeValueWithResponse(arguments: call.arguments as? [String : AnyObject], result: result)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestDevice(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        pendingResult = result
        viewController.present(
            RequestDeviceViewController(options: arguments ?? [:], delegate: self),
            animated: true,
            completion: nil
        )
    }

    private func connect(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        let peripherals = manager.retrievePeripherals(withIdentifiers: [UUID(uuidString: arguments!["id"] as! String)!])
        guard let peripheral = peripherals.first else {
            return result(networkError)
        }
        pendingResult = result
        self.peripherals.append(peripheral)
        manager.connect(peripheral, options: nil)
    }

    private func disconnect(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == arguments!["id"] as! String }) else {
            return result(networkError)
        }
        pendingResult = result
        manager.cancelPeripheralConnection(peripheral)
    }

    private func getPrimaryService(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        let deviceId = arguments!["deviceId"] as! String
        let serviceUUID = arguments!["serviceUUID"] as! String

        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == deviceId }) else {
            return result(networkError)
        }
        pendingResult = result
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: serviceUUID)])
    }

    private func getCharacteristic(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        let deviceId = arguments!["deviceId"] as! String
        let serviceUUID = arguments!["serviceUUID"] as! String
        let characteristic = arguments!["characteristic"] as! String

        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == deviceId }) else {
            return result(networkError)
        }
        let service = peripheral.services?.first { $0.uuid == CBUUID(string: serviceUUID) }
        if service != nil {
            pendingResult = result
            peripheral.delegate = self
            peripheral.discoverCharacteristics([CBUUID(string: characteristic)], for: service!)
        } else {
            result(notFoundError)
        }
    }

    private func readValue(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        let deviceId = arguments!["deviceId"] as! String
        let serviceUUID = arguments!["serviceUUID"] as! String
        let characteristicUUID = arguments!["characteristic"] as! String

        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == deviceId }) else {
            return result(networkError)
        }
        let service = peripheral.services?.first { $0.uuid == CBUUID(string: serviceUUID) }
        let characteristic = service?.characteristics?.first { $0.uuid == CBUUID(string: characteristicUUID) }
        if characteristic != nil {
            pendingResult = result
            peripheral.delegate = self
            peripheral.readValue(for: characteristic!)
        } else {
            result(notFoundError)
        }
    }

    private func writeValueWithoutResponse(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        let deviceId = arguments!["deviceId"] as! String
        let serviceUUID = arguments!["serviceUUID"] as! String
        let characteristicUUID = arguments!["characteristic"] as! String
        let value = arguments!["value"] as! Data

        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == deviceId }) else {
            return result(networkError)
        }
        let service = peripheral.services?.first { $0.uuid == CBUUID(string: serviceUUID) }
        let characteristic = service?.characteristics?.first { $0.uuid == CBUUID(string: characteristicUUID) }
        if characteristic != nil {
            peripheral.writeValue(value, for: characteristic!, type: .withoutResponse)
            result(value)
        } else {
            result(notFoundError)
        }
    }

    private func writeValueWithResponse(arguments: Dictionary<String, AnyObject>?, result: @escaping FlutterResult) {
        let deviceId = arguments!["deviceId"] as! String
        let serviceUUID = arguments!["serviceUUID"] as! String
        let characteristicUUID = arguments!["characteristic"] as! String
        let value = arguments!["value"] as! Data

        guard let peripheral = peripherals.first(where: { $0.identifier.uuidString == deviceId }) else {
            return result(networkError)
        }
        let service = peripheral.services?.first { $0.uuid == CBUUID(string: serviceUUID) }
        let characteristic = service?.characteristics?.first { $0.uuid == CBUUID(string: characteristicUUID) }
        if characteristic != nil {
            pendingResult = result
            peripheral.delegate = self
            peripheral.writeValue(value, for: characteristic!, type: .withResponse)
        } else {
            result(notFoundError)
        }
    }
}

extension SwiftCrossBluetoothApiPlugin: RequestDeviceDelegate {
    func requestDevice(_ requestDevice: RequestDeviceViewController, didRequest peripheral: CBPeripheral) {
        viewController.dismiss(animated: true, completion: nil)
        pendingResult?(Device.fromPeripheral(peripheral).toMap())
    }

    func requestDevice(_ requestDevice: RequestDeviceViewController, didFailWithError error: RequestDeviceError) {
        viewController.dismiss(animated: true, completion: nil)
        switch (error) {
        case .userCancelled:
            pendingResult?(userCancelledError)
        default:
            pendingResult?(notFoundError)
        }
    }
}

extension SwiftCrossBluetoothApiPlugin: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        pendingResult?(Device.fromPeripheral(peripheral).toMap())
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        peripherals.remove(at: peripherals.firstIndex { $0.identifier == peripheral.identifier } ?? -1)
        pendingResult?(networkError)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals.remove(at: peripherals.firstIndex { $0.identifier == peripheral.identifier } ?? -1)
        pendingResult?(Device.fromPeripheral(peripheral).toMap())
    }
}

extension SwiftCrossBluetoothApiPlugin: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            pendingResult?(notFoundError)
        } else {
            pendingResult?(peripheral.services?.first?.toMap())
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            pendingResult?(notFoundError)
        } else {
            pendingResult?(service.characteristics?.first?.toMap())
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            pendingResult?(networkError)
        } else {
            pendingResult?(characteristic.value)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            pendingResult?(networkError)
        } else {
            pendingResult?(characteristic.value)
        }
    }
}

private let networkError = FlutterError(
    code: "NetworkError",
    message: "NetworkError: A network error occurred.",
    details: nil
)

private let userCancelledError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: User cancelled the requestDevice() chooser.",
    details: nil
)

private let notFoundError = FlutterError(
    code: "NotFoundError",
    message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
    details: nil
)
