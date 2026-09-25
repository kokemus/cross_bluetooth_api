package io.github.kokemus.cross_bluetooth_api

import android.Manifest
import android.bluetooth.BluetoothGattCharacteristic
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresPermission
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.github.kokemus.cross_bluetooth_api.commands.*
import io.github.kokemus.cross_bluetooth_api.events.CharacteristicValueChangedEvent
import io.github.kokemus.cross_bluetooth_api.events.GattServerDisconnectedEvent
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerImp
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerListener
import io.github.kokemus.cross_bluetooth_api.services.DeviceManager
import io.github.kokemus.cross_bluetooth_api.services.DeviceManagerListener
import io.github.kokemus.cross_bluetooth_api.services.RequestDeviceLauncher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class CrossBluetoothApiPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, BluetoothManagerListener,
  DeviceManagerListener {
  private lateinit var channel : MethodChannel
  private lateinit var bluetoothManager: BluetoothManager
  private val requestDeviceLauncher = RequestDeviceLauncher()
  private val commandScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cross_bluetooth_api")
    channel.setMethodCallHandler(this)

    bluetoothManager = BluetoothManagerImp(flutterPluginBinding.applicationContext)
    bluetoothManager.addListener(this)

    val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "cross_bluetooth_api/events")
    eventChannel.setStreamHandler(streamHandler)
  }

  internal var eventSink: EventChannel.EventSink? = null
  internal val handler = Handler(Looper.getMainLooper())

  private val streamHandler = object: EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
      eventSink = events
    }

    override fun onCancel(arguments: Any?) {
      eventSink = null
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    bluetoothManager.removeListener(this)
    bluetoothManager.removeAllListeners()
    commandScope.cancel()
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
    requestDeviceLauncher.attach(activityPluginBinding)
  }

  override fun onDetachedFromActivity() {
    requestDeviceLauncher.detach()
  }

  override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {
    requestDeviceLauncher.attach(activityPluginBinding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    requestDeviceLauncher.detach()
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  override fun onMethodCall(call: MethodCall, result: Result) {
    @Suppress("UNCHECKED_CAST")
    val arguments = call.arguments as? Map<String, Any> ?: emptyMap()

    val command = when (CommandId.fromMethod(call.method)) {
      CommandId.REQUEST_DEVICE -> RequestDeviceCommand(requestDeviceLauncher, arguments, result)
      CommandId.CONNECT -> ConnectCommand(bluetoothManager, arguments, result)
      CommandId.DISCONNECT -> DisconnectCommand(bluetoothManager, arguments, result)
      CommandId.GET_PRIMARY_SERVICE -> GetPrimaryServiceCommand(bluetoothManager, arguments, result)
      CommandId.GET_CHARACTERISTIC -> GetCharacteristicCommand(bluetoothManager, arguments, result)
      CommandId.READ_VALUE -> ReadValueCommand(bluetoothManager, arguments, result)
      CommandId.WRITE_VALUE_WITHOUT_RESPONSE -> WriteValueWithoutResponseCommand(bluetoothManager, arguments, result)
      CommandId.WRITE_VALUE_WITH_RESPONSE -> WriteValueWithResponseCommand(bluetoothManager, arguments, result)
      CommandId.START_NOTIFICATIONS -> StartNotificationsCommand(bluetoothManager, arguments, result)
      CommandId.STOP_NOTIFICATIONS -> StopNotificationsCommand(bluetoothManager, arguments, result)
      null -> null
    }

    if (command == null) {
      result.notImplemented()
      return
    }

    commandScope.launch {
      command.execute()
    }
  }

  override fun onConnected(deviceManager: DeviceManager) {
    deviceManager.addListener(this)
  }

  override fun onDisconnected(deviceId: String) {
    handler.post {
      eventSink?.success(GattServerDisconnectedEvent(deviceId).toMap())
    }
  }

  override fun onConnectFailed(deviceId: String) {}

  override fun onCharacteristicChanged(
    deviceManager: DeviceManager,
    characteristic: BluetoothGattCharacteristic,
    value: ByteArray
  ) {
    handler.post {
      eventSink?.success(
        CharacteristicValueChangedEvent(
          deviceId = deviceManager.deviceId,
          serviceUUID = characteristic.service.uuid.toString(),
          characteristicUUID = characteristic.uuid.toString(),
          value = value
        ).toMap()
      )
    }
  }
}
