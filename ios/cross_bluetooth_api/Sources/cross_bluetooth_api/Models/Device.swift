import Foundation
import CoreBluetooth

struct Device {
    var id: String
    var name: String?

    static func fromPeripheral(_ peripheral: CBPeripheral) -> Device {
        Device(
            id: peripheral.identifier.uuidString,
            name: peripheral.name
        )
    }

    static func fromMap(_ map: [String:AnyObject]) -> Device {
        Device(
            id: map["id"] as! String,
            name: map["name"] as? String
        )
    }

    func toMap() -> [String:AnyObject] {
        return [
            "id": id,
            "name": name
        ] as [String:AnyObject]
    }
}
