import Flutter
import UIKit
import CoreBluetooth

public class SwiftCrossBluetoothApiPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cross_bluetooth_api", binaryMessenger: registrar.messenger())
        
        let eventChannel = FlutterEventChannel(name: "cross_bluetooth_api/events", binaryMessenger: registrar.messenger())

        let instance = SwiftCrossBluetoothApiPlugin()
        eventChannel.setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var viewController: UIViewController {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = windowScenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        return keyWindow!.rootViewController!
    }

    private var eventSink: FlutterEventSink?
    private var manager: BluetoothManager!

    override init() {
        super.init()
        manager = BluetoothManager(queue: .main)
        manager.addDelegate(self)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = CommandId(rawValue: call.method)
        let arguments = call.arguments as? [String: AnyObject]
        switch method {
        case .requestDevice:
            Task { @MainActor in
                await RequestDeviceCommand(
                    viewController: viewController,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .connect:
            Task {
                await ConnectCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .disconnect:
            Task {
                await DisconnectCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .getPrimaryService:
            Task {
                await GetPrimaryServiceCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .getCharacteristic:
            Task {
                await GetCharacteristicCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .readValue:
            Task {
                await ReadValueCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .writeValueWithoutResponse:
            Task {
                await WriteValueWithoutResponseCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .writeValueWithResponse:
            Task {
                await WriteValueWithResponseCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .startNotifications:
            Task {
                await StartNotificationsCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        case .stopNotifications:
            Task {
                await StopNotificationsCommand(
                    manager: manager,
                    arguments: arguments,
                    pendingResult: result
                ).execute()
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getPeripheral(_ deviceId: String) -> CBPeripheral? {
        return manager.peripheral(for: deviceId)
    }

    private func getService(_ deviceId: String, _ serviceUUID: String) -> CBService? {
        let peripheral = getPeripheral(deviceId)
        return peripheral?.services?.first { $0.uuid == CBUUID(string: serviceUUID) }
    }

    private func getCharacteristic(_ deviceId: String, _ serviceUUID: String, _ characteristicUUID: String) -> CBCharacteristic? {
        let peripheral = getPeripheral(deviceId)
        let service = peripheral?.services?.first { $0.uuid == CBUUID(string: serviceUUID) }
        return service?.characteristics?.first { $0.uuid == CBUUID(string: characteristicUUID) }
    }
}

extension SwiftCrossBluetoothApiPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

extension SwiftCrossBluetoothApiPlugin: BluetoothManagerDelegete {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        manager.addPeripheral(peripheral).addDelegate(self)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {}

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        manager.removePeripheral(peripheral)
        eventSink?(
            GattServerDisconnectedEvent(
                deviceId: peripheral.identifier.uuidString
            ).toMap()
        )
    }
}

extension SwiftCrossBluetoothApiPlugin: DeviceManagerDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {}

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {}

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil {
            eventSink?(
                CharacteristicValueChangedEvent(
                    deviceId: peripheral.identifier.uuidString,
                    serviceUUID: characteristic.service!.uuid.uuidString,
                    characteristicUUID: characteristic.uuid.uuidString,
                    value: characteristic.value ?? Data()
                ).toMap()
            )
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {}
}
