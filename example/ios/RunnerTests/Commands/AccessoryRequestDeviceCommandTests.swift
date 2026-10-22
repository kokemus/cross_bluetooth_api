import AccessorySetupKit
import CoreBluetooth
import Flutter
import UIKit
import XCTest
@testable import cross_bluetooth_api

@available(iOS 18.0, *)
@MainActor
final class AccessoryRequestDeviceCommandTests: XCTestCase {
    private func makeCommand(
        session: FakeAccessorySession,
        arguments: [String: AnyObject] = ["filters": [[
            "services": ["180A"],
            "productData": ["name": "Sensor", "image": "images/tag.png"]
        ]] as AnyObject],
        pendingResult: @escaping FlutterResult
    ) -> AccessoryRequestDeviceCommand {
        AccessoryRequestDeviceCommand(
            arguments: arguments,
            session: session,
            pendingResult: pendingResult
        )
    }

    func test_requestDeviceOptions_parsesProductData() {
        let options = RequestDeviceOptions.fromMap([
            "filters": [[
                "services": ["180A"],
                "namePrefix": "Sensor",
                "productData": ["name": "Sensor", "image": "assets/sensor.png"]
            ]]
        ])

        let filter = options.filters?.first
        XCTAssertEqual(filter?.services, ["180A"])
        XCTAssertEqual(filter?.namePrefix, "Sensor")
        XCTAssertEqual(filter?.productData?.name, "Sensor")
        XCTAssertEqual(filter?.productData?.image, "assets/sensor.png")
    }

    func test_filter_acceptsAbsentProductData() {
        let filter = Filter.fromMap(["namePrefix": "Sensor" as AnyObject])

        XCTAssertEqual(filter.namePrefix, "Sensor")
        XCTAssertNil(filter.productData)
    }

    func test_filter_ignoresMalformedProductData() {
        let invalidProducts: [AnyObject] = [
            NSNull(),
            "invalid" as AnyObject,
            ["name": "Sensor"] as AnyObject,
            ["image": "assets/sensor.png"] as AnyObject,
            ["name": 42, "image": "assets/sensor.png"] as AnyObject,
            ["name": "Sensor", "image": 42] as AnyObject
        ]
        for productData in invalidProducts {
            let filter = Filter.fromMap([
                "namePrefix": "Sensor" as AnyObject,
                "productData": productData
            ])

            XCTAssertEqual(filter.namePrefix, "Sensor")
            XCTAssertNil(filter.productData)
        }
    }

    func test_execute_usesProductNameAndFlutterAssetImage() async throws {
        let session = FakeAccessorySession()
        let command = makeCommand(session: session, arguments: [
            "filters": [[
                "services": ["180A"],
                "productData": ["name": "Tag", "image": "images/tag.png"]
            ]] as AnyObject
        ]) { _ in }

        await command.execute()
        command.handle(.activated)

        let item = try XCTUnwrap(session.pickerItems.first)
        let assetPath = try XCTUnwrap(Bundle.main.path(
            forResource: FlutterDartProject.lookupKey(forAsset: "images/tag.png"),
            ofType: nil
        ))
        let expectedImage = try XCTUnwrap(UIImage(contentsOfFile: assetPath))
        XCTAssertEqual(item.name, "Tag")
        XCTAssertEqual(item.productImage.pngData(), expectedImage.pngData())
    }

    func test_execute_usesManufacturerDataInDiscoveryDescriptor() async throws {
        let session = FakeAccessorySession()
        let command = makeCommand(session: session, arguments: [
            "filters": [[
                "manufacturerData": [[
                    "companyIdentifier": 0x1234,
                    "dataPrefix": [1, 2],
                    "mask": [255, 240]
                ]],
                "productData": ["name": "Sensor", "image": "images/tag.png"]
            ]] as AnyObject
        ]) { _ in }

        await command.execute()
        command.handle(.activated)

        let descriptor = try XCTUnwrap(session.pickerItems.first?.descriptor)
        XCTAssertEqual(descriptor.bluetoothCompanyIdentifier, ASBluetoothCompanyIdentifier(rawValue: 0x1234))
        XCTAssertEqual(descriptor.bluetoothManufacturerDataBlob, Data([1, 2]))
        XCTAssertEqual(descriptor.bluetoothManufacturerDataMask, Data([255, 240]))
    }

    func test_execute_rejectsMissingProductImage() async throws {
        let session = FakeAccessorySession()
        var result: Any?
        let command = makeCommand(session: session, arguments: [
            "filters": [[
                "services": ["180A"],
                "productData": ["name": "Sensor", "image": "images/missing.png"]
            ]] as AnyObject
        ]) { result = $0 }

        await command.execute()

        XCTAssertEqual((result as? FlutterError)?.code, "NotSupportedError")
        XCTAssertFalse(session.activated)
        XCTAssertFalse(session.pickerRequested)
    }

