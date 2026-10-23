import CoreBluetooth
import Flutter
import UIKit
import XCTest
@testable import cross_bluetooth_api

@MainActor
private final class RecordingViewController: UIViewController {
    private(set) var presentedPicker: UIViewController?
    private(set) var presentationAnimated: Bool?
    private(set) var dismissalCount = 0

    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presentedPicker = viewControllerToPresent
        presentationAnimated = animated
        completion?()
    }

    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        dismissalCount += 1
        completion?()
    }
}

@MainActor
final class RequestDeviceCommandTests: XCTestCase {
    func test_execute_presentsActualPickerAndForwardsDiscoveryOptions() async throws {
        let manager = FakeBluetoothManager()
        let presenter = RecordingViewController()
        let result = FakeFlutterResult()
        let command = RequestDeviceCommand(
            manager: manager,
            viewController: presenter,
            arguments: [
                "filters": [["services": ["180F"], "namePrefix": "Sensor"]] as AnyObject,
                "optionalServices": ["180A"] as AnyObject
            ],
            pendingResult: result.handler
        )
        await command.execute()
        let picker = try XCTUnwrap(presenter.presentedPicker as? RequestDeviceViewController)
        picker.loadViewIfNeeded()
        XCTAssertEqual(presenter.presentationAnimated, true)
        XCTAssertEqual(result.replyCount, 0)
        XCTAssertTrue(manager.isScanning)
        XCTAssertEqual(manager.scannedServiceUUIDs, [CBUUID(string: "180F")])
        XCTAssertEqual(manager.scanOptions?[CBCentralManagerScanOptionAllowDuplicatesKey] as? Bool, false)
        XCTAssertTrue(manager.hasDelegate(picker))

        let central = unsafeBitCast(NSObject(), to: CBCentralManager.self)
        let peripheral = FakePeripheralObject(identifier: UUID(), name: "Sensor One").peripheral
        let advertisement: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "180F")]]
        let unrelated = FakePeripheralObject(identifier: UUID(), name: "Other").peripheral
        picker.centralManager(central, didDiscover: unrelated, advertisementData: advertisement, rssi: -40)
        XCTAssertEqual(picker.tableView(UITableView(), numberOfRowsInSection: 0), 0)
        picker.centralManager(central, didDiscover: peripheral, advertisementData: advertisement, rssi: -40)
        picker.centralManager(central, didDiscover: peripheral, advertisementData: advertisement, rssi: -40)
        XCTAssertEqual(picker.tableView(UITableView(), numberOfRowsInSection: 0), 1)
        picker.tableView(UITableView(), didSelectRowAt: IndexPath(row: 0, section: 0))

        let map = result.value as? [String: AnyObject]
        XCTAssertEqual(map?["id"] as? String, peripheral.identifier.uuidString)
        XCTAssertEqual(map?["name"] as? String, "Sensor One")
        XCTAssertEqual(presenter.dismissalCount, 1)
        XCTAssertEqual(result.replyCount, 1)
        picker.viewDidDisappear(false)
        XCTAssertFalse(manager.isScanning)
        XCTAssertFalse(manager.hasDelegate(picker))
        XCTAssertEqual(manager.stopScanCount, 1)
        command.requestDevice(picker, didRequest: peripheral)
        command.requestDevice(picker, didFailWithError: .userCancelled)
        XCTAssertEqual(result.replyCount, 1)
    }

    func test_execute_acceptAllDevicesScansWithoutServiceRestriction() async throws {
        let manager = FakeBluetoothManager()
        let presenter = RecordingViewController()
        let result = FakeFlutterResult()
        let command = RequestDeviceCommand(
            manager: manager,
            viewController: presenter,
            arguments: ["acceptAllDevices": true as AnyObject],
            pendingResult: result.handler
        )
        await command.execute()
        let picker = try XCTUnwrap(presenter.presentedPicker as? RequestDeviceViewController)
        picker.loadViewIfNeeded()
        XCTAssertNil(manager.scannedServiceUUIDs)
        XCTAssertTrue(manager.isScanning)
        XCTAssertEqual(result.replyCount, 0)
        command.requestDevice(picker, didFailWithError: .userCancelled)
        XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
        XCTAssertEqual((result.value as? FlutterError)?.message, FlutterError.userCancelledError().message)
        XCTAssertEqual(result.replyCount, 1)
        picker.viewDidDisappear(false)
    }

    func test_execute_propagatesEveryChooserErrorOnlyOnce() async throws {
        let errors: [RequestDeviceError] = [.unsupported, .unauthorized, .poweredOff, .userCancelled, .unknown]
        for error in errors {
            let manager = FakeBluetoothManager()
            let presenter = RecordingViewController()
            let result = FakeFlutterResult()
            let command = RequestDeviceCommand(
                manager: manager,
                viewController: presenter,
                arguments: ["acceptAllDevices": true as AnyObject],
                pendingResult: result.handler
            )
            await command.execute()
            let picker = try XCTUnwrap(presenter.presentedPicker as? RequestDeviceViewController)
            command.requestDevice(picker, didFailWithError: error)
            command.requestDevice(picker, didFailWithError: error)
            XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
            let expected = error == .userCancelled ? FlutterError.userCancelledError() : FlutterError.notFoundError()
            XCTAssertEqual((result.value as? FlutterError)?.message, expected.message)
            XCTAssertEqual(result.replyCount, 1)
        }
    }

    func test_execute_pickerReportsUnavailableBluetoothWithoutScanning() async throws {
        for state in [CBManagerState.unsupported, .unauthorized, .poweredOff] {
            let manager = FakeBluetoothManager()
            manager.state = state
            let presenter = RecordingViewController()
            let result = FakeFlutterResult()
            let command = RequestDeviceCommand(
                manager: manager,
                viewController: presenter,
                arguments: ["acceptAllDevices": true as AnyObject],
                pendingResult: result.handler
            )
            await command.execute()
            let picker = try XCTUnwrap(presenter.presentedPicker as? RequestDeviceViewController)
            picker.loadViewIfNeeded()
            XCTAssertEqual((result.value as? FlutterError)?.code, "NotFoundError")
            XCTAssertEqual(result.replyCount, 1)
            XCTAssertFalse(manager.isScanning)
            picker.viewDidDisappear(false)
            XCTAssertFalse(manager.hasDelegate(picker))
        }
    }
}
