package com.brijesh.vision

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.View
import android.view.animation.LinearInterpolator
import kotlin.math.min

/**
 * Animated neon-cyan Liquid Glass orb visualizer rendered natively inside
 * Android's [VoiceInteractionSession] overlay window.
 */
class VisionAssistantPulseView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : View(context, attrs, defStyleAttr) {

    private var pulsePhase = 0f
    private var audioLevel = 0f
    private var isActiveListening = false

    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 3f
    }
    private val corePaint = Paint(Paint.ANTI_ALIAS_FLAG)

    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 1600L
        repeatCount = ValueAnimator.INFINITE
        repeatMode = ValueAnimator.RESTART
        interpolator = LinearInterpolator()
        addUpdateListener {
            pulsePhase = it.animatedFraction
            invalidate()
        }
    }

    fun setAudioLevel(normalizedLevel: Float) {
        val clamped = normalizedLevel.coerceIn(0f, 1f)
        audioLevel = (audioLevel * 0.4f) + (clamped * 0.6f)
        invalidate()
    }

    fun setListeningActive(active: Boolean) {
        isActiveListening = active
        if (!animator.isStarted) {
            animator.start()
        }
        invalidate()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (!animator.isStarted) {
            animator.start()
        }
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val radius = min(cx, cy) * 0.72f
        if (radius <= 0f) return

        val dynamicBoost = if (isActiveListening) (audioLevel * radius * 0.25f) else 0f

        glowPaint.shader = RadialGradient(
            cx,
            cy,
            radius * 1.35f + dynamicBoost,
            intArrayOf(
                Color.argb(if (isActiveListening) 115 else 65, 0, 212, 255),
                Color.argb(30, 57, 133, 255),
                Color.TRANSPARENT,
            ),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, radius * 1.35f + dynamicBoost, glowPaint)

        // Expanding ripple ring
        val ringRadius = radius * (0.65f + (pulsePhase * 0.65f)) + dynamicBoost * 0.5f
        val ringAlpha = ((1f - pulsePhase) * if (isActiveListening) 180 else 95).toInt()
        ringPaint.color = Color.argb(ringAlpha.coerceIn(0, 255), 0, 212, 255)
        canvas.drawCircle(cx, cy, ringRadius, ringPaint)

        // Inner radiant orb core
        corePaint.shader = RadialGradient(
            cx - radius * 0.16f,
            cy - radius * 0.16f,
            radius * 0.68f + dynamicBoost * 0.25f,
            intArrayOf(
                Color.rgb(210, 250, 255),
                Color.rgb(0, 212, 255),
                Color.rgb(57, 133, 255),
            ),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, radius * 0.56f + dynamicBoost * 0.25f, corePaint)
    }
}
