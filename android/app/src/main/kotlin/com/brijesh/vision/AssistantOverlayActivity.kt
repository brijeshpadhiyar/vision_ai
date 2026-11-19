package com.brijesh.vision

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine

/**
 * Gemini-like translucent Flutter assistant sheet activity launched by
 * "Hey VISION" wake-word triggers or Android's system Assistant session.
 */
class AssistantOverlayActivity : FlutterActivity() {
    private var voiceChannel: VisionVoiceChannel? = null
    private var automationChannel: VisionAutomationChannel? = null

    override fun getInitialRoute(): String = "/assistant-overlay"

    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        voiceChannel = VisionVoiceChannel(
            activity = this,
            messenger = messenger,
        )
        automationChannel = VisionAutomationChannel(
            activity = this,
            messenger = messenger,
        )
        val initialPrompt = intent?.getStringExtra("initialPrompt")
        val initialHypotheses =
            intent?.getStringArrayListExtra("initialHypotheses") ?: emptyList()
        if (!initialPrompt.isNullOrBlank()) {
            voiceChannel?.queueOverlayPrompt(initialPrompt, initialHypotheses)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val initialPrompt = intent.getStringExtra("initialPrompt")
        val initialHypotheses =
            intent.getStringArrayListExtra("initialHypotheses") ?: emptyList()
        if (!initialPrompt.isNullOrBlank()) {
            voiceChannel?.queueOverlayPrompt(initialPrompt, initialHypotheses)
        }
    }

    override fun onResume() {
        super.onResume()
        VisionWakeWordService.isForegroundAppActive = true
        voiceChannel?.onHostResume()
    }

    override fun onPause() {
        VisionWakeWordService.isForegroundAppActive = false
        super.onPause()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        val voiceHandled = voiceChannel?.onRequestPermissionsResult(requestCode, grantResults) ?: false
        val automationHandled =
            automationChannel?.onRequestPermissionsResult(requestCode, grantResults) ?: false
        if (!voiceHandled && !automationHandled) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    override fun onDestroy() {
        voiceChannel?.dispose()
        voiceChannel = null
        automationChannel?.dispose()
        automationChannel = null
        super.onDestroy()
    }
}
