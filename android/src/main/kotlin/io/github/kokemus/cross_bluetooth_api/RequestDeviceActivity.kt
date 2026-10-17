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
import android.util.TypedValue
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toolbar
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresPermission
import java.io.Serializable
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.github.kokemus.cross_bluetooth_api.models.RequestDeviceOptions
import java.lang.Exception
import androidx.core.view.size
import androidx.core.view.get

class RequestDeviceActivity: SheetActivity() {
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
            @RequiresPermission(allOf = [Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN])
            override fun onActivityResult(result: ActivityResult) {
                if (result.resultCode == RESULT_OK) {
                    scanner = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter?.bluetoothLeScanner
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
    private var menu: Menu? = null
    private var scanning = false
    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            if (result != null && scanning && !isDismissing) {
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
        title = "Scanning"
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
        }

        listView.setOnItemClickListener { _, _, i, _ ->
            if (isDismissing) return@setOnItemClickListener
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

        val toolbar = createToolbar()
        val actionBarSize = TypedValue().also {
            theme.resolveAttribute(android.R.attr.actionBarSize, it, true)
        }.getDimension(resources.displayMetrics).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(toolbar, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, actionBarSize))
            addView(listView, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        }
        setContentView(content)
        setActionBar(toolbar)
        configureSheet(savedInstanceState)

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
            override fun handleOnBackPressed() {
                stop()
                setResult(RESULT_CANCELED)
                finish()
            }
        })

        val bluetoothAdapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
        if (bluetoothAdapter != null) {
            if (!bluetoothAdapter.isEnabled) {
                enableBluetooth.launch(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE))
                return
            } else {
                scanner = bluetoothAdapter.bluetoothLeScanner
                if (scanner != null) {
                    start()
                    return
                }
            }
        }
        setResult(RESULT_NOT_SUPPORTED_ERROR)
        finish()
        return
    }

    private fun createToolbar(): Toolbar {
        val toolbar = Toolbar(this)
        val actionBarAttributes = theme.obtainStyledAttributes(
            null,
            intArrayOf(android.R.attr.background),
            android.R.attr.actionBarStyle,
            0
        )
        try {
            toolbar.background = actionBarAttributes.getDrawable(0)
        } finally {
            actionBarAttributes.recycle()
        }
        val titleAttributes = theme.obtainStyledAttributes(intArrayOf(android.R.attr.textColorPrimary))
        try {
            titleAttributes.getColorStateList(0)?.let {
                toolbar.setTitleTextColor(it.defaultColor)
            }
        } finally {
            titleAttributes.recycle()
        }
        return toolbar
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    override fun onPause() {
        super.onPause()
        stop()
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        this.menu = menu
        updateScanStatus()
        return true
    }

    override fun onDismissStarted() {
        try {
            stop()
        } catch (_: SecurityException) {
            // Permission may have been revoked while the chooser was visible.
        }
        if (::listView.isInitialized) listView.isEnabled = false
        menu?.let {
            for (index in 0 until it.size) it[index].isEnabled = false
        }
    }

    private fun updateScanStatus() {
        val currentMenu = menu ?: return
        currentMenu.clear()
        currentMenu.add("Re-scan").apply {
            setShowAsActionFlags(MenuItem.SHOW_AS_ACTION_ALWAYS)
            isEnabled = !isDismissing
            if (scanning) {
                actionView = ProgressBar(this@RequestDeviceActivity).apply {
                    scaleX = 0.5f
                    scaleY = 0.5f
                }
            } else {
                setOnMenuItemClickListener(object : MenuItem.OnMenuItemClickListener {
                    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
                    override fun onMenuItemClick(item: MenuItem): Boolean {
                        start()
                        return true
                    }
                })
            }
        }
    }

    @RequiresPermission(Manifest.permission.BLUETOOTH_SCAN)
    private fun start() {
        if (isDismissing) return
        stop()
        devices.clear()
        if (scanner == null) {
            setResult(RESULT_NOT_SUPPORTED_ERROR)
            finish()
            return
        }
        scanning = true
        updateScanStatus()

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
        val wasScanning = scanning
        scanning = false
        updateScanStatus()
        if (wasScanning) {
            try {
                scanner?.stopScan(callback)
            } catch (_: SecurityException) {
                // Cleanup must remain safe after permission revocation.
            }
        }
    }
}