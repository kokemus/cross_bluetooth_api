import Flutter

extension FlutterError {
    static func networkError() -> FlutterError {
        return FlutterError(
            code: "NetworkError",
            message: "NetworkError: A network error occurred.",
            details: nil
        )
    }

    static func notFoundError() -> FlutterError {
        return FlutterError(
            code: "NotFoundError",
            message: "NotFoundError: There is no Bluetooth device that matches the specified options.",
            details: nil
        )
    }

    static func userCancelledError() -> FlutterError {
        return FlutterError(
            code: "NotFoundError",
            message: "NotFoundError: User cancelled the requestDevice() chooser.",
            details: nil
        )
    }

    static func notSupportedError() -> FlutterError {
        return FlutterError(
            code: "NotSupportedError",
            message: "NotSupportedError: Characteristic does not support notifications.",
            details: nil
        )
    }
}
