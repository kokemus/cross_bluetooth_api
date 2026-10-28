package io.github.kokemus.cross_bluetooth_api.views

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.widget.ListView
import android.widget.PopupMenu
import android.widget.ProgressBar
import android.widget.Toolbar
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.io.Serializable
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [32, 35])
class RequestDeviceActivityTest {
    @Test
    fun missingOptions_finishesBeforeContentIsConfigured() {
        val controller = Robolectric.buildActivity(RequestDeviceActivity::class.java).create()
        try {
            val activity = controller.get()
            assertTrue(activity.isFinishing)
            assertEquals(RequestDeviceActivity.RESULT_TYPE_ERROR, shadowOf(activity).resultCode)
        } finally {
            controller.destroy()
        }
    }

    private fun withChooser(test: (RequestDeviceActivity, BluetoothAdapter) -> Unit) {
        val intent = Intent().putExtra("options", hashMapOf("acceptAllDevices" to true) as Serializable)
        val controller: ActivityController<RequestDeviceActivity> =
            Robolectric.buildActivity(RequestDeviceActivity::class.java, intent)
        val activity = controller.get()
        val adapter = activity.getSystemService(BluetoothManager::class.java).adapter
        shadowOf(adapter).setState(BluetoothAdapter.STATE_ON)
        controller.setup()
        try {
            test(activity, adapter)
        } finally {
            controller.pause().stop().destroy()
        }
    }

    @Test
    fun chooser_preservesNativeActionBarAndPlainListInsideSheet() = withChooser { activity, _ ->
        val floating = TypedValue()
        activity.theme.resolveAttribute(android.R.attr.windowIsFloating, floating, true)
        assertNotEquals(0, floating.data)
        assertEquals(Gravity.BOTTOM, activity.window.attributes.gravity)
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, activity.window.attributes.width)
        assertTrue(activity.window.attributes.height > 0)
        val dimAmount = TypedValue()
        assertTrue(activity.theme.resolveAttribute(android.R.attr.backgroundDimAmount, dimAmount, true))
        assertEquals(dimAmount.float, activity.window.attributes.dimAmount, 0.001f)
        assertTrue(activity.window.decorView.background is GradientDrawable)
        assertTrue(activity.window.decorView.clipToOutline)
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        assertEquals(1, content.childCount)
        val layout = content.getChildAt(0) as ViewGroup
        assertEquals(2, layout.childCount)
        assertTrue(layout.getChildAt(0) is Toolbar)
        assertTrue(layout.getChildAt(1) is ListView)
        assertNotNull(activity.actionBar)
        assertEquals("Scanning", activity.actionBar!!.title)
        val menu = PopupMenu(activity, content).menu
        activity.onCreateOptionsMenu(menu)
        assertEquals(1, menu.size())
        assertEquals("Re-scan", menu.getItem(0).title)
        assertTrue(menu.getItem(0).actionView is ProgressBar)
    }

    @Test
    fun swipeDown_cancelsAndStopsScanningImmediately() = withChooser { activity, adapter ->
        val scanner = shadowOf(adapter.bluetoothLeScanner)
        assertFalse(scanner.scanCallbacks.isEmpty())
        activity.window.decorView.apply {
            layout(0, 0, 600, 1000)
            animate().cancel()
            translationY = 0f
        }
        for ((action, positionY, elapsed) in listOf(
            Triple(MotionEvent.ACTION_DOWN, 20f, 0L),
            Triple(MotionEvent.ACTION_MOVE, 420f, 500L),
            Triple(MotionEvent.ACTION_UP, 420f, 1000L)
        )) {
            val event = MotionEvent.obtain(0, elapsed, action, 100f, positionY, 0)
            try {
                activity.dispatchTouchEvent(event)
            } finally {
                event.recycle()
            }
        }
        assertTrue(scanner.scanCallbacks.isEmpty())
        val content = activity.findViewById<ViewGroup>(android.R.id.content).getChildAt(0) as ViewGroup
        assertFalse((content.getChildAt(1) as ListView).isEnabled)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(Activity.RESULT_CANCELED, shadowOf(activity).resultCode)
        assertTrue(activity.isFinishing)
    }

    @Test
    fun back_cancelsAndStopsScanningImmediately() = withChooser { activity, adapter ->
        val scanner = shadowOf(adapter.bluetoothLeScanner)
        assertFalse(scanner.scanCallbacks.isEmpty())
        activity.setResult(Activity.RESULT_OK)
        activity.onBackPressedDispatcher.onBackPressed()
        assertTrue(scanner.scanCallbacks.isEmpty())
        val content = activity.findViewById<ViewGroup>(android.R.id.content).getChildAt(0) as ViewGroup
        assertFalse((content.getChildAt(1) as ListView).isEnabled)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(Activity.RESULT_CANCELED, shadowOf(activity).resultCode)
        assertTrue(activity.isFinishing)
    }

    @Test
    fun scanTimeout_showsRescanAndRestartsScanning() = withChooser { activity, adapter ->
        val menu = PopupMenu(activity, activity.window.decorView).menu
        activity.onCreateOptionsMenu(menu)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(61))
        val scanner = shadowOf(adapter.bluetoothLeScanner)
        assertTrue(scanner.scanCallbacks.isEmpty())
        val rescan = menu.getItem(0)
        assertEquals("Re-scan", rescan.title)
        assertNull(rescan.actionView)
        menu.performIdentifierAction(rescan.itemId, 0)
        assertFalse(scanner.scanCallbacks.isEmpty())
        assertTrue(menu.getItem(0).actionView is ProgressBar)
    }
}



