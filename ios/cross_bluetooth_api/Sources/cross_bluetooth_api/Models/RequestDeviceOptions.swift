import Foundation

struct Filter {
    var services: [String]?
    var name: String?
    var namePrefix: String?

    static func fromMap(_ map: [String:AnyObject]) -> Filter {
        Filter(
            services: map["services"] as? [String],
            name: map["name"] as? String,
            namePrefix: map["namePrefix"] as? String
        )
    }
}

struct RequestDeviceOptions {
    var filters: [Filter]?
    var optionalServices: [String]?
    var acceptAllDevices: Bool

    static func fromMap(_ map: Dictionary<String, Any>) -> RequestDeviceOptions {
        RequestDeviceOptions(
            filters: map["filters"] != nil ? (map["filters"] as! [[String : AnyObject]]).map { Filter.fromMap($0) } : [],
            optionalServices: map["optionalServices"] as? [String],
            acceptAllDevices: map["acceptAllDevices"] as? Bool ?? false
        )
    }
}
