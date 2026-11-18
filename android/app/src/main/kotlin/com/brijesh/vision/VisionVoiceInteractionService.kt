package com.brijesh.vision

import android.os.Bundle
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession

/**
 * System-level Android [VoiceInteractionService] enabling VISION to act as
 * the device's Default Digital Assistant when granted `ROLE_ASSISTANT`.
 */
class VisionVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
    }

    override fun onLaunchVoiceAssistFromKeyguard() {
        showSession(Bundle(), VoiceInteractionSession.SHOW_WITH_ASSIST)
    }
}