    func test_execute_preservesAlternativeServiceFilters() async {
        let session = FakeAccessorySession()
        let command = makeCommand(session: session, arguments: [
            "filters": [
                [
                    "services": ["0000180a-0000-1000-8000-00805f9b34fb"],
                    "productData": ["name": "Sensor", "image": "images/tag.png"]
                ],
                [
                    "services": ["180F"],
                    "productData": ["name": "Battery", "image": "images/tag.png"]
                ]
            ] as AnyObject,
            "optionalServices": ["1812"] as AnyObject
        ]) { _ in }

        await command.execute()
        command.handle(.activated)
        let items = session.pickerItems

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.name, "Sensor")
        XCTAssertEqual(items.first?.descriptor.bluetoothServiceUUID, CBUUID(string: "180A"))
        XCTAssertEqual(items.last?.descriptor.bluetoothServiceUUID, CBUUID(string: "180F"))
    }

    func test_execute_rejectsUnrepresentableFilters() async {
        let unsupportedFilters: [[[String: AnyObject]]] = [
            [],
            [["services": ["180A"] as AnyObject]],
            [[
                "services": ["180A", "180F"] as AnyObject,
                "productData": ["name": "Sensor", "image": "images/tag.png"] as AnyObject
            ]],
            [[
                "name": "Sensor" as AnyObject,
                "productData": ["name": "Sensor", "image": "images/tag.png"] as AnyObject
            ]],
            [[
                "namePrefix": "" as AnyObject,
                "productData": ["name": "Sensor", "image": "images/tag.png"] as AnyObject
            ]],
            [[
                "manufacturerData": [[
                    "companyIdentifier": 1,
                    "dataPrefix": [256]
                ]] as AnyObject,
                "productData": ["name": "Sensor", "image": "images/tag.png"] as AnyObject
            ]],
            [[
                "manufacturerData": [
                    ["companyIdentifier": 1],
                    ["companyIdentifier": 2]
                ] as AnyObject,
                "productData": ["name": "Sensor", "image": "images/tag.png"] as AnyObject
            ]]
        ]
        for filters in unsupportedFilters {
            let session = FakeAccessorySession()
            var result: Any?
            let command = makeCommand(session: session, arguments: ["filters": filters as AnyObject]) { result = $0 }

            await command.execute()

            XCTAssertEqual((result as? FlutterError)?.code, "NotSupportedError")
            XCTAssertFalse(session.activated)
        }
    }

    func test_execute_leavesServiceDeclarationValidationToPlatform() async {
        let session = FakeAccessorySession()
        let command = makeCommand(session: session, arguments: [
            "filters": [[
                "services": ["1812"],
                "productData": ["name": "Sensor", "image": "images/tag.png"]
            ]] as AnyObject
        ]) { _ in }

        await command.execute()
        command.handle(.activated)

        XCTAssertTrue(session.activated)
        XCTAssertTrue(session.pickerRequested)
        XCTAssertEqual(session.pickerItems.first?.descriptor.bluetoothServiceUUID, CBUUID(string: "1812"))
    }

    func test_execute_usesAnchoredNamePrefixWhenAvailable() async {
        let session = FakeAccessorySession()
        var result: Any?
        let command = makeCommand(session: session, arguments: [
            "filters": [[
                "namePrefix": "Sensor",
                "productData": ["name": "Sensor", "image": "images/tag.png"]
            ]] as AnyObject
        ]) { result = $0 }

        await command.execute()
        if #available(iOS 18.2, *) {
            command.handle(.activated)
            XCTAssertEqual(session.pickerItems.first?.descriptor.bluetoothNameSubstring, "Sensor")
            XCTAssertEqual(session.pickerItems.first?.descriptor.bluetoothNameSubstringCompareOptions, [.anchored, .literal])
        } else {
            XCTAssertEqual((result as? FlutterError)?.code, "NotSupportedError")
            XCTAssertFalse(session.activated)
        }
    }

    func test_execute_returnsSelectedBluetoothDeviceOnceAfterDismissal() async {
        let session = FakeAccessorySession()
        var results: [Any?] = []
        let command = makeCommand(session: session) { results.append($0) }
        await command.execute()
        XCTAssertTrue(session.activated)
        XCTAssertFalse(session.pickerRequested)

        command.handle(.activated)
        XCTAssertTrue(session.pickerRequested)
        XCTAssertEqual(session.pickerItems.first?.descriptor.bluetoothServiceUUID, CBUUID(string: "180A"))
        let accessory = FakeAccessory()
        command.handle(.accessoryAdded, accessory: accessory)
        XCTAssertTrue(results.isEmpty)
        command.handle(.pickerDidDismiss)
        command.handle(.invalidated)
        command.handle(.pickerDidDismiss)

        XCTAssertEqual(results.count, 1)
        let device = results.first as? [String: AnyObject]
        XCTAssertEqual(device?["id"] as? String, accessory.bluetoothIdentifier?.uuidString)
        XCTAssertEqual(device?["name"] as? String, "Sensor")
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_returnsCancellationWhenPickerDismissesWithoutSelection() async {
        let session = FakeAccessorySession()
        var result: Any?
        let command = makeCommand(session: session) { result = $0 }
        await command.execute()
        command.handle(.activated)
        command.handle(.pickerDidDismiss)

        XCTAssertEqual((result as? FlutterError)?.message, FlutterError.userCancelledError().message)
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_finishesOnActivationError() async {
        let session = FakeAccessorySession()
        var result: Any?
        let command = makeCommand(session: session) { result = $0 }
        await command.execute()
        command.handle(.invalidated, error: NSError(domain: ASErrorDomain, code: ASError.Code.activationFailed.rawValue))

        XCTAssertEqual((result as? FlutterError)?.code, "NotFoundError")
        XCTAssertFalse(session.pickerRequested)
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_reportsConnectionFailureWithUnderlyingDetails() async {
        let session = FakeAccessorySession()
        var results: [Any?] = []
        let command = makeCommand(session: session) { results.append($0) }
        await command.execute()
        let underlyingError = NSError(
            domain: CBErrorDomain,
            code: CBError.Code.connectionFailed.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Accessory refused the connection"]
        )
        command.handle(.pickerSetupFailed, error: NSError(
            domain: ASErrorDomain,
            code: 150,
            userInfo: [
                NSUnderlyingErrorKey: underlyingError,
                NSLocalizedFailureReasonErrorKey: "Connection failed during setup"
            ]
        ))
        command.handle(.pickerDidDismiss)

        XCTAssertEqual(ASError.Code.connectionFailed.rawValue, 150)
        XCTAssertEqual(results.count, 1)
        let error = results.first as? FlutterError
        XCTAssertEqual(error?.code, "NetworkError")
        XCTAssertTrue(error?.message?.contains("could not connect to the selected accessory") ?? false)
        let details = error?.details as? [String: Any]
        XCTAssertEqual(details?["domain"] as? String, ASErrorDomain)
        XCTAssertEqual(details?["code"] as? Int, 150)
        XCTAssertEqual(details?["failureReason"] as? String, "Connection failed during setup")
        let underlyingDetails = details?["underlyingError"] as? [String: Any]
        XCTAssertEqual(underlyingDetails?["domain"] as? String, CBErrorDomain)
        XCTAssertEqual(underlyingDetails?["message"] as? String, "Accessory refused the connection")
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_reportsPickerCompletionConnectionFailure() async {
        let session = FakeAccessorySession()
        session.pickerError = NSError(domain: ASErrorDomain, code: 150)
        let completion = expectation(description: "Connection failure returned")
        var result: Any?
        let command = makeCommand(session: session) {
            result = $0
            completion.fulfill()
        }

        await command.execute()
        command.handle(.activated)
        await fulfillment(of: [completion], timeout: 1)

        XCTAssertEqual((result as? FlutterError)?.code, "NetworkError")
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_forwardsPlatformConfigurationErrorOnce() async {
        let session = FakeAccessorySession()
        session.pickerError = NSError(
            domain: ASErrorDomain,
            code: ASError.Code.invalidRequest.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Invalid accessory configuration"]
        )
        let completion = expectation(description: "Platform error returned")
        var results: [Any?] = []
        let command = makeCommand(session: session) {
            results.append($0)
            completion.fulfill()
        }

        await command.execute()
        command.handle(.activated)
        await fulfillment(of: [completion], timeout: 1)
        command.handle(.pickerDidDismiss)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual((results.first as? FlutterError)?.message, "Invalid accessory configuration")
        XCTAssertTrue(session.activated)
        XCTAssertTrue(session.pickerRequested)
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_returnsNotSupportedForAcceptAllDevices() async {
        let session = FakeAccessorySession()
        var result: Any?
        let command = AccessoryRequestDeviceCommand(
            arguments: ["acceptAllDevices": true as AnyObject],
            session: session,
            pendingResult: { result = $0 }
        )

        await command.execute()

        XCTAssertEqual((result as? FlutterError)?.code, "NotSupportedError")
        XCTAssertFalse(session.activated)
        XCTAssertFalse(session.pickerRequested)
    }
}

@available(iOS 18.0, *)
private final class FakeAccessorySession: ASAccessorySession, @unchecked Sendable {
    var pickerError: Error?
    private(set) var activated = false
    private(set) var pickerRequested = false
    private(set) var pickerItems: [ASPickerDisplayItem] = []
    private(set) var invalidationCount = 0

    override func activate(on queue: DispatchQueue, eventHandler: @escaping (ASAccessoryEvent) -> Void) {
        activated = true
    }

    override func showPicker(for displayItems: [ASPickerDisplayItem], completionHandler: @escaping (Error?) -> Void) {
        pickerRequested = true
        pickerItems = displayItems
        completionHandler(pickerError)
    }

    override func invalidate() {
        invalidationCount += 1
    }
}

@available(iOS 18.0, *)
private final class FakeAccessory: ASAccessory, @unchecked Sendable {
    private let identifier = UUID()
    override var bluetoothIdentifier: UUID? { identifier }
    override var displayName: String { "Sensor" }
    override var state: ASAccessory.AccessoryState { .authorized }
}