import CoreBluetooth
import Flutter
import XCTest
@testable import cross_bluetooth_api

@MainActor
final class WriteValueWithoutResponseCommandTests: XCTestCase {
    func test_execute_writesTypedAndNativeDataWithoutResponseAndCompletesImmediately() async throws {
        for value in [Data([0, 255, 127]), Data()] {
            for typed in [true, false] {
                let fixture = GattFixture()
                fixture.characteristic.value = Data([42])
                let result = FakeFlutterResult()
                var arguments = fixture.writeArguments
                arguments["value"] = typed ? FlutterStandardTypedData(bytes: value) : value as NSData
                let command = WriteValueWithoutResponseCommand(
                    manager: fixture.manager, arguments: arguments, pendingResult: result.handler
                )
                await command.execute()
                XCTAssertEqual(fixture.device.operations, ["write"])
                XCTAssertTrue(fixture.device.writtenCharacteristic === fixture.characteristic)
                XCTAssertEqual(fixture.device.writtenType, .withoutResponse)
                XCTAssertEqual(fixture.device.writtenValue, value)
                XCTAssertEqual(result.value as? Data, value)
                try assertChannelBytes(result, equalTo: value)
                assertGattCommandFinished(command, fixture: fixture, result: result)
            }
        }
    }

    func test_execute_validatesEveryRequiredArgument() async {
        let fixture = GattFixture()
        for arguments in invalidGattArguments(fixture.writeArguments) {
            let result = FakeFlutterResult()
            let command = WriteValueWithoutResponseCommand(
                manager: fixture.manager, arguments: arguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NetworkError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertGattCommandFinished(command, fixture: fixture, result: result)
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
            let command = WriteValueWithoutResponseCommand(
                manager: fixture.manager, arguments: fixture.writeArguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, missing == 0 ? "NetworkError" : "NotFoundError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertGattCommandFinished(command, fixture: fixture, result: result)
        }
    }

    func test_execute_doesNotWriteAnotherServiceOrCharacteristic() async {
        for key in ["serviceUUID", "characteristic"] {
            let fixture = GattFixture()
            var arguments = fixture.writeArguments
            arguments[key] = (key == "serviceUUID" ? "180A" : "2A00") as AnyObject
            let result = FakeFlutterResult()
            let command = WriteValueWithoutResponseCommand(
                manager: fixture.manager, arguments: arguments, pendingResult: result.handler
            )
            await command.execute()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
            XCTAssertTrue(fixture.device.operations.isEmpty)
            assertGattCommandFinished(command, fixture: fixture, result: result)
        }
    }
}
