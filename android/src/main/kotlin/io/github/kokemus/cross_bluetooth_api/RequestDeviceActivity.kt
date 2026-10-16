package io.github.kokemus.cross_bluetooth_api

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.bluetooth.le.ScanSettings.MATCH_MODE_STICKY
import android.bluetooth.le.ScanSettings.SCAN_MODE_LOW_LATENCY
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresPermission
import java.io.Serializable
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.github.kokemus.cross_bluetooth_api.models.RequestDeviceOptions
import java.lang.Exception

class RequestDeviceActivity: ComponentActivity() {
    companion object {
        const val RESULT_TYPE_ERROR = RESULT_FIRST_USER
        const val RESULT_NOT_FOUND_ERROR = RESULT_FIRST_USER + 1
        const val RESULT_SECURITY_ERROR = RESULT_FIRST_USER + 2
        const val RESULT_NOT_SUPPORTED_ERROR = RESULT_FIRST_USER + 3
        const val RESULT_INVALID_STATE_ERROR = RESULT_FIRST_USER + 4

    }
    private var scanner: BluetoothLeScanner? = null
    private val handler = Handler(Looper.getMainLooper())
    private val enableBluetooth = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
        object : ActivityResultCallback<ActivityResult> {
            @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
            override fun onActivityResult(result: ActivityResult) {
                if (result.resultCode == RESULT_OK) {
                    start()
                } else {
                    setResult(RESULT_INVALID_STATE_ERROR)
                    finish()
                }
            }
        }
    )
    private lateinit var options: RequestDeviceOptions
    private var nativeFilters: List<ScanFilter> = emptyList()
    private lateinit var devices: ArrayAdapter<BluetoothDevice>
    private lateinit var listView: ListView
    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            if (result != null) {
                val accepted = !options.requiresPostFiltering || options.matches(result)
                if (!accepted) return
                if (devices.getPosition(result.device) < 0) {
                    devices.add(result.device)
                    devices.notifyDataSetChanged()
                }
            }
        }
    }

    @RequiresPermission(allOf = [Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN])
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent.hasExtra("options")) {
            val serializedOptions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getSerializableExtra("options", Serializable::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getSerializableExtra("options")
            }
            @Suppress("UNCHECKED_CAST")
            options = RequestDeviceOptions.fromMap(
                serializedOptions as Map<String, Any>
            )
        } else {
            setResult(RESULT_TYPE_ERROR)
            finish()
            return
        }

        devices = object: ArrayAdapter<BluetoothDevice>(
            this,
            android.R.layout.simple_list_item_1,
            android.R.id.text1
        ) {
            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val view = super.getView(position, convertView, parent)
                getItem(position)?.let {
                    view.findViewById<TextView>(android.R.id.text1).apply {
                        text = it.name ?: "${getString(android.R.string.unknownName)} (${it.address})"
                    }
                }
                return view
            }
        }

        listView = ListView(this).apply {
            adapter = devices
            if (Build.VERSION.SDK_INT >= 35 && applicationInfo.targetSdkVersion >= 35) {
                setOnApplyWindowInsetsListener { view, insets ->
                    val systemBars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
                    view.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
                    insets
                }
            }
        }

        listView.setOnItemClickListener { _, _, i, _ ->
            val device = devices.getItem(i)
            setResult(
                RESULT_OK,
                Intent().putExtra(
                    "selected",
                    Device.fromBluetoothDevice(device!!).toMap() as Serializable
                )
            )
            finish()
        }

        setContentView(listView)

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
            override fun handleOnBackPressed() {
                stop()
                setResult(RESULT_CANCELED)
                finish()
            }
        })

        val bluetoothAdapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
        scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner != null) {
            if (bluetoothAdapter?.isEnabled == false) {
                enableBluetooth.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
                return
            } else {
                start()
                return
            }
        }
        setResult(RESULT_NOT_SUPPORTED_ERROR)
        finish()
        return
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    override fun onPause() {
        super.onPause()
        stop()
    }

    private var menu: Menu? = null

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        this.menu = menu
        val progressBar = ProgressBar(this).apply {
            scaleX = 0.5f
            scaleY = 0.5f
        }
        menu!!.add("Re-scan").apply {
            setShowAsActionFlags(MenuItem.SHOW_AS_ACTION_ALWAYS)
            actionView = progressBar
        }
        return true
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    private fun start() {
        devices.clear()
        val progressBar = ProgressBar(this).apply {
            scaleX = 0.5f
            scaleY = 0.5f
        }
        if (menu != null) {
            menu!!.clear()
            menu!!.add("Re-scan").apply {
                setShowAsActionFlags(MenuItem.SHOW_AS_ACTION_ALWAYS)
                actionView = progressBar
            }
        }

        val settings = ScanSettings.Builder()
            .setScanMode(SCAN_MODE_LOW_LATENCY)
            .setMatchMode(MATCH_MODE_STICKY)
            .build()
        handler.postDelayed({
            stop()
        }, 60 * 1000)
        try {
            nativeFilters = options.nativeScanFilters()
            val scanFilters = options.scannerFilters(nativeFilters)
            scanner?.startScan(scanFilters, settings, callback)
        } catch (_: Exception) {
            setResult(RESULT_FIRST_USER)
            finish()
        }
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    private fun stop() {
        handler.removeCallbacksAndMessages(null)
        if (menu != null) {
            menu!!.clear()
            menu!!.add("Re-scan").apply {
                setShowAsActionFlags(MenuItem.SHOW_AS_ACTION_ALWAYS)
                setOnMenuItemClickListener {
                    start()
                    true
                }
            }
        }
        scanner?.stopScan(callback)
    }
}