import XCTest
@testable import cross_bluetooth_api

final class CrossBluetoothApiPluginTests: XCTestCase {
    func test_accessorySetup_requiresBluetoothDeclaration() {
        let configurations: [[String: Any]?] = [
            nil,
            [:],
            ["NSAccessorySetupKitSupports": []],
            ["NSAccessorySetupKitSupports": ["WiFi"]],
            ["NSAccessorySetupKitSupports": "Bluetooth"],
            ["NSAccessorySetupKitSupports": ["bluetooth"]]
        ]
        for configuration in configurations {
            XCTAssertFalse(SwiftCrossBluetoothApiPlugin.isAccessorySetupEnabled(infoDictionary: configuration))
        }
    }

    func test_accessorySetup_enabledWithBluetoothDeclarationOnSupportedOS() {
        for supports in [["Bluetooth"], ["WiFi", "Bluetooth"]] {
            let enabled = SwiftCrossBluetoothApiPlugin.isAccessorySetupEnabled(
                infoDictionary: ["NSAccessorySetupKitSupports": supports]
            )
            if #available(iOS 18.0, *) {
                XCTAssertTrue(enabled)
            } else {
                XCTAssertFalse(enabled)
            }
        }
    }
}
