package io.github.kokemus.cross_bluetooth_api

import android.app.Activity
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.github.kokemus.cross_bluetooth_api.models.RequestDeviceOptions
import java.io.Serializable

/** CrossBluetoothApiPlugin */
class CrossBluetoothApiPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, ActivityResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var activityPluginBinding: ActivityPluginBinding? = null
  private var pendingResult: Result? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cross_bluetooth_api")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "requestDevice" -> requestDevice(call.arguments as java.util.HashMap<String, Object>, result)
      "connect" -> connect(call.arguments as java.util.HashMap<String, Object>, result)
      "disconnect" -> disconnect(call.arguments as java.util.HashMap<String, Object>, result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
    activity = activityPluginBinding.getActivity()
    activityPluginBinding?.addActivityResultListener(this)
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
      Activity.RESULT_CANCELED -> {
        pendingResult?.error("NotFoundError", "NotFoundError: User cancelled the requestDevice() chooser.", null)
      }
      RequestDeviceActivity.RESULT_TYPE_ERROR -> {
        pendingResult?.error("TypeError", "TypeError: The provided options do not make sense.", null)
      }
      RequestDeviceActivity.RESULT_NOT_FOUND_ERROR -> {
        pendingResult?.error("NotFoundError", "NotFoundError: There is no Bluetooth device that matches the specified options.", null)
      }
      RequestDeviceActivity.RESULT_SECURITY_ERROR -> {
        pendingResult?.error("SecurityError", "SecurityError: There is no Bluetooth device that matches the specified options.", null)
      }
      RequestDeviceActivity.RESULT_NOT_SUPPORTED_ERROR -> {
        pendingResult?.error("NotSupportedError", "NotSupportedError: The operation is not supported.", null)
      }
      RequestDeviceActivity.RESULT_INVALID_STATE_ERROR -> {
        pendingResult?.error("InvalidStateError", "InvalidStateError: Bluetooth is turned off.", null)
      }
    }
    return false
  }

  private fun requestDevice(arguments: Map<String, Any>, result: Result) {
    Log.d("requestDevice", RequestDeviceOptions.fromMap(arguments).toString())
    //TODO request bluetooth and permissions
    pendingResult = result
    activity?.startActivityForResult(
      Intent(activity, RequestDeviceActivity::class.java)
        .putExtra("options", arguments as Serializable),
      0
    )
  }

  private var bluetoothGatt: BluetoothGatt? = null

  private val callback = object: BluetoothGattCallback() {
    override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
      super.onConnectionStateChange(gatt, status, newState)
      Log.d("onConnectionStateChange", "$status $newState")
      when (newState) {
        BluetoothProfile.STATE_CONNECTED -> pendingResult?.success(true)
        BluetoothProfile.STATE_DISCONNECTED -> {
          bluetoothGatt = null
          pendingResult?.success(true)
        }
      }
    }
  }

  private fun connect(arguments: Map<String, Any>, result: Result) {
    Log.d("connect", arguments.toString())
    pendingResult = result
    val device = Device.fromMap(arguments)
    val adapter = (activity?.getSystemService(Activity.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    val bluetoothDevice = adapter.getRemoteDevice(device.id)
    bluetoothGatt = bluetoothDevice.connectGatt(activity, false, callback)
  }

  private fun disconnect(arguments: Map<String, Any>, result: Result) {
    Log.d("disconnect", arguments.toString())
    pendingResult = result
    bluetoothGatt?.disconnect()
  }
}
