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
        manager = BluetoothManagerImp(queue: .main)
        manager.addDelegate(self)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = CommandId(rawValue: call.method)
        let arguments = call.arguments as? [String: AnyObject]
        let command: Command? = switch method {
        case .requestDevice:
            RequestDeviceCommand(
                viewController: viewController,
                arguments: arguments,
                pendingResult: result
            )
        case .connect:
            ConnectCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .disconnect:
            DisconnectCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .getPrimaryService:
            GetPrimaryServiceCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .getCharacteristic:
            GetCharacteristicCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .readValue:
            ReadValueCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .writeValueWithoutResponse:
            WriteValueWithoutResponseCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .writeValueWithResponse:
            WriteValueWithResponseCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .startNotifications:
            StartNotificationsCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        case .stopNotifications:
            StopNotificationsCommand(
                manager: manager,
                arguments: arguments,
                pendingResult: result
            )
        default:
            nil
        }

        if let command {
            Task {
                await command.execute()
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
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
