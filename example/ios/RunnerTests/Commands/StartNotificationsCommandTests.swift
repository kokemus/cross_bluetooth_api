import CoreBluetooth
import Flutter
import XCTest
@testable import cross_bluetooth_api

@MainActor
final class StartNotificationsCommandTests: XCTestCase {
    private func assertFinished(_ command: StartNotificationsCommand, fixture: GattFixture, result: FakeFlutterResult) {
        assertGattCommandFinished(command, fixture: fixture, result: result) { error in
            command.peripheral(fixture.peripheral, didUpdateNotificationStateFor: fixture.characteristic, error: error)
        }
    }

    func test_execute_enablesNotificationsOrIndicationsAndWaitsForStateCallback() async {
        let properties: [CBCharacteristicProperties] = [.notify, .indicate, [.notify, .indicate]]
        for property in properties {
            let fixture = GattFixture(properties: property)
            let result = FakeFlutterResult()
            let command = StartNotificationsCommand(
                manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
            )
            let task = await startGattCommand(command, fixture: fixture)
            XCTAssertEqual(result.replyCount, 0)
            XCTAssertEqual(fixture.device.operations, ["notification"])
            XCTAssertTrue(fixture.device.notificationCharacteristic === fixture.characteristic)
            XCTAssertEqual(fixture.device.notificationEnabled, true)
            fixture.characteristic.notifying = true
            fixture.device.emitNotificationState(fixture.peripheral, characteristic: fixture.characteristic)
            await task.value
            XCTAssertEqual(result.value as? Bool, true)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_validatesEveryRequiredArgument() async {
        let fixture = GattFixture()
        for arguments in invalidGattArguments(fixture.arguments) {
            let result = FakeFlutterResult()
            let command = StartNotificationsCommand(
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
            let command = StartNotificationsCommand(
                manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, missing == 0 ? "NetworkError" : "NotFoundError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_doesNotEnableAnotherServiceOrCharacteristic() async {
        for key in ["serviceUUID", "characteristic"] {
            let fixture = GattFixture()
            var arguments = fixture.arguments
            arguments[key] = (key == "serviceUUID" ? "180A" : "2A00") as AnyObject
            let result = FakeFlutterResult()
            let command = StartNotificationsCommand(
                manager: fixture.manager, arguments: arguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_returnsNetworkErrorForFailedStateCallback() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = StartNotificationsCommand(
            manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        fixture.device.emitNotificationState(fixture.peripheral, characteristic: fixture.characteristic, error: fixture.callbackError)
        await task.value
        XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
        assertFinished(command, fixture: fixture, result: result)
    }

    func test_execute_ignoresStateCallbacksForOtherTargetsEvenOnError() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = StartNotificationsCommand(
            manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        let otherPeripheral = FakePeripheralObject(identifier: UUID(), name: nil).peripheral
        let wrongService = GattFixture(serviceUUID: "180A")
        let wrongCharacteristic = GattFixture(characteristicUUID: "2A00")
        for error in [nil, fixture.callbackError] {
            command.peripheral(otherPeripheral, didUpdateNotificationStateFor: fixture.characteristic, error: error)
            command.peripheral(fixture.peripheral, didUpdateNotificationStateFor: wrongService.characteristic, error: error)
            command.peripheral(fixture.peripheral, didUpdateNotificationStateFor: wrongCharacteristic.characteristic, error: error)
            XCTAssertEqual(result.replyCount, 0)
            XCTAssertTrue(fixture.device.hasDelegate(command))
        }
        fixture.characteristic.notifying = true
        fixture.device.emitNotificationState(fixture.peripheral, characteristic: fixture.characteristic)
        await task.value
        assertFinished(command, fixture: fixture, result: result)
    }

    func test_execute_rejectsUnsupportedPropertiesWithoutStartingOperation() async {
        let fixture = GattFixture(properties: .read)
        let result = FakeFlutterResult()
        let command = StartNotificationsCommand(
            manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
        )
        await command.execute()
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotSupportedError")
        XCTAssertTrue(fixture.device.operations.isEmpty)
        assertFinished(command, fixture: fixture, result: result)
    }

    func test_execute_returnsNetworkErrorWhenNotificationsRemainDisabled() async {
        let fixture = GattFixture()
        let result = FakeFlutterResult()
        let command = StartNotificationsCommand(
            manager: fixture.manager, arguments: fixture.arguments, pendingResult: result.handler
        )
        let task = await startGattCommand(command, fixture: fixture)
        fixture.device.emitNotificationState(fixture.peripheral, characteristic: fixture.characteristic)
        await task.value
        XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
        assertFinished(command, fixture: fixture, result: result)
    }
}
