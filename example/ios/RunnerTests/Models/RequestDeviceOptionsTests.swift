import CoreBluetooth
import XCTest
@testable import cross_bluetooth_api

final class RequestDeviceOptionsTests: XCTestCase {
    func test_filtersUseOrAndFieldsUseAnd() {
        let options = RequestDeviceOptions(
            filters: [Filter(services: ["180D"], namePrefix: "Sensor"), Filter(name: "Other")],
            acceptAllDevices: false
        )
        let advertisement: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "180D")]]
        XCTAssertTrue(options.matches(name: "Sensor 1", advertisementData: advertisement))
        XCTAssertTrue(options.matches(name: "Other", advertisementData: [:]))
        XCTAssertFalse(options.matches(name: "Sensor 1", advertisementData: [:]))
        XCTAssertFalse(options.matches(name: "Unrelated", advertisementData: advertisement))
    }

    func test_namesPreferAdvertisementAndFallBackToPeripheral() {
        let filter = Filter(name: "Sensor", namePrefix: "Sen")
        XCTAssertTrue(filter.matches(name: "Cached", advertisementData: [CBAdvertisementDataLocalNameKey: "Sensor"]))
        XCTAssertTrue(filter.matches(name: "Sensor", advertisementData: [:]))
        XCTAssertFalse(filter.matches(name: "Sensor", advertisementData: [CBAdvertisementDataLocalNameKey: "Other"]))
        XCTAssertFalse(filter.matches(name: nil, advertisementData: [:]))
        XCTAssertFalse(filter.matches(name: "sensor", advertisementData: [:]))
    }

    func test_servicesRequireAllUuidsIncludingOverflow() {
        let filter = Filter(services: ["180D", "180F"])
        let primary: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "180D")]]
        XCTAssertFalse(filter.matches(name: nil, advertisementData: primary))
        var complete = primary
        complete[CBAdvertisementDataOverflowServiceUUIDsKey] = [CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")]
        XCTAssertTrue(filter.matches(name: nil, advertisementData: complete))
        XCTAssertFalse(filter.matches(name: nil, advertisementData: [:]))
    }

    func test_scanServicesUnionAllFilters() {
        let options = RequestDeviceOptions(
            filters: [Filter(services: ["180D", "180F"]), Filter(services: ["180A"])],
            acceptAllDevices: false
        )
        XCTAssertEqual(options.scanServiceUUIDs, ["180D", "180F", "180A"].map { CBUUID(string: $0) })
    }

    func test_scanServicesDoNotExcludeUnconstrainedBranches() {
        for filter in [Filter(name: "Sensor"), Filter(services: [], namePrefix: "Sensor"),
                       Filter(manufacturerData: [ManufacturerData(companyIdentifier: 76)])] {
            let options = RequestDeviceOptions(filters: [Filter(services: ["180D"]), filter], acceptAllDevices: false)
            XCTAssertNil(options.scanServiceUUIDs)
        }
    }

    func test_acceptAllDevicesBypassesFiltersAndScanServices() {
        let options = RequestDeviceOptions(filters: [Filter(services: ["180D"], name: "Sensor")], acceptAllDevices: true)
        XCTAssertTrue(options.matches(name: nil, advertisementData: [:]))
        XCTAssertNil(options.scanServiceUUIDs)
    }

    func test_noFiltersDoesNotMatchWithoutAcceptAllDevices() {
        for filters: [Filter]? in [nil, []] {
            let options = RequestDeviceOptions(filters: filters, acceptAllDevices: false)
            XCTAssertFalse(options.matches(name: "Sensor", advertisementData: [:]))
            XCTAssertNil(options.scanServiceUUIDs)
        }
    }

    func test_manufacturerDataParsesAndMatchesMaskedPayload() {
        let options = RequestDeviceOptions.fromMap([
            "filters": [["manufacturerData": [[
                "companyIdentifier": 0x1234, "dataPrefix": [0xA0, 0x05], "mask": [0xF0, 0xFF]
            ]]]]
        ])
        XCTAssertEqual(options.filters?.first?.manufacturerData?.first?.companyIdentifier, 0x1234)
        XCTAssertTrue(options.matches(name: nil, advertisementData: [
            CBAdvertisementDataManufacturerDataKey: Data([0x34, 0x12, 0xAB, 0x05, 0xFF])
        ]))
        XCTAssertFalse(options.matches(name: nil, advertisementData: [
            CBAdvertisementDataManufacturerDataKey: Data([0x34, 0x12, 0xAB, 0x06])
        ]))
        XCTAssertFalse(options.matches(name: nil, advertisementData: [:]))
    }

    func test_manufacturerIdentifierUsesLittleEndianAndPrefixDefaultsToExactMatch() {
        let filter = ManufacturerData(companyIdentifier: 0x1234, dataPrefix: [0xAB])
        XCTAssertTrue(filter.matches(Data([0x34, 0x12, 0xAB])))
        XCTAssertFalse(filter.matches(Data([0x12, 0x34, 0xAB])))
        XCTAssertFalse(filter.matches(Data([0x34, 0x12, 0xAC])))
        XCTAssertFalse(filter.matches(Data([0x34, 0x12])))
        XCTAssertFalse(filter.matches(Data([0x34])))
        XCTAssertFalse(filter.matches(nil))
        XCTAssertTrue(ManufacturerData(companyIdentifier: 0x1234).matches(Data([0x34, 0x12])))
    }

    func test_manufacturerConstraintsCombineWithNamesAndEachOther() {
        let filter = Filter(namePrefix: "Sensor", manufacturerData: [
            ManufacturerData(companyIdentifier: 76), ManufacturerData(companyIdentifier: 76, dataPrefix: [1])
        ])
        let advertisement: [String: Any] = [CBAdvertisementDataManufacturerDataKey: Data([76, 0, 1])]
        XCTAssertTrue(filter.matches(name: "Sensor 1", advertisementData: advertisement))
        XCTAssertFalse(filter.matches(name: "Other", advertisementData: advertisement))
        XCTAssertFalse(filter.matches(name: "Sensor 1", advertisementData: [CBAdvertisementDataManufacturerDataKey: Data([76, 0, 2])]))
    }

    func test_invalidManufacturerValuesDoNotMatchOrCrash() {
        for filter in [ManufacturerData(companyIdentifier: -1),
                       ManufacturerData(companyIdentifier: 76, dataPrefix: [256]),
                       ManufacturerData(companyIdentifier: 76, dataPrefix: [1], mask: []),
                       ManufacturerData(companyIdentifier: 76, dataPrefix: [1], mask: [-1])] {
            XCTAssertFalse(filter.matches(Data([76, 0, 1])))
        }
        let options = RequestDeviceOptions.fromMap(["filters": [["manufacturerData": [["dataPrefix": [1]]]]]])
        XCTAssertFalse(options.matches(name: nil, advertisementData: [CBAdvertisementDataManufacturerDataKey: Data([76, 0, 1])]))
    }

    func test_optionalServicesAndProductDataDoNotConstrainDiscovery() {
        let options = RequestDeviceOptions(
            filters: [Filter(name: "Sensor", productData: ProductData(name: "Product", image: "sensor.png"))],
            optionalServices: ["180D"],
            acceptAllDevices: false
        )
        XCTAssertTrue(options.matches(name: "Sensor", advertisementData: [:]))
        XCTAssertNil(options.scanServiceUUIDs)
    }
}