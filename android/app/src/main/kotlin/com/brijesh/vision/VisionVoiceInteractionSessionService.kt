package com.brijesh.vision

import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

/**
 * Creates [VisionVoiceInteractionSession] instances when the system assistant
 * gesture, button, or keyguard trigger invokes VISION.
 */
class VisionVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return VisionVoiceInteractionSession(this)
    }
}
