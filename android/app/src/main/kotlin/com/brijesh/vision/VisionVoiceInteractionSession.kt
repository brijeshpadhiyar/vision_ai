package com.brijesh.vision

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.service.voice.VoiceInteractionSession
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.TextView
import androidx.core.content.ContextCompat
import kotlin.math.max
import kotlin.math.min

/**
 * Liquid Glass system assistant overlay rendered via Android's
 * [VoiceInteractionSession] directly over the user's current screen with
 * pause-tolerant multi-segment speech accumulation and seamless handoff to
 * VISION's full Flutter assistant experience.
 */
class VisionVoiceInteractionSession(context: Context) : VoiceInteractionSession(context) {

    companion object {
        private const val DEFAULT_ENDPOINT_SILENCE_MS = 3800L
        private const val DEFAULT_INITIAL_TIMEOUT_MS = 7500L
        private const val DEFAULT_MAX_SESSION_MS = 45000L
        private const val SEGMENT_RESTART_DELAY_MS = 90L
        private const val MANUAL_STOP_GRACE_MS = 650L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var rootView: View? = null
    private var orbView: VisionAssistantPulseView? = null
    private var langView: TextView? = null
    private var statusView: TextView? = null
    private var transcriptView: TextView? = null
    private var responseView: TextView? = null
    private var micButton: Button? = null
    private var cancelButton: Button? = null

    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false
    private var isListening = false

    private var activeSessionId = 0L
    private var endpointSilenceMs = DEFAULT_ENDPOINT_SILENCE_MS
    private var sessionStartedAtMs = 0L
    private var lastSpeechActivityAtMs = 0L
    private var manualFinishRequested = false
    private var segmentActive = false
    private var currentPartial = ""
    private val accumulatedSegments = mutableListOf<String>()
    private val accumulatedHypotheses = mutableListOf<List<String>>()

    private var endpointRunnable: Runnable? = null
    private var maxDurationRunnable: Runnable? = null
    private var restartRunnable: Runnable? = null
    private var manualFallbackRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        textToSpeech = TextToSpeech(context.applicationContext) { status ->
            isTtsReady = (status == TextToSpeech.SUCCESS)
        }
    }

    override fun onCreateContentView(): View {
        val view = LayoutInflater.from(context).inflate(R.layout.vision_assistant_overlay, null)
        rootView = view.findViewById(R.id.vision_overlay_root)
        orbView = view.findViewById(R.id.vision_overlay_orb)
        langView = view.findViewById(R.id.vision_overlay_lang)
        statusView = view.findViewById(R.id.vision_overlay_status)
        transcriptView = view.findViewById(R.id.vision_overlay_transcript)
        responseView = view.findViewById(R.id.vision_overlay_response)
        micButton = view.findViewById(R.id.vision_overlay_mic_btn)
        cancelButton = view.findViewById(R.id.vision_overlay_dismiss_btn)

        val openAppBtn: Button = view.findViewById(R.id.vision_overlay_open_app_btn)

        micButton?.setOnClickListener {
            if (isListening) {
                finishListening()
            } else {
                startListening()
            }
        }

        openAppBtn.setOnClickListener {
            val currentText = combineSegments(accumulatedSegments, currentPartial)
            val alts = buildCombinedHypotheses()
            cancelSessionOnly()
            openFullVisionAssistant(
                prompt = currentText.ifBlank { null },
                hypotheses = alts,
            )
        }

        cancelButton?.setOnClickListener {
            if (isListening) {
                cancelSessionOnly()
                statusView?.text = "Cancelled"
                responseView?.text = "Tap Speak to start a new command."
            } else {
                hide()
            }
        }

        return view
    }

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        val localeTag = resolvePreferredLocaleTag()
        endpointSilenceMs = resolveEndpointSilenceMs()
        langView?.text = "Locale: $localeTag • Pause-Tolerant Voice"
        statusView?.text = "Ready"
        responseView?.text = ""

        rootView?.apply {
            alpha = 0f
            translationY = 48f
            animate()
                .alpha(1f)
                .translationY(0f)
                .setDuration(240L)
                .start()
        }

