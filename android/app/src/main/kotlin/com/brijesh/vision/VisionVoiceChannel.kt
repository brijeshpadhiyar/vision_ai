package com.brijesh.vision

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

/**
 * Native Android voice engine bridging pause-tolerant multi-segment
 * [SpeechRecognizer] (STT), [TextToSpeech] (TTS), offline foreground
 * wake-word standby ([VisionWakeWordService]), and Assistant Role integration
 * for English (en-IN), Hindi (hi-IN), and Gujarati (gu-IN).
 */
class VisionVoiceChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    VisionWakeWordService.WakeWordServiceListener {

    companion object {
        private const val METHOD_CHANNEL_NAME = "com.brijesh.vision/voice"
        private const val EVENT_CHANNEL_NAME = "com.brijesh.vision/voice_events"
        const val REQUEST_RECORD_AUDIO_PERMISSION = 3001
        const val REQUEST_ASSISTANT_ROLE = 3002

        private const val DEFAULT_ENDPOINT_SILENCE_MS = 3800L
        private const val DEFAULT_INITIAL_TIMEOUT_MS = 7500L
        private const val DEFAULT_MAX_SESSION_DURATION_MS = 45000L
        private const val SEGMENT_RESTART_DELAY_MS = 90L
        private const val MANUAL_STOP_GRACE_MS = 650L
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRoleResult: MethodChannel.Result? = null
    private var queuedOverlayPrompt: String? = null
    private var queuedOverlayHypotheses: List<String> = emptyList()

    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false
    private var isListening = false
    private var isSpeaking = false
    private var isTtsPaused = false
    private var currentPhase = "idle"

    // Sentence-chunked TTS state for clean pause / resume (Module 02)
    private var ttsChunks: List<String> = emptyList()
    private var ttsCurrentChunkIndex = 0
    private var ttsSessionToken = 0L
    private var lastTtsLocaleTag = "en-IN"
    private var lastTtsSpeechRate = 1.0f
    private var lastTtsPitch = 1.0f
    private var lastTtsVoiceName = ""

    // Multi-segment utterance accumulation & endpointing state
    private var activeSessionId = 0L
    private var activeLocaleTag = "en-IN"
    private var endpointSilenceMs = DEFAULT_ENDPOINT_SILENCE_MS
    private var initialTimeoutMs = DEFAULT_INITIAL_TIMEOUT_MS
    private var maxSessionDurationMs = DEFAULT_MAX_SESSION_DURATION_MS
    private var sessionStartedAtMs = 0L
    private var lastSpeechActivityAtMs = 0L
    private var hasDetectedSpeechInSession = false
    private var manualFinishRequested = false
    private var segmentHasActiveRecognizer = false
    private var segmentCount = 0
    private var transientErrorRetries = 0
    private var currentPartialText = ""
    private val accumulatedSegments = mutableListOf<String>()
    private val accumulatedSegmentHypotheses = mutableListOf<List<String>>()
    private var lastConfidenceScores: List<Double>? = null

    private var endpointFinalizeRunnable: Runnable? = null
    private var maxDurationRunnable: Runnable? = null
    private var restartSegmentRunnable: Runnable? = null
    private var manualStopFallbackRunnable: Runnable? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        VisionWakeWordService.listener = this
        initializeTts()
    }

    fun onHostResume() {
        VisionWakeWordService.listener = this
        emitWakeServiceState()
    }

    fun queueOverlayPrompt(prompt: String, hypotheses: List<String> = emptyList()) {
        queuedOverlayPrompt = prompt
        queuedOverlayHypotheses = hypotheses
        emitEvent(
            mapOf(
                "type" to "overlayPrompt",
                "prompt" to prompt,
                "hypotheses" to hypotheses,
            ),
        )
    }

