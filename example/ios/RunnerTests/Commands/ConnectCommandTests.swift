import XCTest
import Flutter
import CoreBluetooth
@testable import cross_bluetooth_api

@MainActor
final class ConnectCommandTests: XCTestCase {
    private let deviceId = UUID()

    func test_execute_returnsDeviceMap_whenDidConnectIsEmitted() async {
        let manager = FakeBluetoothManager(connectReturnValue: true)
        let fakeResult = FakeFlutterResult()
        let command = ConnectCommand(
            manager: manager,
            arguments: ["id": deviceId.uuidString as AnyObject],
            pendingResult: fakeResult.handler
        )

        let task = Task {
            await command.execute()
        }

        let expectedId = deviceId
        await manager.waitUntilConnectCalled()
        manager.emitDidConnect(identifier: expectedId, name: "Example Device")
        _ = await task.result

        XCTAssertEqual(manager.connectedDeviceIds, [deviceId.uuidString])
        XCTAssertFalse(manager.hasDelegate(command))
        XCTAssertEqual(fakeResult.replyCount, 1)

        let map = fakeResult.value as? [String: AnyObject]
        XCTAssertNotNil(map)
        XCTAssertEqual(map?["id"] as? String, expectedId.uuidString)
        XCTAssertEqual(map?["name"] as? String, "Example Device")
    }

    func test_execute_returnsNetworkError_whenConnectReturnsFalse() async {
        let manager = FakeBluetoothManager(connectReturnValue: false)
        let fakeResult = FakeFlutterResult()
        let command = ConnectCommand(
            manager: manager,
            arguments: ["id": deviceId.uuidString as AnyObject],
            pendingResult: fakeResult.handler
        )

        await command.execute()

        XCTAssertEqual(manager.connectedDeviceIds, [deviceId.uuidString])
        XCTAssertFalse(manager.hasDelegate(command))
        XCTAssertEqual(fakeResult.replyCount, 1)

        let error = fakeResult.value as? FlutterError
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, "NetworkError")
    }

    func test_execute_returnsNetworkError_whenDidFailToConnectIsEmitted() async {
        let manager = FakeBluetoothManager(connectReturnValue: true)
        let fakeResult = FakeFlutterResult()
        let command = ConnectCommand(
            manager: manager,
            arguments: ["id": deviceId.uuidString as AnyObject],
            pendingResult: fakeResult.handler
        )

        let task = Task {
            await command.execute()
        }

        await manager.waitUntilConnectCalled()
        manager.emitDidFailToConnect(identifier: deviceId)
        _ = await task.result

        XCTAssertEqual(manager.connectedDeviceIds, [deviceId.uuidString])
        XCTAssertFalse(manager.hasDelegate(command))
        XCTAssertEqual(fakeResult.replyCount, 1)
        XCTAssertEqual(manager.removedPeripheralCount, 1)

        let error = fakeResult.value as? FlutterError
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, "NetworkError")
    }

    func test_execute_ignoresOtherDevicesAndDuplicateCallbacks() async {
        let manager = FakeBluetoothManager()
        let result = FakeFlutterResult()
        let command = ConnectCommand(
            manager: manager,
            arguments: ["id": deviceId.uuidString as AnyObject],
            pendingResult: result.handler
        )
        let task = Task { await command.execute() }
        await manager.waitUntilConnectCalled()

        manager.emitDidConnect(identifier: UUID())
        manager.emitDidFailToConnect(identifier: UUID())
        XCTAssertEqual(result.replyCount, 0)
        XCTAssertEqual(manager.removedPeripheralCount, 0)
        XCTAssertTrue(manager.hasDelegate(command))

        manager.emitDidConnect(identifier: deviceId)
        await task.value
        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let peripheral = FakePeripheralObject(identifier: deviceId, name: nil).peripheral
        command.centralManager(central, didConnect: peripheral)
        command.centralManager(central, didFailToConnect: peripheral, error: nil)
        XCTAssertEqual(result.replyCount, 1)
        XCTAssertFalse(manager.hasDelegate(command))
    }

    func test_execute_rejectsMissingInvalidAndMalformedIdentifiers() async {
        let invalidArguments: [[String: AnyObject]] = [
            [:], ["id": 123 as AnyObject], ["id": "invalid" as AnyObject]
        ]
        for arguments in invalidArguments {
            let manager = FakeBluetoothManager()
            let result = FakeFlutterResult()
            let command = ConnectCommand(manager: manager, arguments: arguments, pendingResult: result.handler)
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
            XCTAssertEqual(result.replyCount, 1)
            XCTAssertTrue(manager.connectedDeviceIds.isEmpty)
            XCTAssertFalse(manager.hasDelegate(command))
        }
    }
}
