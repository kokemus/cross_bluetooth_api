import Foundation
import CoreBluetooth

struct ManufacturerData {
    var companyIdentifier: Int
    var dataPrefix: [Int]?
    var mask: [Int]?

    static func fromMap(_ map: [String: AnyObject]) -> ManufacturerData? {
        guard let companyIdentifier = map["companyIdentifier"] as? Int else { return nil }
        return ManufacturerData(
            companyIdentifier: companyIdentifier,
            dataPrefix: map["dataPrefix"] as? [Int],
            mask: map["mask"] as? [Int]
        )
    }

    func matches(_ data: Data?) -> Bool {
        guard let data, data.count >= 2 else { return false }
        let bytes = Array(data)
        guard Int(bytes[0]) | (Int(bytes[1]) << 8) == companyIdentifier else { return false }
        let prefix = dataPrefix ?? []
        guard bytes.count >= prefix.count + 2,
              mask == nil || mask?.count == prefix.count else { return false }
        return prefix.indices.allSatisfy { index in
            guard let expected = UInt8(exactly: prefix[index]),
                  let bitmask = UInt8(exactly: mask?[index] ?? 255) else { return false }
            return bytes[index + 2] & bitmask == expected & bitmask
        }
    }
}

struct ProductData {
    var name: String
    var image: String

    static func fromMap(_ map: [String: AnyObject]) -> ProductData? {
        guard let name = map["name"] as? String,
              let image = map["image"] as? String else { return nil }
        return ProductData(name: name, image: image)
    }
}

struct Filter {
    var services: [String]?
    var name: String?
    var namePrefix: String?
    var productData: ProductData? = nil
    var manufacturerData: [ManufacturerData]? = nil

    static func fromMap(_ map: [String:AnyObject]) -> Filter {
        Filter(
            services: map["services"] as? [String],
            name: map["name"] as? String,
            namePrefix: map["namePrefix"] as? String,
            productData: (map["productData"] as? [String: AnyObject]).flatMap(ProductData.fromMap),
            manufacturerData: (map["manufacturerData"] as? [[String: AnyObject]])?.map {
                ManufacturerData.fromMap($0) ?? ManufacturerData(companyIdentifier: -1)
            }
        )
    }

    func matches(name deviceName: String?, advertisementData: [String: Any]) -> Bool {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? deviceName
        if let name, advertisedName != name { return false }
        if let namePrefix, advertisedName?.hasPrefix(namePrefix) != true { return false }
        if let services {
            let advertisedServices = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
                + (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
            guard services.allSatisfy({ advertisedServices.contains(CBUUID(string: $0)) }) else { return false }
        }
        if let manufacturerData {
            let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
            guard manufacturerData.allSatisfy({ $0.matches(data) }) else { return false }
        }
        return true
    }
}

struct RequestDeviceOptions {
    var filters: [Filter]?
    var optionalServices: [String]?
    var acceptAllDevices: Bool

    var scanServiceUUIDs: [CBUUID]? {
        guard !acceptAllDevices, let filters, !filters.isEmpty,
              filters.allSatisfy({ !($0.services?.isEmpty ?? true) }) else { return nil }
        return filters.flatMap { ($0.services ?? []).map { CBUUID(string: $0) } }
    }

    func matches(name: String?, advertisementData: [String: Any]) -> Bool {
        acceptAllDevices || (filters?.contains { $0.matches(name: name, advertisementData: advertisementData) } ?? false)
    }

    static func fromMap(_ map: Dictionary<String, Any>) -> RequestDeviceOptions {
        RequestDeviceOptions(
            filters: map["filters"] != nil ? (map["filters"] as! [[String : AnyObject]]).map { Filter.fromMap($0) } : [],
            optionalServices: map["optionalServices"] as? [String],
            acceptAllDevices: map["acceptAllDevices"] as? Bool ?? false
        )
    }
}
