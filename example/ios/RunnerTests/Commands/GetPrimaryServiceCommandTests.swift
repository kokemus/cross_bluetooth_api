import CoreBluetooth
import Flutter
import XCTest
@testable import cross_bluetooth_api

@MainActor
final class GetPrimaryServiceCommandTests: XCTestCase {
    private func assertFinished(_ command: GetPrimaryServiceCommand, fixture: GattFixture, result: FakeFlutterResult) {
        assertGattCommandFinished(command, fixture: fixture, result: result) { error in
            command.peripheral(fixture.peripheral, didDiscoverServices: error)
        }
    }

    func test_execute_discoversOnlyTargetAndReturnsUuidAndPrimaryFlag() async throws {
        for primary in [true, false] {
            let fixture = GattFixture(primary: primary)
            let result = FakeFlutterResult()
            let command = GetPrimaryServiceCommand(
                manager: fixture.manager, arguments: fixture.serviceArguments, pendingResult: result.handler
            )
            let task = await startGattCommand(command, fixture: fixture)
            XCTAssertEqual(result.replyCount, 0)
            XCTAssertEqual(fixture.device.operations, ["services"])
            XCTAssertEqual(fixture.device.discoveredServiceUUIDs, [fixture.service.uuid])
            fixture.device.emitServicesDiscovered(fixture.peripheral)
            await task.value
            let map = try XCTUnwrap(result.value as? [String: AnyObject])
            XCTAssertEqual(Set(map.keys), ["uuid", "isPrimary"])
            XCTAssertEqual(map["uuid"] as? String, fixture.service.uuid.uuidString)
            XCTAssertEqual(map["isPrimary"] as? Bool, primary)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_validatesEveryRequiredArgument() async {
        let fixture = GattFixture()
        for arguments in invalidGattArguments(fixture.serviceArguments) {
            let result = FakeFlutterResult()
            let command = GetPrimaryServiceCommand(
                manager: fixture.manager, arguments: arguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_reportsMissingDeviceOrService() async {
        for missingDevice in [true, false] {
            let fixture = GattFixture()
            if missingDevice {
                fixture.manager.devices.removeAll()
            } else {
                fixture.device.services.removeAll()
            }
            let result = FakeFlutterResult()
            let command = GetPrimaryServiceCommand(
                manager: fixture.manager, arguments: fixture.serviceArguments, pendingResult: result.handler
            )
            if missingDevice {
                await command.execute()
                XCTAssertTrue(fixture.device.operations.isEmpty)
            } else {
                let task = await startGattCommand(command, fixture: fixture)
                fixture.device.emitServicesDiscovered(fixture.peripheral)
                await task.value
            }
            XCTAssertEqual((result.value as? FlutterError)?.code, missingDevice ? "NetworkError" : "NotFoundError")
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_doesNotReturnAnotherService() async {
        let fixture = GattFixture()
        var arguments = fixture.serviceArguments
        arguments["serviceUUID"] = "180A" as AnyObject
        let result = FakeFlutterResult()
        let command = GetPrimaryServiceCommand(
            manager: fixture.manager, arguments: arguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        fixture.device.emitServicesDiscovered(fixture.peripheral)
        await task.value
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
        assertFinished(command, fixture: fixture, result: result)
    }

    func test_execute_returnsNotFoundForFailedDiscoveryCallback() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = GetPrimaryServiceCommand(
            manager: fixture.manager, arguments: fixture.serviceArguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        fixture.device.emitServicesDiscovered(fixture.peripheral, error: fixture.callbackError)
        await task.value
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
        assertFinished(command, fixture: fixture, result: result)
    }

    func test_execute_ignoresCallbacksFromOtherDevicesEvenOnError() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = GetPrimaryServiceCommand(
            manager: fixture.manager, arguments: fixture.serviceArguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        let otherPeripheral = FakePeripheralObject(identifier: UUID(), name: nil).peripheral
        for error in [nil, fixture.callbackError] {
            command.peripheral(otherPeripheral, didDiscoverServices: error)
            XCTAssertEqual(result.replyCount, 0)
            XCTAssertTrue(fixture.device.hasDelegate(command))
        }
        fixture.device.emitServicesDiscovered(fixture.peripheral)
        await task.value
        assertFinished(command, fixture: fixture, result: result)
    }
}
