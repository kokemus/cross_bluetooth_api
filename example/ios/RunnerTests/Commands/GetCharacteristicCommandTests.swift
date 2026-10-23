import CoreBluetooth
import Flutter
import XCTest
@testable import cross_bluetooth_api

@MainActor
final class GetCharacteristicCommandTests: XCTestCase {
    private func assertFinished(_ command: GetCharacteristicCommand, fixture: GattFixture, result: FakeFlutterResult) {
        assertGattCommandFinished(command, fixture: fixture, result: result) { error in
            command.peripheral(fixture.peripheral, didDiscoverCharacteristicsFor: fixture.service, error: error)
        }
    }

    func test_execute_discoversTargetAndReturnsOnlyUuid() async throws {
        for primary in [true, false] {
            let fixture = GattFixture(primary: primary)
            let result = FakeFlutterResult()
            let command = GetCharacteristicCommand(
                manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
            )
            let task = await startGattCommand(command, fixture: fixture)
            XCTAssertEqual(result.replyCount, 0)
            XCTAssertEqual(fixture.device.operations, ["characteristics"])
            XCTAssertTrue(fixture.device.discoveredService === fixture.service)
            XCTAssertEqual(fixture.device.discoveredCharacteristicUUIDs, [fixture.characteristic.uuid])
            fixture.device.emitCharacteristicsDiscovered(fixture.peripheral, service: fixture.service)
            await task.value
            let map = try XCTUnwrap(result.value as? [String: AnyObject])
            XCTAssertEqual(Set(map.keys), ["uuid"])
            XCTAssertEqual(map["uuid"] as? String, fixture.characteristic.uuid.uuidString)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_validatesEveryRequiredArgument() async {
        let fixture = GattFixture()
        for arguments in invalidGattArguments(fixture.arguments) {
            let result = FakeFlutterResult()
            let command = GetCharacteristicCommand(
                manager: fixture.manager, arguments: arguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_reportsMissingDeviceServiceOrCharacteristic() async {
        for missing in 0...2 {
            let fixture = GattFixture()
            if missing == 0 {
                fixture.manager.devices.removeAll()
            } else if missing == 1 {
                fixture.device.services.removeAll()
            } else {
                fixture.service.characteristics = []
            }
            let result = FakeFlutterResult()
            let command = GetCharacteristicCommand(
                manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
            )
            if missing == 2 {
                let task = await startGattCommand(command, fixture: fixture)
                fixture.device.emitCharacteristicsDiscovered(fixture.peripheral, service: fixture.service)
                await task.value
            } else {
                await command.execute()
                XCTAssertTrue(fixture.device.operations.isEmpty)
            }
            XCTAssertEqual((result.value as? FlutterError)?.code, missing == 0 ? "NetworkError" : "NotFoundError")
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_doesNotReturnAnotherServiceOrCharacteristic() async {
        for key in ["serviceUUID", "characteristic"] {
            let fixture = GattFixture()
            var arguments = fixture.arguments
            arguments[key] = (key == "serviceUUID" ? "180A" : "2A00") as AnyObject
            let result = FakeFlutterResult()
            let command = GetCharacteristicCommand(
                manager: fixture.manager, arguments: arguments, pendingResult: result.handler
            )
            if key == "characteristic" {
                let task = await startGattCommand(command, fixture: fixture)
                fixture.device.emitCharacteristicsDiscovered(fixture.peripheral, service: fixture.service)
                await task.value
            } else {
                await command.execute()
                XCTAssertTrue(fixture.device.operations.isEmpty)
            }
            XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_returnsNotFoundForFailedDiscoveryCallback() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = GetCharacteristicCommand(
            manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        fixture.device.emitCharacteristicsDiscovered(fixture.peripheral, service: fixture.service, error: fixture.callbackError)
        await task.value
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
        assertFinished(command, fixture: fixture, result: result)
    }

    func test_execute_ignoresCallbacksForOtherDevicesOrServicesEvenOnError() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = GetCharacteristicCommand(
            manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        let otherPeripheral = FakePeripheralObject(identifier: UUID(), name: nil).peripheral
        let wrongService = GattFixture(serviceUUID: "180A")
        for error in [nil, fixture.callbackError] {
            command.peripheral(otherPeripheral, didDiscoverCharacteristicsFor: fixture.service, error: error)
            command.peripheral(fixture.peripheral, didDiscoverCharacteristicsFor: wrongService.service, error: error)
            XCTAssertEqual(result.replyCount, 0)
            XCTAssertTrue(fixture.device.hasDelegate(command))
        }
        fixture.device.emitCharacteristicsDiscovered(fixture.peripheral, service: fixture.service)
        await task.value
        assertFinished(command, fixture: fixture, result: result)
    }
}
