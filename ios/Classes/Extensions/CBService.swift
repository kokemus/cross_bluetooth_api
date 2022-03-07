import Foundation
import CoreBluetooth

extension CBService {
    func toMap() -> [String:AnyObject] {
        return [
            "uuid": uuid.uuidString,
            "isPrimary": isPrimary
        ] as [String:AnyObject]
    }
}
