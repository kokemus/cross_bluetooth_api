import Foundation
import Flutter

public class GattServerDisconnectedEvent: Event {
    let deviceId: String
    
    init(deviceId: String) {
        self.deviceId = deviceId
        super.init(name: .gattserverdisconnected)
    }
    
    override func toMap() -> [String:AnyObject] {
        var map = super.toMap()
        map["deviceId"] = deviceId as AnyObject
        return map
    }
}