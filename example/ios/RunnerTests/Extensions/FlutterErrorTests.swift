import Flutter
import XCTest
@testable import cross_bluetooth_api

final class FlutterErrorTests: XCTestCase {
    func test_helpers_preserveDefaultMessages() {
        let cases: [(error: FlutterError, code: String, message: String)] = [
            (FlutterError.networkError(), "NetworkError", "NetworkError: A network error occurred."),
            (
                FlutterError.notFoundError(),
                "NotFoundError",
                "NotFoundError: There is no Bluetooth device that matches the specified options."
            ),
            (
                FlutterError.userCancelledError(),
                "NotFoundError",
                "NotFoundError: User cancelled the requestDevice() chooser."
            ),
            (
                FlutterError.notSupportedError(),
                "NotSupportedError",
                "NotSupportedError: Characteristic does not support notifications."
            )
        ]
        for testCase in cases {
            XCTAssertEqual(testCase.error.code, testCase.code)
            XCTAssertEqual(testCase.error.message, testCase.message)
            XCTAssertNil(testCase.error.details)
        }
    }

    func test_helpers_replaceMessageWhilePreservingPrefix() {
        for message in ["Custom failure.", ""] {
            let cases: [(error: FlutterError, code: String)] = [
                (FlutterError.networkError(message: message), "NetworkError"),
                (FlutterError.notFoundError(message: message), "NotFoundError"),
                (FlutterError.userCancelledError(message: message), "NotFoundError"),
                (FlutterError.notSupportedError(message: message), "NotSupportedError")
            ]
            for testCase in cases {
                XCTAssertEqual(testCase.error.code, testCase.code)
                XCTAssertEqual(testCase.error.message, "\(testCase.code): \(message)")
                XCTAssertNil(testCase.error.details)
            }
        }
    }
}
