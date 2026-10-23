package io.github.kokemus.cross_bluetooth_api.views

import android.app.Activity
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.TextView
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [29, 32, 35])
class SheetActivityTest {
    class TestSheetActivity : SheetActivity() {
        var dismissCount = 0
        var dismissStateObserved = false

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            if (!intent.getBooleanExtra("skipContent", false)) {
                setContentView(TextView(this))
                configureSheet(savedInstanceState)
            }
        }

        override fun onDismissStarted() {
            dismissCount++
            dismissStateObserved = isDismissing
        }
    }

    @Test
    fun configuration_preservesSheetAppearanceWithoutChooserContent() {
        val controller = Robolectric.buildActivity(TestSheetActivity::class.java).setup()
        try {
            val activity = controller.get()
            assertEquals(Gravity.BOTTOM, activity.window.attributes.gravity)
            assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, activity.window.attributes.width)
            assertTrue(activity.window.attributes.height > 0)
            assertEquals(0.4f, activity.window.attributes.dimAmount, 0.001f)
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
