import Foundation
import Flutter

enum EventName: String, Codable {
    case gattserverdisconnected
    case characteristicvaluechanged
}

public class Event: NSObject {
    let name: EventName
    
    init(name: EventName) {
        self.name = name
    }

    func toMap() -> [String:AnyObject] {
        return [
            "name": name.rawValue
        ] as [String:AnyObject]
    }
}
