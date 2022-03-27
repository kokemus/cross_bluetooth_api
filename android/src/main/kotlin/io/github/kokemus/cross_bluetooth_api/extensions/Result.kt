package io.github.kokemus.cross_bluetooth_api.extensions

import io.flutter.plugin.common.MethodChannel

fun MethodChannel.Result.networkError() {
    this.error(
        "NetworkError",
        "NetworkError: A network error occurred.",
        null
    )
}

fun MethodChannel.Result.userCancelledError() {
    this.error(
        "NotFoundError",
        "NotFoundError: User cancelled the requestDevice() chooser.",
        null
    )
}

fun MethodChannel.Result.notFoundError() {
    this.error(
        "NotFoundError",
        "NotFoundError: There is no Bluetooth device that matches the specified options.",
        null
    )
}

fun MethodChannel.Result.typeError() {
    this.error(
        "TypeError",
        "TypeError: The provided options do not make sense.",
        null
    )
}

fun MethodChannel.Result.securityError() {
    this.error(
        "SecurityError",
        "SecurityError: There is no Bluetooth device that matches the specified options.",
        null
    )
}

fun MethodChannel.Result.notSupportedError() {
    this.error(
        "NotSupportedError",
        "NotSupportedError: The operation is not supported.",
        null
    )
}

fun MethodChannel.Result.invalidStateError() {
    this.error(
        "InvalidStateError",
        "InvalidStateError: Bluetooth is turned off.",
        null
    )
}