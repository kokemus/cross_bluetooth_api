package io.github.kokemus.cross_bluetooth_api.testing.fakes

import io.github.kokemus.cross_bluetooth_api.services.BluetoothManager
import io.github.kokemus.cross_bluetooth_api.services.BluetoothManagerListener
import io.github.kokemus.cross_bluetooth_api.services.DeviceManager

class FakeBluetoothManager(
    private val connectReturnValue: Boolean = true,
    var disconnectReturnValue: Boolean = true
) : BluetoothManager {
    private val listeners = linkedSetOf<BluetoothManagerListener>()
    val devices = linkedMapOf<String, DeviceManager>()
    val disconnectedIds = mutableListOf<String>()

    override fun addListener(delegate: BluetoothManagerListener) {
        listeners.add(delegate)
    }

    override fun removeListener(delegate: BluetoothManagerListener) {
        listeners.remove(delegate)
    }

    override fun removeAllListeners() {
        listeners.clear()
    }

    override fun deviceManager(deviceId: String): DeviceManager? = devices[deviceId]

    override fun retrieveDeviceManager(deviceId: String): DeviceManager? = devices[deviceId]

    override fun connect(deviceId: String): Boolean = connectReturnValue

    override fun disconnect(deviceId: String): Boolean {
        disconnectedIds.add(deviceId)
        return disconnectReturnValue
    }

    @Suppress("unused") // Used by DisconnectCommandTest.
    fun emitDisconnected(deviceId: String) {
        listeners.toList().forEach { it.onDisconnected(deviceId) }
    }

    fun emitConnected(deviceManager: DeviceManager) {
        listeners.toList().forEach { it.onConnected(deviceManager) }
    }

    fun emitConnectFailed(deviceId: String) {
        listeners.toList().forEach { it.onConnectFailed(deviceId) }
    }

    fun hasListener(listener: BluetoothManagerListener): Boolean {
        return listeners.contains(listener)
    }
}
