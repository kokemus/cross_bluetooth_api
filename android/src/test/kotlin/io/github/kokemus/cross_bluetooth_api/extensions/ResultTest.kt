package io.github.kokemus.cross_bluetooth_api.extensions

import io.github.kokemus.cross_bluetooth_api.testing.fakes.FakeResult
import org.junit.Assert.assertEquals
import org.junit.Test

class ResultTest {
    @Test
    fun helpers_preserveDefaultMessages() {
        val cases = listOf(
            Triple(
                FakeResult().apply { networkError() },
                "NetworkError",
                "NetworkError: A network error occurred."
            ),
            Triple(
                FakeResult().apply { userCancelledError() },
                "NotFoundError",
                "NotFoundError: User cancelled the requestDevice() chooser."
            ),
            Triple(
                FakeResult().apply { notFoundError() },
                "NotFoundError",
                "NotFoundError: There is no Bluetooth device that matches the specified options."
            ),
            Triple(
                FakeResult().apply { typeError() },
                "TypeError",
                "TypeError: The provided options do not make sense."
            ),
            Triple(
                FakeResult().apply { securityError() },
                "SecurityError",
                "SecurityError: There is no Bluetooth device that matches the specified options."
            ),
            Triple(
                FakeResult().apply { notSupportedError() },
                "NotSupportedError",
                "NotSupportedError: The operation is not supported."
            ),
            Triple(
                FakeResult().apply { invalidStateError() },
                "InvalidStateError",
                "InvalidStateError: Bluetooth is turned off."
            )
        )
        for ((result, code, message) in cases) {
            assertEquals(code, result.errorCode)
            assertEquals(message, result.errorMessage)
            assertEquals(1, result.replyCount)
        }
    }

    @Test
    fun helpers_replaceMessageWhilePreservingPrefix() {
        for (message in listOf("Custom failure.", "")) {
            val cases = listOf(
                FakeResult().apply { networkError(message = message) } to "NetworkError",
                FakeResult().apply { userCancelledError(message = message) } to "NotFoundError",
                FakeResult().apply { notFoundError(message = message) } to "NotFoundError",
                FakeResult().apply { typeError(message = message) } to "TypeError",
                FakeResult().apply { securityError(message = message) } to "SecurityError",
                FakeResult().apply { notSupportedError(message = message) } to "NotSupportedError",
                FakeResult().apply { invalidStateError(message = message) } to "InvalidStateError"
            )
            for ((result, code) in cases) {
                assertEquals(code, result.errorCode)
                assertEquals("$code: $message", result.errorMessage)
                assertEquals(1, result.replyCount)
            }
        }
    }
}
