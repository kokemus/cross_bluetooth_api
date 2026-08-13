package io.github.kokemus.cross_bluetooth_api

import android.Manifest
import android.app.Activity
import android.bluetooth.*
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
import android.content.Intent
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
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.github.kokemus.cross_bluetooth_api.extensions.*
import io.github.kokemus.cross_bluetooth_api.models.Device
import java.io.Serializable
import java.util.*

class CrossBluetoothApiPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, ActivityResultListener {
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var activityPluginBinding: ActivityPluginBinding? = null
  private var pendingResult: Result? = null
  private var pendingNotificationResult: Result? = null
  private var bluetoothGatts: MutableList<BluetoothGatt> = mutableListOf()

  companion object {
    private val clientCharacteristicConfigUuid = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cross_bluetooth_api")
    channel.setMethodCallHandler(this)

    val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "cross_bluetooth_api/events")
    eventChannel.setStreamHandler(streamHandler)
  }

  private var eventSink: EventChannel.EventSink? = null
  private val handler = Handler(Looper.getMainLooper())

  private val streamHandler = object: EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
      eventSink = events
    }

    override fun onCancel(arguments: Any?) {
      eventSink = null
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
    activity = activityPluginBinding.activity
    activityPluginBinding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    pendingResult = null
    activity = null
    activityPluginBinding?.removeActivityResultListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(activityPluginBinding: ActivityPluginBinding) {}

  override fun onDetachedFromActivityForConfigChanges() {}

  override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?): Boolean {
    when (resultCode) {
      Activity.RESULT_OK -> {
        val selected = intent!!.getSerializableExtra("selected")
        pendingResult?.success(selected)
      }
      Activity.RESULT_CANCELED -> pendingResult?.userCancelledError()
      RequestDeviceActivity.RESULT_TYPE_ERROR -> pendingResult?.typeError()
      RequestDeviceActivity.RESULT_NOT_FOUND_ERROR -> pendingResult?.notFoundError()
      RequestDeviceActivity.RESULT_SECURITY_ERROR -> pendingResult?.securityError()
      RequestDeviceActivity.RESULT_NOT_SUPPORTED_ERROR -> pendingResult?.notSupportedError()
      RequestDeviceActivity.RESULT_INVALID_STATE_ERROR -> pendingResult?.invalidStateError()
    }
    pendingResult = null
    return false
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  override fun onMethodCall(call: MethodCall, result: Result) {
    @Suppress("UNCHECKED_CAST")
    val arguments = call.arguments as HashMap<String, Any>
    when (call.method) {
      "requestDevice" -> requestDevice(arguments, result)
      "connect" -> connect(arguments, result)
      "disconnect" -> disconnect(arguments, result)
      "getPrimaryService" -> getPrimaryService(arguments, result)
      "getCharacteristic" -> getCharacteristic(arguments, result)
      "readValue" -> readValue(arguments, result)
      "writeValueWithoutResponse" -> writeValueWithoutResponse(arguments, result)
      "startNotifications" -> startNotifications(arguments, result)
      "stopNotifications" -> stopNotifications(arguments, result)
      else -> result.notImplemented()
    }
  }

  private fun requestDevice(arguments: Map<String, Any>, result: Result) {
    pendingResult = result
    activity?.startActivityForResult(
      Intent(activity, RequestDeviceActivity::class.java)
        .putExtra("options", arguments as Serializable),
      0
    )
  }

  private val callback = object: BluetoothGattCallback() {
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
      super.onConnectionStateChange(gatt, status, newState)
      when (newState) {
        BluetoothProfile.STATE_CONNECTED -> {
          bluetoothGatts.add(gatt!!)
          gatt.discoverServices()
        }
        BluetoothProfile.STATE_DISCONNECTED -> {
          gatt?.close()
          bluetoothGatts.remove(gatt)
          pendingResult?.success(true)
          pendingResult = null
          handler.post {
            eventSink?.success(mapOf("name" to "gattserverdisconnected"))
          }
        }
      }
    }

    override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
      super.onServicesDiscovered(gatt, status)
      pendingResult?.success(true)
      pendingResult = null
    }

    override fun onCharacteristicRead(
      gatt: BluetoothGatt,
      characteristic: BluetoothGattCharacteristic,
      value: ByteArray,
      status: Int
    ) {
      super.onCharacteristicRead(gatt, characteristic, value, status)
      if (status == GATT_SUCCESS) {
        pendingResult?.success(value)
      } else {
        pendingResult?.networkError()
      }
      pendingResult = null
    }

    override fun onCharacteristicWrite(
      gatt: BluetoothGatt?,
      characteristic: BluetoothGattCharacteristic?,
      status: Int
    ) {
      super.onCharacteristicWrite(gatt, characteristic, status)
      if (status == GATT_SUCCESS) {
        pendingResult?.success(characteristic?.value)
      } else {
        pendingResult?.networkError()
      }
      pendingResult = null
    }

    override fun onDescriptorWrite(
      gatt: BluetoothGatt?,
      descriptor: BluetoothGattDescriptor?,
      status: Int
    ) {
      super.onDescriptorWrite(gatt, descriptor, status)
      if (descriptor?.uuid != clientCharacteristicConfigUuid) {
        return
      }

      if (status == GATT_SUCCESS) {
        pendingNotificationResult?.success(true)
      } else {
        pendingNotificationResult?.networkError()
      }
      pendingNotificationResult = null
    }

    override fun onCharacteristicChanged(
      gatt: BluetoothGatt,
      characteristic: BluetoothGattCharacteristic,
      value: ByteArray
    ) {
      super.onCharacteristicChanged(gatt, characteristic, value)
      handler.post {
        eventSink?.success(
          mapOf(
            "name" to "characteristicvaluechanged",
            "deviceId" to gatt.device.address,
            "serviceUUID" to characteristic.service.uuid.toString(),
            "characteristicUUID" to characteristic.uuid.toString(),
            "value" to characteristic.value
          )
        )
      }
    }
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  private fun connect(arguments: Map<String, Any>, result: Result) {
    pendingResult = result
    val device = Device.fromMap(arguments)
    val adapter = (activity?.getSystemService(Activity.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    val bluetoothDevice = adapter.getRemoteDevice(device.id)
    val gatt = bluetoothDevice.connectGatt(activity, false, callback)
    if (gatt == null) {
      pendingResult = null
      result.networkError()
    }
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  private fun disconnect(arguments: Map<String, Any>, result: Result) {
    pendingResult = result
    val gatt = getGatt(arguments["id"] as String)
    gatt?.disconnect()
  }

  private fun getPrimaryService(arguments: Map<String, Any>, result: Result) {
    val deviceId = arguments["deviceId"] as String
    val serviceUUID = arguments["serviceUUID"] as String

    val service = getPrimaryService(deviceId, serviceUUID)
    if (service != null) {
      result.success(service.toMap())
    } else {
      result.notFoundError()
    }
  }

  private fun getCharacteristic(arguments: Map<String, Any>, result: Result) {
    val deviceId = arguments["deviceId"] as String
    val serviceUUID = arguments["serviceUUID"] as String
    val characteristicUUID = arguments["characteristic"] as String

    val characteristic = getCharacteristic(deviceId, serviceUUID, characteristicUUID)
    if (characteristic != null) {
      result.success(characteristic.toMap())
    } else {
      result.notFoundError()
    }
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  private fun readValue(arguments: Map<String, Any>, result: Result) {
    pendingResult = result
    val deviceId = arguments["deviceId"] as String
    val serviceUUID = arguments["serviceUUID"] as String
    val characteristicUUID = arguments["characteristic"] as String

    val gatt = getGatt(deviceId)
    val characteristic = getCharacteristic(deviceId, serviceUUID, characteristicUUID)
    if (gatt?.readCharacteristic(characteristic) == false) {
      pendingResult = null
      result.networkError()
    }
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  private fun writeValueWithoutResponse(arguments: Map<String, Any>, result: Result) {
    pendingResult = result
    val deviceId = arguments["deviceId"] as String
    val serviceUUID = arguments["serviceUUID"] as String
    val characteristicUUID = arguments["characteristic"] as String
    val value = arguments["value"] as ByteArray

    val gatt = getGatt(deviceId)
    val characteristic = getCharacteristic(deviceId, serviceUUID, characteristicUUID)
    characteristic?.value = value
    characteristic?.writeType = WRITE_TYPE_NO_RESPONSE
    if (gatt?.writeCharacteristic(characteristic) == false) {
      pendingResult = null
      result.networkError()
    }
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  private fun startNotifications(arguments: Map<String, Any>, result: Result) {
    val deviceId = arguments["deviceId"] as String
    val serviceUUID = arguments["serviceUUID"] as String
    val characteristicUUID = arguments["characteristic"] as String

    val gatt = getGatt(deviceId)
    val characteristic = getCharacteristic(deviceId, serviceUUID, characteristicUUID)
    if (gatt == null || characteristic == null) {
      result.notFoundError()
      return
    }

    val supportsNotify = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
    val supportsIndicate = characteristic.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0
    if (!supportsNotify && !supportsIndicate) {
      result.notSupportedError()
      return
    }

    val cccd = characteristic.getDescriptor(clientCharacteristicConfigUuid)
    if (cccd == null) {
      result.notSupportedError()
      return
    }

    val enableValue = if (supportsNotify) {
      BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
    } else {
      BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
    }

    if (gatt.setCharacteristicNotification(characteristic, true)) {
      pendingNotificationResult = result
      cccd.value = enableValue
      if (!gatt.writeDescriptor(cccd)) {
        pendingNotificationResult = null
        result.networkError()
      }
    } else {
      result.networkError()
    }
  }

  @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
  private fun stopNotifications(arguments: Map<String, Any>, result: Result) {
    val deviceId = arguments["deviceId"] as String
    val serviceUUID = arguments["serviceUUID"] as String
    val characteristicUUID = arguments["characteristic"] as String

    val gatt = getGatt(deviceId)
    val characteristic = getCharacteristic(deviceId, serviceUUID, characteristicUUID)
    if (gatt == null || characteristic == null) {
      result.notFoundError()
      return
    }

    val cccd = characteristic.getDescriptor(clientCharacteristicConfigUuid)
    if (cccd == null) {
      result.notSupportedError()
      return
    }

    if (gatt.setCharacteristicNotification(characteristic, false)) {
      pendingNotificationResult = result
      cccd.value = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
      if (!gatt.writeDescriptor(cccd)) {
        pendingNotificationResult = null
        result.networkError()
      }
    } else {
      result.networkError()
    }
  }

  private fun getGatt(deviceId: String): BluetoothGatt? {
    return bluetoothGatts.find { it.device.address == deviceId }
  }

  private fun getPrimaryService(deviceId: String, serviceUUID: String): BluetoothGattService? {
    val gatt = getGatt(deviceId)
    return gatt?.getService(UUID.fromString(serviceUUID))
  }

  private fun getCharacteristic(deviceId: String, serviceUUID: String, characteristic: String):  BluetoothGattCharacteristic? {
    val service = getPrimaryService(deviceId, serviceUUID)
    return service?.getCharacteristic(UUID.fromString(characteristic))
  }
}
