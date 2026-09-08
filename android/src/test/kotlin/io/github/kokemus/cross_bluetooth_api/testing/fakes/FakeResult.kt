package io.github.kokemus.cross_bluetooth_api.testing.fakes

import io.flutter.plugin.common.MethodChannel

class FakeResult : MethodChannel.Result {
    var successValue: Any? = null
    var errorCode: String? = null
    var errorMessage: String? = null
    var notImplementedCalled: Boolean = false

    override fun success(result: Any?) {
        successValue = result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        this.errorCode = errorCode
        this.errorMessage = errorMessage
    }

    override fun notImplemented() {
        notImplementedCalled = true
    }
}
