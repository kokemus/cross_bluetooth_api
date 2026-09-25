package io.github.kokemus.cross_bluetooth_api.commands

import io.github.kokemus.cross_bluetooth_api.services.RequestDeviceLauncher
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

class RequestDeviceCommand(
    private val launcher: RequestDeviceLauncher,
    arguments: Map<String, Any>,
    pendingResult: MethodChannel.Result
) : BaseCommand(CommandId.REQUEST_DEVICE, arguments, pendingResult) {
    override suspend fun execute() {
        suspendCancellableCoroutine { continuation ->
            launcher.launch(arguments, pendingResult) {
                if (continuation.isActive) {
                    continuation.resume(Unit)
                }
            }
        }
    }
}
