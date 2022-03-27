package io.github.kokemus.cross_bluetooth_api

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.bluetooth.le.ScanSettings.MATCH_MODE_STICKY
import android.bluetooth.le.ScanSettings.SCAN_MODE_LOW_LATENCY
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.TextView
import java.io.Serializable
import io.github.kokemus.cross_bluetooth_api.models.Device
import io.github.kokemus.cross_bluetooth_api.models.RequestDeviceOptions
import java.lang.Exception
import java.util.*

class RequestDeviceActivity: Activity() {
    companion object {
        const val RESULT_TYPE_ERROR = RESULT_FIRST_USER
        const val RESULT_NOT_FOUND_ERROR = RESULT_FIRST_USER + 1
        const val RESULT_SECURITY_ERROR = RESULT_FIRST_USER + 2
        const val RESULT_NOT_SUPPORTED_ERROR = RESULT_FIRST_USER + 3
        const val RESULT_INVALID_STATE_ERROR = RESULT_FIRST_USER + 4

        private const val REQUEST_ENABLE_BT = 0
    }
    private var scanner: BluetoothLeScanner? = null
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var options: RequestDeviceOptions
    private lateinit var devices: ArrayAdapter<BluetoothDevice>
    private lateinit var listView: ListView
    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            if (result != null) {
                if (devices.getPosition(result.device) < 0) {
                    devices.add(result.device)
                    devices.notifyDataSetChanged()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent.hasExtra("options")) {
            options = RequestDeviceOptions.fromMap(
                intent.getSerializableExtra("options") as Map<String, Any>
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
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val view = super.getView(position, convertView, parent)
                getItem(position)?.let {
                    view.findViewById<TextView>(android.R.id.text1).apply {
                        text = if (it.name != null) {
                            it.name
                        } else {
                            "${getString(android.R.string.unknownName)} (${it.address})"
                        }

                    }
                }
                return view
            }
        }

        listView = ListView(this).apply {
            adapter = devices
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

        val bluetoothAdapter = (getSystemService(BLUETOOTH_SERVICE) as BluetoothManager).adapter
        scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner != null) {
            if (bluetoothAdapter?.isEnabled == false) {
                startActivityForResult(
                    Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),
                    REQUEST_ENABLE_BT
                )
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_BT) {
            if (resultCode == RESULT_OK) {
                start()
            } else {
                setResult(RESULT_INVALID_STATE_ERROR)
                finish()
            }
        }
    }

    override fun onPause() {
        super.onPause()
        stop()
    }

    override fun onBackPressed() {
        stop()
        setResult(RESULT_CANCELED)
        finish()
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

        val filters = mutableListOf<ScanFilter>()
        if (options.filters != null) {
            for (filter in options.filters!!) {
                if (filter.services != null) {
                    for (service in filter.services) {
                        filters.add(ScanFilter.Builder()
                            .setServiceUuid(ParcelUuid(UUID.fromString(service)))
                            .build()
                        )
                    }
                }
                if (filter.name != null) {
                    filters.add(ScanFilter.Builder().setDeviceName(filter.name).build())
                }
                if (filter.namePrefix != null) {
                    // post filtering
                    filters.add(ScanFilter.Builder().setDeviceName(filter.namePrefix).build())
                }
            }
        }
        if (options.optionalServices != null) {
            for (service in options.optionalServices!!) {
                // post filtering
            }
        }
        if (options.acceptAllDevices) {
            // nop
        }
        val settings = ScanSettings.Builder()
            .setScanMode(SCAN_MODE_LOW_LATENCY)
            .setMatchMode(MATCH_MODE_STICKY)
            .build()
        handler.postDelayed({
            stop()
        }, 60 * 1000)
        try {
            scanner?.startScan(filters, settings, callback)
        } catch (e: Exception) {
            setResult(RESULT_FIRST_USER)
            finish()
        }
    }

    private fun stop() {
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