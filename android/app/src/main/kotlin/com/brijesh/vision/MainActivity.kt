package com.brijesh.vision

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var voiceChannel: VisionVoiceChannel? = null
    private var automationChannel: VisionAutomationChannel? = null

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
    }

    override fun onResume() {
        super.onResume()
        VisionWakeWordService.isForegroundAppActive = true
    }

    override fun onPause() {
        VisionWakeWordService.isForegroundAppActive = false
        super.onPause()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val voiceHandled = voiceChannel?.onActivityResult(requestCode, resultCode) ?: false
        if (!voiceHandled) {
            super.onActivityResult(requestCode, resultCode, data)
        }
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
