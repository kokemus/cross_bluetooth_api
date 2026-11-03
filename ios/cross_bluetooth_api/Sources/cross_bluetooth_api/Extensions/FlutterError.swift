import Flutter

extension FlutterError {
    static func networkError(message: String = "A network error occurred.", details: Any? = nil) -> FlutterError {
        return FlutterError(
            code: "NetworkError",
            message: "NetworkError: \(message)",
            details: details
        )
    }

    static func notFoundError(message: String = "There is no Bluetooth device that matches the specified options.", details: Any? = nil) -> FlutterError {
        return FlutterError(
            code: "NotFoundError",
            message: "NotFoundError: \(message)",
            details: details
        )
    }

    static func userCancelledError(message: String = "User cancelled the requestDevice() chooser.") -> FlutterError {
        return FlutterError(
            code: "NotFoundError",
            message: "NotFoundError: \(message)",
            details: nil
        )
    }

    static func notSupportedError(message: String = "Characteristic does not support notifications.") -> FlutterError {
        return FlutterError(
            code: "NotSupportedError",
            message: "NotSupportedError: \(message)",
            details: nil
        )
    }
}