    private fun initializeTts() {
        textToSpeech = TextToSpeech(activity.applicationContext) { status ->
            isTtsReady = (status == TextToSpeech.SUCCESS)
            if (isTtsReady) {
                textToSpeech?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        isSpeaking = true
                        if (!isListening) {
                            currentPhase = "speaking"
                        }
                        emitState()
                    }

                    override fun onDone(utteranceId: String?) {
                        if (utteranceId == null || !utteranceId.startsWith("vision_tts_${ttsSessionToken}_")) {
                            return
                        }
                        if (isTtsPaused) return
                        val nextIdx = ttsCurrentChunkIndex + 1
                        if (nextIdx < ttsChunks.size) {
                            ttsCurrentChunkIndex = nextIdx
                            mainHandler.post { speakCurrentChunk() }
                            return
                        }
                        ttsChunks = emptyList()
                        ttsCurrentChunkIndex = 0
                        isSpeaking = false
                        isTtsPaused = false
                        if (!isListening) {
                            currentPhase = "idle"
                        }
                        emitState()
                        resumeWakeServiceIfRunning()
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        if (isTtsPaused) return
                        ttsChunks = emptyList()
                        ttsCurrentChunkIndex = 0
                        isSpeaking = false
                        isTtsPaused = false
                        if (!isListening) {
                            currentPhase = "idle"
                        }
                        emitState()
                        resumeWakeServiceIfRunning()
                    }
                })
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkMicrophonePermission" -> {
                result.success(hasAudioPermission())
            }
            "requestMicrophonePermission" -> {
                if (hasAudioPermission()) {
                    result.success(true)
                } else {
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        REQUEST_RECORD_AUDIO_PERMISSION,
                    )
                }
            }
            "isSpeechAvailable" -> {
                val available = SpeechRecognizer.isRecognitionAvailable(activity)
                result.success(available)
            }
            "startListening" -> {
                if (!hasAudioPermission()) {
                    result.error(
                        "PERMISSION_DENIED",
                        "Microphone permission is required for voice recognition.",
                        null,
                    )
                    return
                }
                val localeTag = call.argument<String>("locale") ?: "en-IN"
                val silenceMs = (call.argument<Number>("endpointSilenceMs")?.toLong()
                    ?: DEFAULT_ENDPOINT_SILENCE_MS).coerceIn(1800L, 8000L)
                val initialWaitMs = (call.argument<Number>("initialTimeoutMs")?.toLong()
                    ?: DEFAULT_INITIAL_TIMEOUT_MS).coerceIn(3000L, 15000L)
                val maxCapMs = (call.argument<Number>("maxDurationMs")?.toLong()
                    ?: DEFAULT_MAX_SESSION_DURATION_MS).coerceIn(10000L, 90000L)
                startSpeechListening(
                    localeTag = localeTag,
                    silenceMs = silenceMs,
                    initialWaitMs = initialWaitMs,
                    maxCapMs = maxCapMs,
                )
                result.success(true)
            }
            "stopListening" -> {
                finishSpeechListening()
                result.success(true)
            }
            "cancelListening" -> {
                cancelSpeechListening()
                result.success(true)
            }
            "speak" -> {
                val text = call.argument<String>("text") ?: ""
                val localeTag = call.argument<String>("locale") ?: "en-IN"
                val rate = (call.argument<Double>("speechRate") ?: 1.0).toFloat().coerceIn(0.5f, 2.0f)
                val pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat().coerceIn(0.5f, 2.0f)
                val voiceName = call.argument<String>("voiceName") ?: ""
                val spoke = speakText(text, localeTag, rate, pitch, voiceName)
                result.success(spoke)
            }
            "pauseSpeaking" -> {
                val paused = pauseTtsPlayback()
                result.success(paused)
            }
            "resumeSpeaking" -> {
                val resumed = resumeTtsPlayback()
                result.success(resumed)
            }
            "getAvailableVoices" -> {
                val localeFilter = call.argument<String>("locale")
                result.success(listAvailableTtsVoices(localeFilter))
            }
            "stopSpeaking" -> {
                ttsSessionToken += 1L
                ttsChunks = emptyList()
                ttsCurrentChunkIndex = 0
                isTtsPaused = false
                textToSpeech?.stop()
                isSpeaking = false
                if (!isListening) {
                    currentPhase = "idle"
                }
                emitState()
                resumeWakeServiceIfRunning()
                result.success(true)
            }
            "startWakeWordService" -> {
                if (!hasAudioPermission()) {
                    result.error(
                        "PERMISSION_DENIED",
                        "Microphone permission is required to start Hey VISION standby.",
                        null,
                    )
                    return
                }
                val sensitivity = call.argument<Double>("sensitivity") ?: 0.55
                val serviceIntent = Intent(activity, VisionWakeWordService::class.java).apply {
                    action = VisionWakeWordService.ACTION_START
                    putExtra(VisionWakeWordService.EXTRA_SENSITIVITY, sensitivity)
                }
                ContextCompat.startForegroundService(activity, serviceIntent)
                result.success(true)
            }
            "stopWakeWordService" -> {
                val serviceIntent = Intent(activity, VisionWakeWordService::class.java).apply {
                    action = VisionWakeWordService.ACTION_STOP
                }
                activity.startService(serviceIntent)
                result.success(true)
            }
            "setWakeWordSensitivity" -> {
                val sensitivity = call.argument<Double>("sensitivity") ?: 0.55
                val serviceIntent = Intent(activity, VisionWakeWordService::class.java).apply {
                    action = VisionWakeWordService.ACTION_UPDATE_SENSITIVITY
                    putExtra(VisionWakeWordService.EXTRA_SENSITIVITY, sensitivity)
                }
                if (VisionWakeWordService.isRunning) {
                    activity.startService(serviceIntent)
                }
                result.success(true)
            }
            "getWakeWordServiceStatus" -> {
                result.success(
                    mapOf(
                        "isRunning" to VisionWakeWordService.isRunning,
                        "isMicActive" to VisionWakeWordService.isMicActive,
                        "sensitivity" to VisionWakeWordService.currentSensitivity,
                    ),
                )
            }
            "isDefaultAssistant" -> {
                result.success(isDefaultAssistant())
            }
            "requestAssistantRole" -> {
                handleRequestAssistantRole(result)
            }
            "openAssistantOverlay" -> {
                val intent = Intent(activity, AssistantOverlayActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                activity.startActivity(intent)
                result.success(true)
            }
            "consumeOverlayPrompt" -> {
                val prompt = queuedOverlayPrompt
                queuedOverlayPrompt = null
                queuedOverlayHypotheses = emptyList()
                result.success(prompt)
            }
            "consumeOverlayPayload" -> {
                val payload = if (!queuedOverlayPrompt.isNullOrBlank()) {
                    mapOf(
                        "prompt" to queuedOverlayPrompt,
                        "hypotheses" to queuedOverlayHypotheses,
                    )
                } else {
                    null
                }
                queuedOverlayPrompt = null
                queuedOverlayHypotheses = emptyList()
                result.success(payload)
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_ASSISTANT_ROLE) return false
        pendingRoleResult?.success(resultCode == Activity.RESULT_OK || isDefaultAssistant())
        pendingRoleResult = null
        return true
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_RECORD_AUDIO_PERMISSION) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    private fun isDefaultAssistant(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_ASSISTANT)) {
                return roleManager.isRoleHeld(RoleManager.ROLE_ASSISTANT)
            }
        }
        val assistantSetting = Settings.Secure.getString(
            activity.contentResolver,
            "assistant",
        ) ?: ""
        return assistantSetting.contains(activity.packageName)
    }

    private fun handleRequestAssistantRole(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_ASSISTANT)) {
                if (roleManager.isRoleHeld(RoleManager.ROLE_ASSISTANT)) {
                    result.success(true)
                    return
                }
                if (pendingRoleResult != null) {
                    result.error("ROLE_BUSY", "Assistant role prompt is already active.", null)
                    return
                }
                pendingRoleResult = result
                val roleIntent = roleManager.createRequestRoleIntent(RoleManager.ROLE_ASSISTANT)
                @Suppress("DEPRECATION")
                activity.startActivityForResult(roleIntent, REQUEST_ASSISTANT_ROLE)
                return
            }
        }
        try {
            activity.startActivity(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))
            result.success(false)
        } catch (e: Exception) {
            result.error("ASSISTANT_SETTINGS_ERROR", e.message, null)
        }
    }

    private fun hasAudioPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun pauseWakeServiceIfRunning() {
        if (VisionWakeWordService.isRunning) {
            val pauseIntent = Intent(activity, VisionWakeWordService::class.java).apply {
                action = VisionWakeWordService.ACTION_PAUSE_MIC
            }
            activity.startService(pauseIntent)
        }
    }

    private fun resumeWakeServiceIfRunning() {
        if (VisionWakeWordService.isRunning && !isListening && !isSpeaking) {
            val resumeIntent = Intent(activity, VisionWakeWordService::class.java).apply {
                action = VisionWakeWordService.ACTION_RESUME_MIC
            }
            activity.startService(resumeIntent)
        }
    }

    private fun startSpeechListening(
        localeTag: String,
        silenceMs: Long,
        initialWaitMs: Long,
        maxCapMs: Long,
    ) {
        pauseWakeServiceIfRunning()

        // Never capture while VISION is speaking aloud.
        if (isSpeaking) {
            textToSpeech?.stop()
            isSpeaking = false
        }

        cancelSessionTimers()
        destroySpeechRecognizer()

        activeSessionId += 1L
        val sessionId = activeSessionId
        activeLocaleTag = localeTag
        endpointSilenceMs = silenceMs
        initialTimeoutMs = initialWaitMs
        maxSessionDurationMs = maxCapMs

        val now = System.currentTimeMillis()
        sessionStartedAtMs = now
        lastSpeechActivityAtMs = now
        hasDetectedSpeechInSession = false
        manualFinishRequested = false
        segmentHasActiveRecognizer = false
        segmentCount = 0
        transientErrorRetries = 0
        currentPartialText = ""
        accumulatedSegments.clear()
        accumulatedSegmentHypotheses.clear()
        lastConfidenceScores = null

        isListening = true
        currentPhase = "listening"
        emitState()

        val maxRunnable = Runnable {
            if (sessionId == activeSessionId && isListening) {
                if (hasAnyTranscript()) {
                    finalizeSession(sessionId)
                } else {
                    failSession(
                        sessionId,
                        code = "STT_SESSION_TIMEOUT",
                        message = "Listening timed out. Tap the microphone and speak your command.",
                    )
                }
            }
        }
        maxDurationRunnable = maxRunnable
        mainHandler.postDelayed(maxRunnable, maxSessionDurationMs)

        startRecognitionSegment(sessionId)
    }

    private fun startRecognitionSegment(sessionId: Long) {
        if (sessionId != activeSessionId || !isListening || isSpeaking || manualFinishRequested) {
            return
        }

        destroySpeechRecognizer()
        segmentCount += 1

        val recognizer = SpeechRecognizer.createSpeechRecognizer(activity).apply {
            setRecognitionListener(createRecognitionListener(sessionId))
        }
        speechRecognizer = recognizer
        segmentHasActiveRecognizer = true

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, activeLocaleTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, activeLocaleTag)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_CONFIDENCE_SCORES, true)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                endpointSilenceMs,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                max(2000L, endpointSilenceMs - 1000L),
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                2000L,
            )
        }

        try {
            recognizer.startListening(intent)
        } catch (e: Exception) {
            segmentHasActiveRecognizer = false
            if (hasAnyTranscript()) {
                finalizeSession(sessionId)
            } else {
                failSession(
                    sessionId,
                    code = "STT_START_ERROR",
                    message = "Unable to start speech recognizer: ${e.message}",
                )
            }
        }
    }

    /**
     * User-requested manual completion ("Done"): flushes accumulated speech and
     * gives an active recognizer a brief grace window to deliver final words.
     */
    private fun finishSpeechListening() {
        if (!isListening) return
        val sessionId = activeSessionId
        manualFinishRequested = true
        cancelEndpointTimer()
        cancelRestartTimer()

        currentPhase = "finalizing"
        emitState()

        if (segmentHasActiveRecognizer && speechRecognizer != null) {
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
            manualStopFallbackRunnable = fallback
            mainHandler.postDelayed(fallback, MANUAL_STOP_GRACE_MS)
        } else {
            finalizeSession(sessionId)
        }
    }

    /**
     * User-requested manual cancellation: aborts capture and discards buffers.
     */
    private fun cancelSpeechListening() {
        activeSessionId += 1L
        cancelSessionTimers()
        destroySpeechRecognizer()
        accumulatedSegments.clear()
        accumulatedSegmentHypotheses.clear()
        currentPartialText = ""
        lastConfidenceScores = null
        hasDetectedSpeechInSession = false
        manualFinishRequested = false
        segmentHasActiveRecognizer = false
        isListening = false
        currentPhase = "cancelled"
        emitState()
        currentPhase = "idle"
        emitState()
        resumeWakeServiceIfRunning()
    }

    private fun scheduleEndpointFinalize(sessionId: Long, delayMs: Long) {
        cancelEndpointTimer()
        val runnable = Runnable {
            if (sessionId == activeSessionId && isListening && !manualFinishRequested) {
                finalizeSession(sessionId)
            }
        }
        endpointFinalizeRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun scheduleNextSegment(sessionId: Long, delayMs: Long = SEGMENT_RESTART_DELAY_MS) {
        cancelRestartTimer()
        val runnable = Runnable {
            if (sessionId == activeSessionId && isListening && !isSpeaking && !manualFinishRequested) {
                startRecognitionSegment(sessionId)
            }
        }
        restartSegmentRunnable = runnable
        mainHandler.postDelayed(runnable, delayMs)
    }

    private fun finalizeSession(sessionId: Long) {
        if (sessionId != activeSessionId) return
        activeSessionId += 1L
        cancelSessionTimers()
        destroySpeechRecognizer()

        val finalTranscript = combineSegments(accumulatedSegments, currentPartialText)
        val finalHypotheses = buildCombinedHypotheses()
        val scores = lastConfidenceScores

        accumulatedSegments.clear()
        accumulatedSegmentHypotheses.clear()
        currentPartialText = ""
        lastConfidenceScores = null
        segmentHasActiveRecognizer = false
        manualFinishRequested = false

        isListening = false
        if (finalTranscript.isNotEmpty()) {
            currentPhase = "finalizing"
            emitState()
            emitEvent(
                mapOf(
                    "type" to "transcript",
                    "text" to finalTranscript,
                    "isFinal" to true,
                    "hypotheses" to finalHypotheses,
                    "confidenceScores" to scores,
                    "segmentCount" to segmentCount,
                ),
            )
            currentPhase = "idle"
            emitState()
        } else {
            currentPhase = "error"
            emitState()
            emitEvent(
                mapOf(
                    "type" to "error",
                    "code" to "STT_ERROR_${SpeechRecognizer.ERROR_NO_MATCH}",
                    "message" to "No speech recognized. Please speak clearly and try again.",
                ),
            )
        }

        resumeWakeServiceIfRunning()
    }

    private fun failSession(sessionId: Long, code: String, message: String) {
        if (sessionId != activeSessionId) return
        activeSessionId += 1L
        cancelSessionTimers()
        destroySpeechRecognizer()

        accumulatedSegments.clear()
        accumulatedSegmentHypotheses.clear()
        currentPartialText = ""
        lastConfidenceScores = null
        segmentHasActiveRecognizer = false
        manualFinishRequested = false
        isListening = false
        currentPhase = "error"
        emitState()
        emitEvent(
            mapOf(
                "type" to "error",
                "code" to code,
                "message" to message,
            ),
        )
        resumeWakeServiceIfRunning()
    }

    private fun speakText(
        text: String,
        localeTag: String,
        speechRate: Float,
        pitch: Float = 1.0f,
        voiceName: String = "",
    ): Boolean {
        val tts = textToSpeech
        if (!isTtsReady || tts == null || text.isBlank()) {
            return false
        }

        // Prevent wake-word AudioRecord contention and cancel active STT before TTS.
        if (isListening) {
            cancelSpeechListening()
        }
        pauseWakeServiceIfRunning()

        lastTtsLocaleTag = localeTag
        lastTtsSpeechRate = speechRate.coerceIn(0.5f, 2.0f)
        lastTtsPitch = pitch.coerceIn(0.5f, 2.0f)
        lastTtsVoiceName = voiceName.trim()

        applyTtsVoiceConfig(tts, lastTtsLocaleTag, lastTtsSpeechRate, lastTtsPitch, lastTtsVoiceName)

        ttsSessionToken += 1L
        ttsChunks = splitTtsChunks(text)
        ttsCurrentChunkIndex = 0
        isTtsPaused = false
        if (ttsChunks.isEmpty()) return false

        isSpeaking = true
        currentPhase = "speaking"
        emitState()
        return speakCurrentChunk()
    }

    private fun applyTtsVoiceConfig(
        tts: TextToSpeech,
        localeTag: String,
        speechRate: Float,
        pitch: Float,
        voiceName: String,
    ) {
        val locale = Locale.forLanguageTag(localeTag)
        var appliedCustomVoice = false
        if (voiceName.isNotEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val matched = try {
                tts.voices?.firstOrNull { it.name == voiceName }
            } catch (_: Exception) {
                null
            }
            if (matched != null && matched.locale.language.equals(locale.language, ignoreCase = true)) {
                tts.voice = matched
                appliedCustomVoice = true
            }
        }
        if (!appliedCustomVoice) {
            val availability = tts.isLanguageAvailable(locale)
            if (availability >= TextToSpeech.LANG_AVAILABLE) {
                tts.language = locale
            } else {
                tts.language = Locale.US
            }
        }
        tts.setSpeechRate(speechRate)
        tts.setPitch(pitch)
    }

    private fun speakCurrentChunk(): Boolean {
        val tts = textToSpeech ?: return false
        if (ttsCurrentChunkIndex !in ttsChunks.indices) {
            isSpeaking = false
            isTtsPaused = false
            if (!isListening) currentPhase = "idle"
            emitState()
            resumeWakeServiceIfRunning()
            return false
        }
        val chunk = ttsChunks[ttsCurrentChunkIndex]
        val utteranceId = "vision_tts_${ttsSessionToken}_$ttsCurrentChunkIndex"
        val status = tts.speak(chunk, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        if (status == TextToSpeech.ERROR) {
            ttsChunks = emptyList()
            ttsCurrentChunkIndex = 0
            isSpeaking = false
            isTtsPaused = false
            currentPhase = "idle"
            emitState()
            resumeWakeServiceIfRunning()
            return false
        }
        return true
    }

    private fun pauseTtsPlayback(): Boolean {
        if (!isSpeaking || ttsChunks.isEmpty()) return false
        isTtsPaused = true
        isSpeaking = false
        textToSpeech?.stop()
        if (!isListening) {
            currentPhase = "idle"
        }
        emitState()
        return true
    }

    private fun resumeTtsPlayback(): Boolean {
        val tts = textToSpeech ?: return false
        if (!isTtsPaused || ttsChunks.isEmpty() || ttsCurrentChunkIndex !in ttsChunks.indices) {
            return false
        }
        if (isListening) {
            cancelSpeechListening()
        }
        pauseWakeServiceIfRunning()
        applyTtsVoiceConfig(tts, lastTtsLocaleTag, lastTtsSpeechRate, lastTtsPitch, lastTtsVoiceName)
        ttsSessionToken += 1L
        isTtsPaused = false
        isSpeaking = true
        currentPhase = "speaking"
        emitState()
        return speakCurrentChunk()
    }

    private fun splitTtsChunks(text: String): List<String> {
        val cleaned = text.trim()
        if (cleaned.isEmpty()) return emptyList()
        val rawParts = cleaned
            .split(Regex("(?<=[.!?।\\n])\\s+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        return if (rawParts.isEmpty()) listOf(cleaned) else rawParts
    }

    private fun listAvailableTtsVoices(localeFilter: String?): List<Map<String, Any?>> {
        val tts = textToSpeech
        if (!isTtsReady || tts == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return emptyList()
        }
        val targetLang = localeFilter
            ?.takeIf { it.isNotBlank() && !it.equals("auto", ignoreCase = true) }
            ?.let { Locale.forLanguageTag(it).language }
        val allowedLanguages = setOf("en", "hi", "gu")
        val voices = try {
            tts.voices ?: emptySet()
        } catch (_: Exception) {
            emptySet()
        }
        return voices
            .filter { voice ->
                val lang = voice.locale?.language?.lowercase() ?: ""
                if (targetLang != null && targetLang.isNotBlank()) {
                    lang == targetLang.lowercase()
                } else {
                    lang in allowedLanguages
                }
            }
            .sortedWith(
                compareBy<android.speech.tts.Voice>(
                    { it.isNetworkConnectionRequired },
                    { -it.quality },
                    { it.name },
                ),
            )
            .take(30)
            .map { voice ->
                mapOf(
                    "name" to voice.name,
                    "locale" to voice.locale.toLanguageTag(),
                    "quality" to voice.quality,
                    "networkRequired" to voice.isNetworkConnectionRequired,
                )
            }
    }

    private fun createRecognitionListener(sessionId: Long): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                if (sessionId != activeSessionId || !isListening) return
                if (!hasDetectedSpeechInSession) {
                    currentPhase = "listening"
                }
                emitState()
            }

            override fun onBeginningOfSpeech() {
                if (sessionId != activeSessionId || !isListening) return
                hasDetectedSpeechInSession = true
                transientErrorRetries = 0
                lastSpeechActivityAtMs = System.currentTimeMillis()
                cancelEndpointTimer()
                if (currentPartialText.isNotEmpty() || accumulatedSegments.isNotEmpty()) {
                    currentPhase = "partial_transcription"
                } else {
                    currentPhase = "listening"
                }
                emitState()
            }

            override fun onRmsChanged(rmsdB: Float) {
                if (sessionId != activeSessionId || !isListening) return
                val clamped = min(10.0f, max(0.0f, rmsdB + 2.0f))
                val normalized = (clamped / 10.0f).toDouble()
                if (normalized >= 0.48 && currentPhase == "endpointing") {
                    // User resumed speaking during pause window — keep endpointing alive.
                    lastSpeechActivityAtMs = System.currentTimeMillis()
                }
                emitEvent(
                    mapOf(
                        "type" to "amplitude",
                        "rmsDb" to rmsdB.toDouble(),
                        "normalizedLevel" to normalized,
                    ),
                )
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                if (sessionId != activeSessionId || !isListening) return
                segmentHasActiveRecognizer = false
                if (!manualFinishRequested && hasAnyTranscript()) {
                    currentPhase = "endpointing"
                    emitState()
                }
            }

            override fun onError(error: Int) {
                if (sessionId != activeSessionId || !isListening) return
                segmentHasActiveRecognizer = false

                if (manualFinishRequested) {
                    finalizeSession(sessionId)
                    return
                }

                val now = System.currentTimeMillis()
                val elapsedSession = now - sessionStartedAtMs
                val silenceElapsed = now - lastSpeechActivityAtMs

                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                        if (hasAnyTranscript()) {
                            if (currentPartialText.isNotEmpty() && accumulatedSegments.isEmpty()) {
                                // Promote trailing partial text if recognizer timed out before onResults.
                                accumulatedSegments.add(currentPartialText)
                                accumulatedSegmentHypotheses.add(listOf(currentPartialText))
                                currentPartialText = ""
                            }
                            if (silenceElapsed >= endpointSilenceMs || elapsedSession >= maxSessionDurationMs) {
                                finalizeSession(sessionId)
                            } else {
                                currentPhase = "endpointing"
                                emitState()
                                val remainingMs = max(350L, endpointSilenceMs - silenceElapsed)
                                scheduleEndpointFinalize(sessionId, remainingMs)
                                scheduleNextSegment(sessionId)
                            }
                        } else if (elapsedSession < initialTimeoutMs) {
                            currentPhase = "listening"
                            emitState()
                            scheduleNextSegment(sessionId, 110L)
                        } else {
                            failSession(
                                sessionId,
                                code = "STT_ERROR_$error",
                                message = mapSpeechError(error),
                            )
                        }
                    }

                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                    SpeechRecognizer.ERROR_CLIENT -> {
                        if (transientErrorRetries < 2 && elapsedSession < maxSessionDurationMs) {
                            transientErrorRetries += 1
                            scheduleNextSegment(sessionId, 180L)
                        } else if (hasAnyTranscript()) {
                            finalizeSession(sessionId)
                        } else {
                            failSession(
                                sessionId,
                                code = "STT_ERROR_$error",
                                message = mapSpeechError(error),
                            )
                        }
                    }

                    else -> {
                        if (hasAnyTranscript()) {
                            finalizeSession(sessionId)
                        } else {
                            failSession(
                                sessionId,
                                code = "STT_ERROR_$error",
                                message = mapSpeechError(error),
                            )
                        }
                    }
                }
            }

            override fun onResults(results: Bundle?) {
                if (sessionId != activeSessionId || !isListening) return
                segmentHasActiveRecognizer = false

                val matches = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.map { it.trim() }
                    ?.filter { it.isNotEmpty() }
                    ?.distinct()
                    ?.take(5)
                    ?: emptyList()
                val rawScores = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                val validScores: List<Double>? = if (rawScores != null && rawScores.isNotEmpty()) {
                    val converted = rawScores
                        .take(matches.size)
                        .map { score -> score.toDouble() }
                        .filter { it in 0.0..1.0 }
                    converted.ifEmpty { null }
                } else {
                    null
                }

                if (matches.isNotEmpty()) {
                    val segmentText = matches.first()
                    if (accumulatedSegments.lastOrNull()?.equals(segmentText, ignoreCase = true) != true) {
                        accumulatedSegments.add(segmentText)
                        accumulatedSegmentHypotheses.add(matches)
                    }
                    lastConfidenceScores = validScores
                    currentPartialText = ""
                    hasDetectedSpeechInSession = true
                    lastSpeechActivityAtMs = System.currentTimeMillis()
                    transientErrorRetries = 0
                }

                val combinedPreview = combineSegments(accumulatedSegments, currentPartialText)
                val combinedHypotheses = buildCombinedHypotheses()

                if (manualFinishRequested ||
                    (System.currentTimeMillis() - sessionStartedAtMs) >= maxSessionDurationMs
                ) {
                    finalizeSession(sessionId)
                    return
                }

                if (combinedPreview.isNotEmpty()) {
                    emitEvent(
                        mapOf(
                            "type" to "transcript",
                            "text" to combinedPreview,
                            "isFinal" to false,
                            "hypotheses" to combinedHypotheses,
                            "confidenceScores" to lastConfidenceScores,
                            "segmentCount" to segmentCount,
                        ),
                    )
                    currentPhase = "endpointing"
                    emitState()

                    val waitMs = if (isBareWakeWordOnly(combinedPreview)) {
                        max(endpointSilenceMs, 4500L)
                    } else {
                        endpointSilenceMs
                    }
                    scheduleEndpointFinalize(sessionId, waitMs)
                    scheduleNextSegment(sessionId)
                } else if ((System.currentTimeMillis() - sessionStartedAtMs) < initialTimeoutMs) {
                    currentPhase = "listening"
                    emitState()
                    scheduleNextSegment(sessionId, 110L)
                } else {
                    finalizeSession(sessionId)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (sessionId != activeSessionId || !isListening) return
                val matches =
                    partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val partial = matches?.firstOrNull()?.trim() ?: ""
                if (partial.isNotEmpty()) {
                    hasDetectedSpeechInSession = true
                    lastSpeechActivityAtMs = System.currentTimeMillis()
                    currentPartialText = partial
                    cancelEndpointTimer()
                    currentPhase = "partial_transcription"
                    emitState()

                    val combined = combineSegments(accumulatedSegments, currentPartialText)
                    emitEvent(
                        mapOf(
                            "type" to "transcript",
                            "text" to combined,
                            "isFinal" to false,
                            "hypotheses" to buildCombinedHypotheses(),
                            "segmentCount" to segmentCount,
                        ),
                    )
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    private fun hasAnyTranscript(): Boolean {
        return accumulatedSegments.isNotEmpty() || currentPartialText.isNotBlank()
    }

    private fun combineSegments(segments: List<String>, trailingPartial: String): String {
        val parts = ArrayList<String>(segments.size + 1)
        for (seg in segments) {
            val trimmed = seg.trim()
            if (trimmed.isNotEmpty()) parts.add(trimmed)
        }
        val partial = trailingPartial.trim()
        if (partial.isNotEmpty()) {
            val last = parts.lastOrNull()
            if (last == null || !last.equals(partial, ignoreCase = true)) {
                parts.add(partial)
            }
        }
        return parts.joinToString(" ").replace(Regex("\\s+"), " ").trim()
    }

    private fun buildCombinedHypotheses(): List<String> {
        if (accumulatedSegmentHypotheses.isEmpty()) {
            val single = combineSegments(accumulatedSegments, currentPartialText)
            return if (single.isNotEmpty()) listOf(single) else emptyList()
        }

        // Preserve top combined transcript, plus top-5 alternative variants on the final/most-recent segment
        // so phonetic contact names in the trailing segment retain all ASR alternatives.
        val primaryPrefix = if (accumulatedSegmentHypotheses.size > 1) {
            accumulatedSegmentHypotheses
                .dropLast(1)
                .mapNotNull { it.firstOrNull() }
                .joinToString(" ")
                .trim()
        } else {
            ""
        }

        val lastSegmentAlts = accumulatedSegmentHypotheses.last()
        val combined = LinkedHashSet<String>()
        for (alt in lastSegmentAlts) {
            val full = if (primaryPrefix.isNotEmpty()) "$primaryPrefix $alt" else alt
            val normalized = full.replace(Regex("\\s+"), " ").trim()
            if (normalized.isNotEmpty()) {
                combined.add(normalized)
            }
        }
        // Also include trailing partial if present
        if (currentPartialText.isNotBlank()) {
            combined.add(combineSegments(accumulatedSegments, currentPartialText))
        }
        return combined.take(5).toList()
    }

    private fun isBareWakeWordOnly(text: String): Boolean {
        val lower = text.lowercase().trim().replace(Regex("[^a-z\\s]"), "")
        return lower == "hey vision" ||
            lower == "hi vision" ||
            lower == "hello vision" ||
            lower == "ok vision" ||
            lower == "okay vision" ||
            lower == "vision"
    }

    private fun cancelSessionTimers() {
        cancelEndpointTimer()
        cancelRestartTimer()
        maxDurationRunnable?.let { mainHandler.removeCallbacks(it) }
        maxDurationRunnable = null
        manualStopFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        manualStopFallbackRunnable = null
    }

    private fun cancelEndpointTimer() {
        endpointFinalizeRunnable?.let { mainHandler.removeCallbacks(it) }
        endpointFinalizeRunnable = null
    }

    private fun cancelRestartTimer() {
        restartSegmentRunnable?.let { mainHandler.removeCallbacks(it) }
        restartSegmentRunnable = null
    }

    private fun destroySpeechRecognizer() {
        try {
            speechRecognizer?.destroy()
        } catch (_: Exception) {
        }
        speechRecognizer = null
        segmentHasActiveRecognizer = false
    }

    private fun mapSpeechError(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error."
            SpeechRecognizer.ERROR_CLIENT -> "Speech client error."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                "Microphone permission not granted."
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT ->
                "Network error during speech recognition."
            SpeechRecognizer.ERROR_NO_MATCH ->
                "No speech recognized. Please speak clearly and try again."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
                "Speech recognizer is busy."
            SpeechRecognizer.ERROR_SERVER ->
                "Speech recognition server error."
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                "No speech input detected."
            else -> "Speech recognition error ($error)."
        }
    }

    override fun onWakeWordServiceStateChanged(running: Boolean, micActive: Boolean, error: String?) {
        emitEvent(
            mapOf(
                "type" to "wakeServiceState",
                "isRunning" to running,
                "isMicActive" to micActive,
                if (error != null) "error" to error else "error" to "",
            ),
        )
    }

    override fun onWakeWordTriggered(confidence: Double) {
        emitEvent(
            mapOf(
                "type" to "wakeWordTriggered",
                "confidence" to confidence,
            ),
        )
    }

    private fun emitWakeServiceState() {
        emitEvent(
            mapOf(
                "type" to "wakeServiceState",
                "isRunning" to VisionWakeWordService.isRunning,
                "isMicActive" to VisionWakeWordService.isMicActive,
                "error" to "",
            ),
        )
    }

    private fun emitState() {
        emitEvent(
            mapOf(
                "type" to "state",
                "isListening" to isListening,
                "isSpeaking" to isSpeaking,
                "phase" to currentPhase,
                "segmentCount" to segmentCount,
            ),
        )
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emitState()
        emitWakeServiceState()
        val pending = queuedOverlayPrompt
        val pendingAlts = queuedOverlayHypotheses
        if (!pending.isNullOrBlank()) {
            queuedOverlayPrompt = null
            queuedOverlayHypotheses = emptyList()
            emitEvent(
                mapOf(
                    "type" to "overlayPrompt",
                    "prompt" to pending,
                    "hypotheses" to pendingAlts,
                ),
            )
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        activeSessionId += 1L
        cancelSessionTimers()
        if (VisionWakeWordService.listener === this) {
            VisionWakeWordService.listener = null
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        destroySpeechRecognizer()
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
    }
}
