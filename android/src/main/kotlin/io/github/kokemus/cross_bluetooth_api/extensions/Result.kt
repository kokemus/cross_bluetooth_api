package io.github.kokemus.cross_bluetooth_api.extensions

import io.flutter.plugin.common.MethodChannel

fun MethodChannel.Result.networkError(message: String = "A network error occurred.") {
    this.error(
        "NetworkError",
        "NetworkError: $message",
        null
    )
}

fun MethodChannel.Result.userCancelledError(message: String = "User cancelled the requestDevice() chooser.") {
    this.error(
        "NotFoundError",
        "NotFoundError: $message",
        null
    )
}

fun MethodChannel.Result.notFoundError(message: String = "There is no Bluetooth device that matches the specified options.") {
    this.error(
        "NotFoundError",
        "NotFoundError: $message",
        null
    )
}

fun MethodChannel.Result.typeError(message: String = "The provided options do not make sense.") {
    this.error(
        "TypeError",
        "TypeError: $message",
        null
    )
}

fun MethodChannel.Result.securityError(message: String = "There is no Bluetooth device that matches the specified options.") {
    this.error(
        "SecurityError",
        "SecurityError: $message",
        null
    )
}

fun MethodChannel.Result.notSupportedError(message: String = "The operation is not supported.") {
    this.error(
        "NotSupportedError",
        "NotSupportedError: $message",
        null
    )
}

fun MethodChannel.Result.invalidStateError(message: String = "Bluetooth is turned off.") {
    this.error(
        "InvalidStateError",
        "InvalidStateError: $message",
        null
    )
}