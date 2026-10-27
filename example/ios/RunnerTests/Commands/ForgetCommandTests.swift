import AccessorySetupKit
import Flutter
import XCTest
@testable import cross_bluetooth_api

@available(iOS 18.0, *)
@MainActor
final class AccessoryForgetCommandTests: XCTestCase {
    func test_execute_removesOnlyMatchingAccessory() async {
        let session = ForgetAccessorySession()
        let target = ForgetAccessory()
        session.storedAccessories = [ForgetAccessory(), target]
        let replied = expectation(description: "Forget completed")
        let result = FakeFlutterResult()
        let command = AccessoryForgetCommand(
            arguments: ["id": target.bluetoothIdentifier!.uuidString as AnyObject],
            session: session
        ) {
            result.handler($0)
            replied.fulfill()
        }
        await command.execute()
        XCTAssertTrue(session.activated)
        XCTAssertEqual(result.replyCount, 0)

        command.handle(.activated)
        command.handle(.activated)
        XCTAssertEqual(session.removedAccessories.count, 1)
        XCTAssertTrue(session.removedAccessories.first === target)
        await fulfillment(of: [replied], timeout: 2)

        XCTAssertNil(result.value)
        XCTAssertEqual(session.invalidationCount, 1)
        command.handle(.invalidated)
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_reportsUnsupportedForNonAccessory() async {
        let session = ForgetAccessorySession()
        session.storedAccessories = [ForgetAccessory()]
        let identifier = UUID().uuidString
        let result = FakeFlutterResult()
        let command = AccessoryForgetCommand(
            arguments: ["id": identifier as AnyObject],
            session: session,
            pendingResult: result.handler
        )
        await command.execute()
        command.handle(.activated)
        XCTAssertTrue(session.removedAccessories.isEmpty)
        XCTAssertEqual(result.replyCount, 1)
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotSupportedError")
    }

    func test_execute_preservesDeviceOnRemovalFailure() async {
        let session = ForgetAccessorySession()
        let target = ForgetAccessory()
        session.storedAccessories = [target]
        session.removalError = NSError(domain: "ForgetTests", code: 42)
        let replied = expectation(description: "Error reported")
        let result = FakeFlutterResult()
        let command = AccessoryForgetCommand(
            arguments: ["id": target.bluetoothIdentifier!.uuidString as AnyObject],
            session: session
        ) {
            result.handler($0)
            replied.fulfill()
        }
        await command.execute()
        command.handle(.activated)
        await fulfillment(of: [replied], timeout: 2)
        XCTAssertEqual((result.value as? FlutterError)?.code, "UnknownError")
        XCTAssertEqual(session.invalidationCount, 1)
    }

    func test_execute_reportsActivationFailureOnlyOnce() async {
        let session = ForgetAccessorySession()
        let result = FakeFlutterResult()
        let command = AccessoryForgetCommand(
            arguments: ["id": UUID().uuidString as AnyObject],
            session: session,
            pendingResult: result.handler
        )
        await command.execute()
        command.handle(.invalidated, error: NSError(domain: "ForgetTests", code: 1))
        command.handle(.activated)
        XCTAssertEqual((result.value as? FlutterError)?.code, "UnknownError")
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_rejectsInvalidIdentifierBeforeActivating() async {
        let session = ForgetAccessorySession()
        let result = FakeFlutterResult()
        let command = AccessoryForgetCommand(
            arguments: ["id": "invalid" as AnyObject],
            session: session,
            pendingResult: result.handler
        )
        await command.execute()
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
        XCTAssertFalse(session.activated)
    }
}

@available(iOS 18.0, *)
private final class ForgetAccessorySession: ASAccessorySession, @unchecked Sendable {
    var storedAccessories: [ASAccessory] = []
    var removalError: Error?
    private(set) var activated = false
    private(set) var removedAccessories: [ASAccessory] = []
    private(set) var invalidationCount = 0

    override var accessories: [ASAccessory] { storedAccessories }

    override func activate(on queue: DispatchQueue, eventHandler: @escaping (ASAccessoryEvent) -> Void) {
        activated = true
    }

    override func removeAccessory(_ accessory: ASAccessory, completionHandler: @escaping (Error?) -> Void) {
        removedAccessories.append(accessory)
        completionHandler(removalError)
    }

    override func invalidate() {
        invalidationCount += 1
    }
}

@available(iOS 18.0, *)
private final class ForgetAccessory: ASAccessory, @unchecked Sendable {
    private let identifier = UUID()
    override var bluetoothIdentifier: UUID? { identifier }
}
