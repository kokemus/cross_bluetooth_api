package io.github.kokemus.cross_bluetooth_api.commands

import io.flutter.plugin.common.MethodChannel

abstract class BaseCommand(
    protected val id: CommandId,
    protected val arguments: Map<String, Any>,
    protected val pendingResult: MethodChannel.Result
) : Command
