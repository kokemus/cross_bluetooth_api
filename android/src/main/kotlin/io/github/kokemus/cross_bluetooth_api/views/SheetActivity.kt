package io.github.kokemus.cross_bluetooth_api.views

import android.animation.ValueAnimator
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import androidx.activity.ComponentActivity
import androidx.core.graphics.drawable.toDrawable

/** Floating-window presentation, independent of the content hosted by the sheet. */
abstract class SheetActivity : ComponentActivity() {
    protected var isDismissing: Boolean = false
        private set

    private var sheet: ViewGroup? = null
    private var entranceListener: View.OnLayoutChangeListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val nightMode = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        setTheme(if (nightMode == Configuration.UI_MODE_NIGHT_YES) {
            android.R.style.Theme_DeviceDefault_Dialog_NoActionBar
        } else {
            android.R.style.Theme_DeviceDefault_Light_Dialog_NoActionBar
        })
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawable(Color.TRANSPARENT.toDrawable())
        window.decorView.setPadding(0, 0, 0, 0)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.attributes = window.attributes.apply {
            dimAmount = 0.4f
            windowAnimations = 0
            gravity = Gravity.BOTTOM
        }
        setFinishOnTouchOutside(true)
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    /** Call once after installing the content and any action bar. */
    protected fun configureSheet(savedInstanceState: Bundle?) {
        check(sheet == null) { "Sheet is already configured" }
        val backgroundColor = TypedValue().also {
            theme.resolveAttribute(android.R.attr.colorBackgroundFloating, it, true)
        }.data
        val radius = (24 * resources.displayMetrics.density).toInt().toFloat()
        val decor = (window.decorView as ViewGroup).apply {
            background = GradientDrawable().apply {
                setColor(backgroundColor)
                cornerRadii = floatArrayOf(radius, radius, radius, radius, 0f, 0f, 0f, 0f)
            }
            clipToOutline = true
        }
        sheet = decor
        updateSheetSize()
        entranceListener = object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                view: View, left: Int, top: Int, right: Int, bottom: Int,
                oldLeft: Int, oldTop: Int, oldRight: Int, oldBottom: Int
            ) {
                if (view.height == 0) return
                view.removeOnLayoutChangeListener(this)
                entranceListener = null
                if (!isDismissing && savedInstanceState == null && ValueAnimator.areAnimatorsEnabled()) {
                    view.translationY = view.height.toFloat()
                    view.animate().translationY(0f).setDuration(250)
                        .setInterpolator(DecelerateInterpolator()).start()
                }
            }
        }.also { decor.addOnLayoutChangeListener(it) }
    }

    private fun updateSheetSize() {
        val height = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = windowManager.currentWindowMetrics
            val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
            )
            metrics.bounds.height() - insets.top - insets.bottom
        } else {
            resources.displayMetrics.heightPixels
        }
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, (height * 0.85f).toInt())
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (sheet != null) updateSheetSize()
    }

    /** Invoked once, before any exit animation, including exits before content is installed. */
    protected open fun onDismissStarted() {}

    final override fun finish() {
        if (isDismissing || isFinishing || isDestroyed) return
        isDismissing = true
        onDismissStarted()
        val decor = sheet
        if (decor != null && decor.isAttachedToWindow && decor.height > 0 &&
            ValueAnimator.areAnimatorsEnabled()
        ) {
            decor.animate().cancel()
            decor.animate().translationY(decor.height.toFloat()).setDuration(200)
                .withEndAction { if (!isDestroyed) finishImmediately() }.start()
        } else {
            finishImmediately()
        }
    }

    private fun finishImmediately() {
        super.finish()
        if (Build.VERSION.SDK_INT < 34) {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    override fun onDestroy() {
        sheet?.let { decor ->
            entranceListener?.let { decor.removeOnLayoutChangeListener(it) }
            decor.animate().withEndAction(null).cancel()
        }
        entranceListener = null
        sheet = null
        super.onDestroy()
    }
}
