import Foundation
import Flutter

enum CommandId: String, Codable {
    case requestDevice
    case connect
    case disconnect
    case getPrimaryService
    case getCharacteristic
    case readValue
    case writeValueWithoutResponse
    case writeValueWithResponse
    case startNotifications
    case stopNotifications
}

protocol Command {
    func execute() async
}

public class BaseCommand: NSObject, Command {
    let id: CommandId
    let arguments: [String: AnyObject]
    let pendingResult: FlutterResult
    
    init(
        id: CommandId, 
        arguments: [String: AnyObject]?,
        pendingResult: @escaping FlutterResult,
    ) {
        self.id = id
        self.arguments = arguments ?? [:]
        self.pendingResult = pendingResult
    }

    func execute() async {
        pendingResult(FlutterError(code: "NotImplemented", message: "Command \(id.rawValue) is not implemented.", details: nil))
    }

    func dataArgument(_ key: String) -> Data? {
        if let value = arguments[key] as? FlutterStandardTypedData {
            return value.data
        }
        return arguments[key] as? Data
    }
}
