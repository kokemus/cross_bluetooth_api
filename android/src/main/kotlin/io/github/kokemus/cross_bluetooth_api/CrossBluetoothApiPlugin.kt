package io.github.kokemus.cross_bluetooth_api

import android.app.Activity
import android.bluetooth.*
import android.bluetooth.BluetoothGatt.GATT_SUCCESS
import android.bluetooth.BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
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
  private var bluetoothGatts: MutableList<BluetoothGatt> = mutableListOf()

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cross_bluetooth_api")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
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
    return false
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
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
        }
      }
    }

    override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
      super.onServicesDiscovered(gatt, status)
      pendingResult?.success(true)
    }

    override fun onCharacteristicRead(
      gatt: BluetoothGatt?,
      characteristic: BluetoothGattCharacteristic?,
      status: Int
    ) {
      super.onCharacteristicRead(gatt, characteristic, status)
      if (status == GATT_SUCCESS) {
        pendingResult?.success(characteristic?.value)
      } else {
        pendingResult?.networkError()
      }
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
    }
  }

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
