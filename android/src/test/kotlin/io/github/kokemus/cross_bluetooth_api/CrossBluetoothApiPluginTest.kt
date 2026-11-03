package io.github.kokemus.cross_bluetooth_api

import android.content.Context
import android.content.pm.FeatureInfo
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [26, 35])
class CrossBluetoothApiPluginTest {
    private lateinit var context: Context
    private lateinit var plugin: CrossBluetoothApiPlugin

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        plugin = CrossBluetoothApiPlugin()
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP, true)
    }

    @Suppress("DEPRECATION")
    private fun declareFeature(name: String?, required: Boolean = false) {
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        packageInfo.reqFeatures = name?.let {
            arrayOf(FeatureInfo().apply {
                this.name = it
                flags = if (required) FeatureInfo.FLAG_REQUIRED else 0
            })
        }
        shadowOf(context.packageManager).installPackage(packageInfo)
    }

    @Test
    fun companionSetupIsDisabledWithoutManifestDeclaration() {
        declareFeature(null)
        assertFalse(plugin.isCompanionSetupEnabled(context))
    }

    @Test
    fun unrelatedManifestFeatureDoesNotEnableCompanionSetup() {
        declareFeature(PackageManager.FEATURE_BLUETOOTH_LE)
        assertFalse(plugin.isCompanionSetupEnabled(context))
    }

    @Test
    fun optionalManifestFeatureEnablesCompanionSetup() {
        declareFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP)
        assertTrue(plugin.isCompanionSetupEnabled(context))
    }

    @Test
    fun requiredManifestFeatureEnablesCompanionSetup() {
        declareFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP, required = true)
        assertTrue(plugin.isCompanionSetupEnabled(context))
    }

    @Test
    fun manifestDeclarationDoesNotEnableUnsupportedDevice() {
        declareFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP)
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_COMPANION_DEVICE_SETUP, false)
        assertFalse(plugin.isCompanionSetupEnabled(context))
    }
}
