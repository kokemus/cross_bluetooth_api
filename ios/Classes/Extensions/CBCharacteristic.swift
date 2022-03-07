import Foundation
import CoreBluetooth

extension CBCharacteristic  {
    func toMap() -> [String:AnyObject] {
        return [
            "uuid": uuid.uuidString
        ] as [String:AnyObject]
    }
}
