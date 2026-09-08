import XCTest
import Flutter
@testable import cross_bluetooth_api

final class ConnectCommandTests: XCTestCase {

    func test_execute_returnsDeviceMap_whenDidConnectIsEmitted() async {
        let manager = FakeBluetoothManager(connectReturnValue: true)
        let fakeResult = FakeFlutterResult()
        let command = ConnectCommand(
            manager: manager,
            arguments: ["id": "device-id" as AnyObject],
            pendingResult: fakeResult.handler
        )

        let task = Task {
            await command.execute()
        }

        let expectedId = UUID()
        await manager.waitUntilConnectCalled()
        manager.emitDidConnect(identifier: expectedId, name: "Example Device")
        _ = await task.result

        XCTAssertEqual(manager.connectedDeviceIds, ["device-id"])

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
            arguments: ["id": "device-id" as AnyObject],
            pendingResult: fakeResult.handler
        )

        await command.execute()

        XCTAssertEqual(manager.connectedDeviceIds, ["device-id"])

        let error = fakeResult.value as? FlutterError
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, "NetworkError")
    }

    func test_execute_returnsNetworkError_whenDidFailToConnectIsEmitted() async {
        let manager = FakeBluetoothManager(connectReturnValue: true)
        let fakeResult = FakeFlutterResult()
        let command = ConnectCommand(
            manager: manager,
            arguments: ["id": "device-id" as AnyObject],
            pendingResult: fakeResult.handler
        )

        let task = Task {
            await command.execute()
        }

        await manager.waitUntilConnectCalled()
        manager.emitDidFailToConnect()
        _ = await task.result

        XCTAssertEqual(manager.connectedDeviceIds, ["device-id"])
        XCTAssertEqual(manager.removedPeripheralCount, 1)

        let error = fakeResult.value as? FlutterError
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, "NetworkError")
    }
}
