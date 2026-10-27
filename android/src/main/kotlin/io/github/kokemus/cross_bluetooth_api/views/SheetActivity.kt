package io.github.kokemus.cross_bluetooth_api.views

import android.animation.ValueAnimator
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
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
    private var touchStartX = 0f
    private var touchStartY = 0f
    private var canDrag = false
    private var isDragging = false
    private var ignoreTouchUntilUp = false
    private var velocityTracker: VelocityTracker? = null

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

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        val decor = sheet ?: return super.dispatchTouchEvent(event)
        if (isDismissing) return true
        if (ignoreTouchUntilUp && event.actionMasked != MotionEvent.ACTION_DOWN) {
            if (event.actionMasked == MotionEvent.ACTION_UP || event.actionMasked == MotionEvent.ACTION_CANCEL) {
                ignoreTouchUntilUp = false
            }
            return true
        }
        val configuration = ViewConfiguration.get(this)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                resetDrag()
                ignoreTouchUntilUp = false
                touchStartX = event.rawX
                touchStartY = event.rawY
                canDrag = !canScrollUpAt(decor, event.rawX, event.rawY)
                velocityTracker = VelocityTracker.obtain().also { it.addMovement(event) }
            }
            MotionEvent.ACTION_MOVE -> {
                velocityTracker?.addMovement(event)
                val distanceX = event.rawX - touchStartX
                val distanceY = event.rawY - touchStartY
                if (canDrag && !isDragging &&
                    maxOf(kotlin.math.abs(distanceX), kotlin.math.abs(distanceY)) > configuration.scaledTouchSlop
                ) {
                    canDrag = distanceY > kotlin.math.abs(distanceX)
                    if (canDrag) {
                        isDragging = true
                        decor.animate().cancel()
                        val cancel = MotionEvent.obtain(event)
                        cancel.action = MotionEvent.ACTION_CANCEL
                        super.dispatchTouchEvent(cancel)
                        cancel.recycle()
                    }
                }
                if (isDragging) {
                    decor.translationY = (distanceY - configuration.scaledTouchSlop).coerceAtLeast(0f)
                    return true
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_POINTER_DOWN -> {
                val wasDragging = isDragging
                if (wasDragging) {
                    velocityTracker?.addMovement(event)
                    velocityTracker?.computeCurrentVelocity(1000, configuration.scaledMaximumFlingVelocity.toFloat())
                    val velocity = velocityTracker?.yVelocity ?: 0f
                    val dismiss = event.actionMasked == MotionEvent.ACTION_UP &&
                        (decor.translationY >= decor.height * 0.25f ||
                            (decor.translationY > configuration.scaledTouchSlop &&
                                velocity > maxOf(configuration.scaledMinimumFlingVelocity.toFloat(),
                                    1000 * resources.displayMetrics.density)))
                    if (dismiss) {
                        finish()
                    } else if (ValueAnimator.areAnimatorsEnabled()) {
                        decor.animate().translationY(0f).setDuration(200)
                            .setInterpolator(DecelerateInterpolator()).start()
                    } else {
                        decor.translationY = 0f
                    }
                }
                resetDrag()
                if (wasDragging) {
                    ignoreTouchUntilUp = event.actionMasked == MotionEvent.ACTION_POINTER_DOWN
                    return true
                }
            }
        }
        return super.dispatchTouchEvent(event)
    }

    private fun canScrollUpAt(view: View, screenX: Float, screenY: Float): Boolean {
        val location = IntArray(2)
        view.getLocationOnScreen(location)
        if (screenX < location[0] || screenX >= location[0] + view.width ||
            screenY < location[1] || screenY >= location[1] + view.height
        ) return false
        if (view.canScrollVertically(-1)) return true
        if (view is ViewGroup) {
            for (index in view.childCount - 1 downTo 0) {
                if (view.getChildAt(index).visibility == View.VISIBLE &&
                    canScrollUpAt(view.getChildAt(index), screenX, screenY)
                ) return true
            }
        }
        return false
    }

    private fun resetDrag() {
        velocityTracker?.recycle()
        velocityTracker = null
        canDrag = false
        isDragging = false
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
        resetDrag()
        sheet?.let { decor ->
            entranceListener?.let { decor.removeOnLayoutChangeListener(it) }
            decor.animate().withEndAction(null).cancel()
        }
        entranceListener = null
        sheet = null
        super.onDestroy()
    }
}
