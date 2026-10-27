import AccessorySetupKit
import Flutter
import XCTest
@testable import cross_bluetooth_api

@available(iOS 18.0, *)
@MainActor
final class AccessoryGetDevicesCommandTests: XCTestCase {
    func test_execute_returnsOnlyAuthorizedBluetoothAccessories() async throws {
        let session = GetDevicesAccessorySession()
        let target = GetDevicesAccessory(identifier: UUID(), name: "Sensor")
        session.storedAccessories = [
            target,
            GetDevicesAccessory(identifier: nil, name: "Wi-Fi"),
            GetDevicesAccessory(identifier: UUID(), name: "Unauthorized", authorized: false)
        ]
        let result = FakeFlutterResult()
        let command = AccessoryGetDevicesCommand(session: session, pendingResult: result.handler)

        await command.execute()
        XCTAssertTrue(session.activated)
        XCTAssertEqual(result.replyCount, 0)
        command.handle(.activated)

        let devices = try XCTUnwrap(result.value as? [[String: Any]])
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?["id"] as? String, target.bluetoothIdentifier?.uuidString)
        XCTAssertEqual(devices.first?["name"] as? String, "Sensor")
        XCTAssertEqual(session.invalidationCount, 1)
        command.handle(.activated)
        command.handle(.invalidated)
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_returnsEmptyList() async {
        let session = GetDevicesAccessorySession()
        let result = FakeFlutterResult()
        let command = AccessoryGetDevicesCommand(session: session, pendingResult: result.handler)
        await command.execute()
        command.handle(.activated)
        XCTAssertEqual((result.value as? [Any])?.count, 0)
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_reportsActivationErrorsAndInvalidationOnce() async {
        for error in [nil, NSError(domain: "GetDevicesTests", code: 42)] {
            let session = GetDevicesAccessorySession()
            let result = FakeFlutterResult()
            let command = AccessoryGetDevicesCommand(session: session, pendingResult: result.handler)
            await command.execute()
            command.handle(.invalidated, error: error)
            command.handle(.activated)
            XCTAssertEqual((result.value as? FlutterError)?.code, error == nil ? "NetworkError" : "UnknownError")
            XCTAssertEqual(result.replyCount, 1)
            XCTAssertEqual(session.invalidationCount, 1)
        }
    }
}

@MainActor
final class GetDevicesPluginTests: XCTestCase {
    func test_handle_reportsNotImplementedWithoutAccessorySetupKit() throws {
        guard (Bundle.main.object(forInfoDictionaryKey: "NSAccessorySetupKitSupports") as? [String])?
            .contains("Bluetooth") != true else {
            throw XCTSkip("The test host has AccessorySetupKit Bluetooth support configured.")
        }
        let result = FakeFlutterResult()
        SwiftCrossBluetoothApiPlugin().handle(
            FlutterMethodCall(methodName: "getDevices", arguments: nil),
            result: result.handler
        )
        XCTAssertTrue((result.value as? NSObject) === FlutterMethodNotImplemented)
        XCTAssertEqual(result.replyCount, 1)
    }
}

@available(iOS 18.0, *)
private final class GetDevicesAccessorySession: ASAccessorySession, @unchecked Sendable {
    var storedAccessories: [ASAccessory] = []
    private(set) var activated = false
    private(set) var invalidationCount = 0
    override var accessories: [ASAccessory] { storedAccessories }
    override func activate(on queue: DispatchQueue, eventHandler: @escaping (ASAccessoryEvent) -> Void) {
        activated = true
    }
    override func invalidate() {
        invalidationCount += 1
    }
}

@available(iOS 18.0, *)
private final class GetDevicesAccessory: ASAccessory, @unchecked Sendable {
    private let identifier: UUID?
    private let name: String
    private let authorized: Bool
    init(identifier: UUID?, name: String, authorized: Bool = true) {
        self.identifier = identifier
        self.name = name
        self.authorized = authorized
        super.init()
    }
    override var bluetoothIdentifier: UUID? { identifier }
    override var displayName: String { name }
    override var state: ASAccessory.AccessoryState { authorized ? .authorized : .awaitingAuthorization }
}
