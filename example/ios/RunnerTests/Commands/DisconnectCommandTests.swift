import CoreBluetooth
import Flutter
import XCTest
@testable import cross_bluetooth_api

@MainActor
final class DisconnectCommandTests: XCTestCase {
    func test_execute_waitsForTargetDisconnectAndCompletesOnlyOnce() async {
        let identifier = UUID()
        let manager = FakeBluetoothManager()
        let result = FakeFlutterResult()
        let command = DisconnectCommand(
            manager: manager,
            arguments: ["id": identifier.uuidString as AnyObject],
            pendingResult: result.handler
        )
        let called = expectation(description: "Disconnect requested")
        manager.onOperation = { called.fulfill() }
        let task = Task { await command.execute() }
        await fulfillment(of: [called], timeout: 2)

        XCTAssertEqual(manager.disconnectedDeviceIds, [identifier.uuidString])
        XCTAssertEqual(result.replyCount, 0)
        manager.emitDidDisconnect(identifier: UUID())
        XCTAssertEqual(result.replyCount, 0)
        XCTAssertTrue(manager.hasDelegate(command))
        manager.emitDidDisconnect(identifier: identifier)
        await task.value

        let map = result.value as? [String: AnyObject]
        XCTAssertEqual(map?["id"] as? String, identifier.uuidString)
        XCTAssertEqual(map?["name"] as? String, "Example Device")
        XCTAssertFalse(manager.hasDelegate(command))
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let peripheral = FakePeripheralObject(identifier: identifier, name: nil).peripheral
        command.centralManager(central, didDisconnectPeripheral: peripheral, error: nil)
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_returnsNetworkErrorForMissingOrInvalidIdentifier() async {
        let arguments: [[String: AnyObject]] = [[:], ["id": 123 as AnyObject]]
        for arguments in arguments {
            let manager = FakeBluetoothManager()
            let result = FakeFlutterResult()
            let command = DisconnectCommand(manager: manager, arguments: arguments, pendingResult: result.handler)
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
            XCTAssertEqual(result.replyCount, 1)
            XCTAssertTrue(manager.disconnectedDeviceIds.isEmpty)
            XCTAssertFalse(manager.hasDelegate(command))
        }
    }

    func test_execute_returnsNetworkErrorWhenDisconnectIsRejected() async {
        let manager = FakeBluetoothManager()
        manager.disconnectReturnValue = false
        let identifier = UUID()
        let result = FakeFlutterResult()
        let command = DisconnectCommand(
            manager: manager,
            arguments: ["id": identifier.uuidString as AnyObject],
            pendingResult: result.handler
        )
        await command.execute()
        XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
        XCTAssertEqual(manager.disconnectedDeviceIds, [identifier.uuidString])
        XCTAssertFalse(manager.hasDelegate(command))
        manager.emitDidDisconnect(identifier: identifier)
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_returnsNetworkErrorForFailedDisconnectCallback() async {
        let identifier = UUID()
        let manager = FakeBluetoothManager()
        let result = FakeFlutterResult()
        let command = DisconnectCommand(
            manager: manager,
            arguments: ["id": identifier.uuidString as AnyObject],
            pendingResult: result.handler
        )
        let called = expectation(description: "Disconnect requested")
        manager.onOperation = { called.fulfill() }
        let task = Task { await command.execute() }
        await fulfillment(of: [called], timeout: 2)
        manager.emitDidDisconnect(identifier: identifier, error: NSError(domain: CBErrorDomain, code: 0))
        await task.value
        XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
        XCTAssertEqual(result.replyCount, 1)
        XCTAssertFalse(manager.hasDelegate(command))
    }
}
