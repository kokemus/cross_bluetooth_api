package io.github.kokemus.cross_bluetooth_api.testing.fakes

import io.flutter.plugin.common.MethodChannel

class FakeResult : MethodChannel.Result {
    var successValue: Any? = null
    var errorCode: String? = null
    var errorMessage: String? = null
    var notImplementedCalled: Boolean = false
    var successCount = 0
        private set
    var errorCount = 0
        private set
    @Suppress("unused") // Used by command tests to verify exactly-once replies.
    val replyCount: Int
        get() = successCount + errorCount + if (notImplementedCalled) 1 else 0

    override fun success(result: Any?) {
        successCount++
        successValue = result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        errorCount++
        this.errorCode = errorCode
        this.errorMessage = errorMessage
    }

    override fun notImplemented() {
        notImplementedCalled = true
    }
}
