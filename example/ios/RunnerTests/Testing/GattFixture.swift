import CoreBluetooth
import Flutter
import XCTest
@testable import cross_bluetooth_api

final class TestCharacteristic: CBMutableCharacteristic {
    var notifying = false
    override var isNotifying: Bool { notifying }
}

final class GattFixture {
    let identifier = UUID()
    let manager = FakeBluetoothManager()
    let device: FakeDeviceManager
    let service: CBMutableService
    let characteristic: TestCharacteristic
    let peripheral: CBPeripheral
    let callbackError = NSError(domain: CBErrorDomain, code: CBError.Code.unknown.rawValue)

    init(
        serviceUUID: String = "180F",
        characteristicUUID: String = "2A19",
        primary: Bool = true,
        properties: CBCharacteristicProperties = [.read, .write, .writeWithoutResponse, .notify]
    ) {
        device = FakeDeviceManager(deviceId: identifier.uuidString)
        peripheral = FakePeripheralObject(identifier: identifier, name: "Sensor").peripheral
        service = CBMutableService(type: CBUUID(string: serviceUUID), primary: primary)
        characteristic = TestCharacteristic(
            type: CBUUID(string: characteristicUUID),
            properties: properties,
            value: nil,
            permissions: [.readable, .writeable]
        )
        service.characteristics = [characteristic]
        device.services = [service]
        manager.devices[device.deviceId] = device
    }

    var serviceArguments: [String: AnyObject] {
        [
            "deviceId": device.deviceId as AnyObject,
            "serviceUUID": service.uuid.uuidString as AnyObject
        ]
    }

    var arguments: [String: AnyObject] {
        serviceArguments.merging(["characteristic": characteristic.uuid.uuidString as AnyObject]) { _, new in new }
    }

    var writeArguments: [String: AnyObject] {
        arguments.merging(["value": FlutterStandardTypedData(bytes: Data([0, 255, 127]))]) { _, new in new }
    }
}

func invalidGattArguments(_ arguments: [String: AnyObject]) -> [[String: AnyObject]] {
    arguments.keys.flatMap { key in
        var missing = arguments
        missing.removeValue(forKey: key)
        var wrongType = arguments
        wrongType[key] = 123 as AnyObject
        return [missing, wrongType]
    }
}

@MainActor
extension XCTestCase {
    func startGattCommand(_ command: BaseCommand, fixture: GattFixture) async -> Task<Void, Never> {
        let called = expectation(description: "Device operation started")
        fixture.device.onOperation = { called.fulfill() }
        let task = Task { await command.execute() }
        await fulfillment(of: [called], timeout: 2)
        fixture.device.onOperation = nil
        return task
    }

    func assertChannelBytes(_ result: FakeFlutterResult, equalTo expected: Data) throws {
        let codec = FlutterStandardMethodCodec.sharedInstance()
        let envelope = codec.encodeSuccessEnvelope(result.value)
        let decoded = try XCTUnwrap(codec.decodeEnvelope(envelope) as? FlutterStandardTypedData)
        XCTAssertEqual(decoded.type, .uInt8)
        XCTAssertEqual(decoded.data, expected)
    }

    func assertGattCommandFinished(
        _ command: BaseCommand,
        fixture: GattFixture,
        result: FakeFlutterResult,
        lateCallback: (Error?) -> Void = { _ in },
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.replyCount, 1, file: file, line: line)
        if let delegate = command as? DeviceManagerDelegate {
            XCTAssertFalse(fixture.device.hasDelegate(delegate), file: file, line: line)
        }
        lateCallback(fixture.callbackError)
        lateCallback(nil)
        XCTAssertEqual(result.replyCount, 1, "Command replied twice", file: file, line: line)
    }
}