        if (hasMicPermission()) {
            startListening()
        } else {
            transcriptView?.text = "Microphone permission is needed for voice input."
            statusView?.text = "Permission"
        }
    }

    private fun resolvePreferredLocaleTag(): String {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        return when (prefs.getString("flutter.vision_pref_voice_language", "english")) {
            "hindi" -> "hi-IN"
            "gujarati" -> "gu-IN"
            else -> "en-IN"
        }
    }

    private fun resolveEndpointSilenceMs(): Long {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val stored = prefs.getLong("flutter.vision_pref_endpoint_silence_ms", DEFAULT_ENDPOINT_SILENCE_MS)
        return stored.coerceIn(1800L, 8000L)
    }

    private fun hasMicPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun startListening() {
        if (!hasMicPermission()) {
            openFullVisionAssistant(prompt = null, hypotheses = emptyList())
            return
        }

        cancelTimers()
        destroyRecognizer()

        activeSessionId += 1L
        val sessionId = activeSessionId
        val now = System.currentTimeMillis()
        sessionStartedAtMs = now
        lastSpeechActivityAtMs = now
        manualFinishRequested = false
        segmentActive = false
        currentPartial = ""
        accumulatedSegments.clear()
        accumulatedHypotheses.clear()

        isListening = true
        orbView?.setListeningActive(true)
        statusView?.text = "Listening"
        micButton?.text = "Done"
        cancelButton?.text = "Cancel"
        transcriptView?.text = "Listening for your command..."
        responseView?.text = "Short pauses are preserved. Speak naturally or tap Done."

        val capRunnable = Runnable {
            if (sessionId == activeSessionId && isListening) {
                finalizeSession(sessionId)
            }
        }
        maxDurationRunnable = capRunnable
        mainHandler.postDelayed(capRunnable, DEFAULT_MAX_SESSION_MS)

        startSegment(sessionId)
    }

    private fun startSegment(sessionId: Long) {
        if (sessionId != activeSessionId || !isListening || manualFinishRequested) return
        destroyRecognizer()

        val recognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(createListener(sessionId))
        }
        speechRecognizer = recognizer
        segmentActive = true

        val localeTag = resolvePreferredLocaleTag()
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, endpointSilenceMs)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                max(2000L, endpointSilenceMs - 1000L),
            )
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000L)
        }
        try {
            recognizer.startListening(intent)
        } catch (_: Exception) {
            segmentActive = false
            finalizeSession(sessionId)
        }
    }

    private fun finishListening() {
        if (!isListening) return
        val sessionId = activeSessionId
        manualFinishRequested = true
        cancelEndpointTimer()
        cancelRestartTimer()
        statusView?.text = "Finalizing"

        if (segmentActive && speechRecognizer != null) {
            try {
                speechRecognizer?.stopListening()
            } catch (_: Exception) {
                finalizeSession(sessionId)
                return
            }
            val fallback = Runnable {
                if (sessionId == activeSessionId && isListening) {
                    finalizeSession(sessionId)
                }
            }
            manualFallbackRunnable = fallback
            mainHandler.postDelayed(fallback, MANUAL_STOP_GRACE_MS)
        } else {
            finalizeSession(sessionId)
        }
    }

    private fun cancelSessionOnly() {
        activeSessionId += 1L
        cancelTimers()
        destroyRecognizer()
        accumulatedSegments.clear()
        accumulatedHypotheses.clear()
        currentPartial = ""
        manualFinishRequested = false
        segmentActive = false
        isListening = false
        orbView?.setListeningActive(false)
        orbView?.setAudioLevel(0f)
        micButton?.text = "Speak"
        cancelButton?.text = "Close"
    }

    private fun finalizeSession(sessionId: Long) {
        if (sessionId != activeSessionId) return
        val finalText = combineSegments(accumulatedSegments, currentPartial)
        val alts = buildCombinedHypotheses()
        cancelSessionOnly()

        if (finalText.isNotEmpty()) {
            transcriptView?.text = finalText
            statusView?.text = "Understanding"
            openFullVisionAssistant(finalText, alts)
        } else {
            statusView?.text = "Tap Speak"
            responseView?.text = "Could not hear clearly. Tap Speak or open Full Assistant."
        }
    }

    private fun openFullVisionAssistant(prompt: String?, hypotheses: List<String>) {
        val intent = Intent(context, AssistantOverlayActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (!prompt.isNullOrBlank()) {
                putExtra("initialPrompt", prompt)
            }
            if (hypotheses.isNotEmpty()) {
                putStringArrayListExtra("initialHypotheses", ArrayList(hypotheses))
            }
        }
        try {
            startAssistantActivity(intent)
        } catch (_: Exception) {
            context.startActivity(intent)
        }
        hide()
    }

    private fun createListener(sessionId: Long): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                if (sessionId != activeSessionId || !isListening) return
                statusView?.text = "Listening"
                orbView?.setListeningActive(true)
            }

            override fun onBeginningOfSpeech() {
                if (sessionId != activeSessionId || !isListening) return
                lastSpeechActivityAtMs = System.currentTimeMillis()
                cancelEndpointTimer()
                statusView?.text = if (accumulatedSegments.isNotEmpty() || currentPartial.isNotEmpty()) {
                    "Transcribing"
                } else {
                    "Listening"
                }
            }

            override fun onRmsChanged(rmsdB: Float) {
                if (sessionId != activeSessionId || !isListening) return
                val clamped = min(10.0f, max(0.0f, rmsdB + 2.0f))
                orbView?.setAudioLevel(clamped / 10.0f)
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                if (sessionId != activeSessionId || !isListening) return
                segmentActive = false
                if (!manualFinishRequested && (accumulatedSegments.isNotEmpty() || currentPartial.isNotEmpty())) {
                    statusView?.text = "Pause OK"
                }
            }

            override fun onError(error: Int) {
                if (sessionId != activeSessionId || !isListening) return
                segmentActive = false

                if (manualFinishRequested) {
                    finalizeSession(sessionId)
                    return
                }

                val now = System.currentTimeMillis()
                val elapsedSession = now - sessionStartedAtMs
                val silenceElapsed = now - lastSpeechActivityAtMs
                val hasText = accumulatedSegments.isNotEmpty() || currentPartial.isNotEmpty()

                if ((error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                    if (hasText) {
                        if (currentPartial.isNotEmpty() && accumulatedSegments.isEmpty()) {
                            accumulatedSegments.add(currentPartial)
                            accumulatedHypotheses.add(listOf(currentPartial))
                            currentPartial = ""
                        }
                        if (silenceElapsed >= endpointSilenceMs) {
                            finalizeSession(sessionId)
                        } else {
                            statusView?.text = "Pause OK"
                            val remaining = max(350L, endpointSilenceMs - silenceElapsed)
                            scheduleEndpoint(sessionId, remaining)
                            scheduleRestart(sessionId)
                        }
                    } else if (elapsedSession < DEFAULT_INITIAL_TIMEOUT_MS) {
                        scheduleRestart(sessionId)
                    } else {
                        cancelSessionOnly()
                        statusView?.text = "Tap Speak"
                        responseView?.text = "Could not hear clearly. Tap Speak or open Full Assistant."
                    }
                } else if (hasText) {
                    finalizeSession(sessionId)
                } else {
                    cancelSessionOnly()
                    statusView?.text = "Tap Speak"
                    responseView?.text = "Speech recognition unavailable right now."
                }
            }

            override fun onResults(results: Bundle?) {
                if (sessionId != activeSessionId || !isListening) return
                segmentActive = false

                val matches = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.map { it.trim() }
                    ?.filter { it.isNotEmpty() }
                    ?.distinct()
                    ?.take(5)
                    ?: emptyList()

                if (matches.isNotEmpty()) {
                    val text = matches.first()
                    if (accumulatedSegments.lastOrNull()?.equals(text, ignoreCase = true) != true) {
                        accumulatedSegments.add(text)
                        accumulatedHypotheses.add(matches)
                    }
                    currentPartial = ""
                    lastSpeechActivityAtMs = System.currentTimeMillis()
                }

                val combined = combineSegments(accumulatedSegments, currentPartial)
                if (combined.isNotEmpty()) {
                    transcriptView?.text = combined
                }

                if (manualFinishRequested) {
                    finalizeSession(sessionId)
                    return
                }

                if (combined.isNotEmpty()) {
                    statusView?.text = "Pause OK"
                    responseView?.text = "Keep speaking or tap Done to send."
                    scheduleEndpoint(sessionId, endpointSilenceMs)
                    scheduleRestart(sessionId)
                } else if ((System.currentTimeMillis() - sessionStartedAtMs) < DEFAULT_INITIAL_TIMEOUT_MS) {
                    scheduleRestart(sessionId)
                } else {
                    finalizeSession(sessionId)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (sessionId != activeSessionId || !isListening) return
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull()?.trim() ?: ""
                if (text.isNotEmpty()) {
                    currentPartial = text
                    lastSpeechActivityAtMs = System.currentTimeMillis()
                    cancelEndpointTimer()
                    statusView?.text = "Transcribing"
                    transcriptView?.text = combineSegments(accumulatedSegments, currentPartial)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    private fun combineSegments(segments: List<String>, partial: String): String {
        val parts = ArrayList<String>(segments.size + 1)
        for (s in segments) {
            if (s.isNotBlank()) parts.add(s.trim())
        }
        if (partial.isNotBlank() && parts.lastOrNull()?.equals(partial.trim(), ignoreCase = true) != true) {
            parts.add(partial.trim())
        }
        return parts.joinToString(" ").replace(Regex("\\s+"), " ").trim()
    }

    private fun buildCombinedHypotheses(): List<String> {
        if (accumulatedHypotheses.isEmpty()) {
            val combined = combineSegments(accumulatedSegments, currentPartial)
            return if (combined.isNotEmpty()) listOf(combined) else emptyList()
        }
        val prefix = if (accumulatedHypotheses.size > 1) {
            accumulatedHypotheses.dropLast(1).mapNotNull { it.firstOrNull() }.joinToString(" ").trim()
        } else {
            ""
        }
        val out = LinkedHashSet<String>()
        for (alt in accumulatedHypotheses.last()) {
            val full = if (prefix.isNotEmpty()) "$prefix $alt" else alt
            val normalized = full.replace(Regex("\\s+"), " ").trim()
            if (normalized.isNotEmpty()) out.add(normalized)
        }
        return out.take(5).toList()
    }

    private fun scheduleEndpoint(sessionId: Long, delayMs: Long) {
        cancelEndpointTimer()
        val r = Runnable {
            if (sessionId == activeSessionId && isListening && !manualFinishRequested) {
                finalizeSession(sessionId)
            }
        }
        endpointRunnable = r
        mainHandler.postDelayed(r, delayMs)
    }

    private fun scheduleRestart(sessionId: Long) {
        cancelRestartTimer()
        val r = Runnable {
            if (sessionId == activeSessionId && isListening && !manualFinishRequested) {
                startSegment(sessionId)
            }
        }
        restartRunnable = r
        mainHandler.postDelayed(r, SEGMENT_RESTART_DELAY_MS)
    }

    private fun cancelTimers() {
        cancelEndpointTimer()
        cancelRestartTimer()
        maxDurationRunnable?.let { mainHandler.removeCallbacks(it) }
        maxDurationRunnable = null
        manualFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        manualFallbackRunnable = null
    }

    private fun cancelEndpointTimer() {
        endpointRunnable?.let { mainHandler.removeCallbacks(it) }
        endpointRunnable = null
    }

    private fun cancelRestartTimer() {
        restartRunnable?.let { mainHandler.removeCallbacks(it) }
        restartRunnable = null
    }

    private fun destroyRecognizer() {
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {
        }
        speechRecognizer = null
        segmentActive = false
    }

    override fun onHide() {
        cancelSessionOnly()
        textToSpeech?.stop()
        super.onHide()
    }

    override fun onDestroy() {
        cancelSessionOnly()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
