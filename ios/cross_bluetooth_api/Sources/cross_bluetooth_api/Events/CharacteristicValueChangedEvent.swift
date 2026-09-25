import Foundation
import Flutter

public class CharacteristicValueChangedEvent: Event {
    let deviceId: String
    let serviceUUID: String
    let characteristicUUID: String
    let value: Data

    init(
        deviceId: String,
        serviceUUID: String,
        characteristicUUID: String,
        value: Data
    ) {
        self.deviceId = deviceId
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        self.value = value
        super.init(name: .characteristicvaluechanged)
    }

    override func toMap() -> [String:AnyObject] {
        var map = super.toMap()
        map["deviceId"] = deviceId as AnyObject
        map["serviceUUID"] = serviceUUID as AnyObject
        map["characteristicUUID"] = characteristicUUID as AnyObject
        map["value"] = value as AnyObject
        return map
    }
}
