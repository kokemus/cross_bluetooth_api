package io.github.kokemus.cross_bluetooth_api.views

import android.app.Activity
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.TextView
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [29, 32, 35])
class SheetActivityTest {
    class TestSheetActivity : SheetActivity() {
        var dismissCount = 0
        var dismissStateObserved = false
        var clickCount = 0
        val touchActions = mutableListOf<Int>()

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            if (!intent.getBooleanExtra("skipContent", false)) {
                setContentView(object : TextView(this) {
                    override fun canScrollVertically(direction: Int): Boolean =
                        direction == -1 && intent.getBooleanExtra("scrolled", false)
                }.apply {
                    setOnClickListener { clickCount++ }
                    setOnTouchListener { _, event ->
                        touchActions.add(event.actionMasked)
                        false
                    }
                })
                configureSheet(savedInstanceState)
            }
        }

        override fun onDismissStarted() {
            dismissCount++
            dismissStateObserved = isDismissing
        }
    }

    @Test
    @Config(qualifiers = "notnight")
    fun configuration_preservesSheetAppearanceWithoutChooserContent() {
        val controller = Robolectric.buildActivity(TestSheetActivity::class.java).setup()
        try {
            val activity = controller.get()
            assertEquals(Gravity.BOTTOM, activity.window.attributes.gravity)
            assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, activity.window.attributes.width)
            assertTrue(activity.window.attributes.height > 0)
            assertThemeDimAmount(activity)
            val background = activity.window.decorView.background as GradientDrawable
            val color = TypedValue()
            activity.theme.resolveAttribute(android.R.attr.colorBackgroundFloating, color, true)
            assertEquals(color.data, background.color!!.defaultColor)
            assertTrue(activity.window.decorView.clipToOutline)
        } finally {
            controller.pause().stop().destroy()
        }
    }

    @Test
    @Config(qualifiers = "night")
    fun darkMode_usesThemeDimAmount() {
        val controller = Robolectric.buildActivity(TestSheetActivity::class.java).setup()
        try {
            assertThemeDimAmount(controller.get())
        } finally {
            controller.pause().stop().destroy()
        }
    }

    private fun assertThemeDimAmount(activity: Activity) {
        val dimAmount = TypedValue()
        assertTrue(activity.theme.resolveAttribute(android.R.attr.backgroundDimAmount, dimAmount, true))
        assertEquals(dimAmount.float, activity.window.attributes.dimAmount, 0.001f)
        assertTrue(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_DIM_BEHIND != 0)
    }

    private fun withLaidOutSheet(scrolled: Boolean = false, test: (TestSheetActivity) -> Unit) {
        val intent = Intent().putExtra("scrolled", scrolled)
        val controller: ActivityController<TestSheetActivity> =
            Robolectric.buildActivity(TestSheetActivity::class.java, intent).setup().visible()
        try {
            val activity = controller.get()
            activity.window.decorView.apply {
                layout(0, 0, 600, 1000)
                animate().cancel()
                translationY = 0f
            }
            test(activity)
        } finally {
            controller.pause().stop().destroy()
        }
    }

    private fun touch(activity: Activity, action: Int, x: Float, y: Float, elapsed: Long) {
        val event = MotionEvent.obtain(0, elapsed, action, x, y, 0)
        try {
            activity.dispatchTouchEvent(event)
        } finally {
            event.recycle()
        }
    }

    @Test
    fun downwardDrag_dismissesOnceAndCancelsChildTap() = withLaidOutSheet { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 500f, 500)
        assertTrue(activity.window.decorView.translationY > 0f)
        assertTrue(activity.touchActions.contains(MotionEvent.ACTION_CANCEL))
        touch(activity, MotionEvent.ACTION_UP, 100f, 500f, 1000)
        assertEquals(1, activity.dismissCount)
        assertTrue(activity.dismissStateObserved)
        assertEquals(0, activity.clickCount)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertTrue(activity.isFinishing)
        assertEquals(Activity.RESULT_CANCELED, shadowOf(activity).resultCode)
    }

    @Test
    fun quickDownwardFlick_dismissesBelowDistanceThreshold() = withLaidOutSheet { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 180f, 10)
        touch(activity, MotionEvent.ACTION_UP, 100f, 220f, 20)
        assertEquals(1, activity.dismissCount)
    }

    @Test
    fun secondPointer_cancelsDragAndConsumesRemainingGesture() = withLaidOutSheet { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 500f, 500)
        touch(activity, MotionEvent.ACTION_POINTER_DOWN, 100f, 500f, 600)
        val childEventCount = activity.touchActions.size
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 600f, 700)
        touch(activity, MotionEvent.ACTION_UP, 100f, 600f, 1000)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(0, activity.dismissCount)
        assertEquals(0, activity.clickCount)
        assertEquals(childEventCount, activity.touchActions.size)
        assertEquals(0f, activity.window.decorView.translationY, 0.001f)
    }

    @Test
    fun shortDrag_returnsToRest() = withLaidOutSheet { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 180f, 500)
        touch(activity, MotionEvent.ACTION_UP, 100f, 180f, 1000)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(0, activity.dismissCount)
        assertEquals(0f, activity.window.decorView.translationY, 0.001f)
    }

    @Test
    fun cancelledDrag_returnsToRestEvenPastDismissThreshold() = withLaidOutSheet { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 500f, 500)
        touch(activity, MotionEvent.ACTION_CANCEL, 100f, 500f, 1000)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(0, activity.dismissCount)
        assertEquals(0f, activity.window.decorView.translationY, 0.001f)
    }

    @Test
    fun scrolledChild_keepsDownwardGesture() = withLaidOutSheet(scrolled = true) { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 100f, 500f, 500)
        touch(activity, MotionEvent.ACTION_UP, 100f, 500f, 1000)
        assertEquals(0, activity.dismissCount)
        assertEquals(0f, activity.window.decorView.translationY, 0.001f)
        assertFalse(activity.touchActions.contains(MotionEvent.ACTION_CANCEL))
    }

    @Test
    fun horizontalGesture_doesNotDragSheet() = withLaidOutSheet { activity ->
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, 0)
        touch(activity, MotionEvent.ACTION_MOVE, 500f, 120f, 500)
        touch(activity, MotionEvent.ACTION_UP, 500f, 500f, 1000)
        assertEquals(0, activity.dismissCount)
        assertEquals(0f, activity.window.decorView.translationY, 0.001f)
    }

    @Test
    fun tap_stillClicksChild() = withLaidOutSheet { activity ->
        val start = SystemClock.uptimeMillis()
        touch(activity, MotionEvent.ACTION_DOWN, 100f, 100f, start)
        touch(activity, MotionEvent.ACTION_UP, 100f, 100f, start + 50)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, activity.clickCount)
        assertEquals(0, activity.dismissCount)
    }

    @Test
    fun finishBeforeContent_invokesHookOnceAndPreservesResult() {
        val intent = Intent().putExtra("skipContent", true)
        val controller = Robolectric.buildActivity(TestSheetActivity::class.java, intent).create()
        val activity = controller.get()
        try {
            activity.setResult(Activity.RESULT_OK)
            activity.finish()
            activity.finish()
            assertEquals(1, activity.dismissCount)
            assertTrue(activity.dismissStateObserved)
            assertTrue(activity.isFinishing)
            assertEquals(Activity.RESULT_OK, shadowOf(activity).resultCode)
        } finally {
            controller.destroy()
        }
    }

    @Test
    fun destroyWithoutDismissal_doesNotInvokeDismissHookOrFinishLater() {
        val controller = Robolectric.buildActivity(TestSheetActivity::class.java).setup()
        val activity = controller.get()
        controller.pause().stop().destroy()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals(0, activity.dismissCount)
        assertFalse(activity.isFinishing)
    }
}
