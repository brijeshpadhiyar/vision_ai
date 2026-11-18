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
 * Native Android voice engine bridging SpeechRecognizer (STT), TextToSpeech (TTS),
 * offline foreground wake-word standby ([VisionWakeWordService]), and Assistant Role
 * integration for English (en-IN), Hindi (hi-IN), and Gujarati (gu-IN).
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
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRoleResult: MethodChannel.Result? = null
    private var queuedOverlayPrompt: String? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false
    private var isListening = false
    private var isSpeaking = false

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        VisionWakeWordService.listener = this
        initializeTts()
    }

    fun queueOverlayPrompt(prompt: String) {
        queuedOverlayPrompt = prompt
        emitEvent(
            mapOf(
                "type" to "overlayPrompt",
                "prompt" to prompt,
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
                        emitState()
                    }

                    override fun onDone(utteranceId: String?) {
                        isSpeaking = false
                        emitState()
                        resumeWakeServiceIfRunning()
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        isSpeaking = false
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
                startSpeechListening(localeTag)
                result.success(true)
            }
            "stopListening" -> {
                stopSpeechListening()
                result.success(true)
            }
            "cancelListening" -> {
                cancelSpeechListening()
                result.success(true)
            }
            "speak" -> {
                val text = call.argument<String>("text") ?: ""
                val localeTag = call.argument<String>("locale") ?: "en-IN"
                val rate = call.argument<Double>("speechRate") ?: 1.0
                val spoke = speakText(text, localeTag, rate.toFloat())
                result.success(spoke)
            }
            "stopSpeaking" -> {
                textToSpeech?.stop()
                isSpeaking = false
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
                result.success(prompt)
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

    private fun startSpeechListening(localeTag: String) {
        pauseWakeServiceIfRunning()

        if (isSpeaking) {
            textToSpeech?.stop()
            isSpeaking = false
        }

        if (speechRecognizer == null) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity).apply {
                setRecognitionListener(createRecognitionListener())
            }
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1800L)
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                1400L,
            )
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1200L)
        }

        isListening = true
        emitState()
        speechRecognizer?.startListening(intent)
    }

    private fun stopSpeechListening() {
        speechRecognizer?.stopListening()
        isListening = false
        emitState()
        resumeWakeServiceIfRunning()
    }

    private fun cancelSpeechListening() {
        speechRecognizer?.cancel()
        isListening = false
        emitState()
        resumeWakeServiceIfRunning()
    }

    private fun speakText(text: String, localeTag: String, speechRate: Float): Boolean {
        val tts = textToSpeech
        if (!isTtsReady || tts == null || text.isBlank()) {
            return false
        }

        // Prevent wake-word AudioRecord contention while TTS speaks aloud.
        pauseWakeServiceIfRunning()

        val locale = Locale.forLanguageTag(localeTag)
        val availability = tts.isLanguageAvailable(locale)
        if (availability >= TextToSpeech.LANG_AVAILABLE) {
            tts.language = locale
        } else {
            tts.language = Locale.US
        }

        tts.setSpeechRate(speechRate)
        val utteranceId = "vision_tts_${System.currentTimeMillis()}"
        isSpeaking = true
        emitState()
        val status = tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        if (status == TextToSpeech.ERROR) {
            isSpeaking = false
            emitState()
            resumeWakeServiceIfRunning()
            return false
        }
        return true
    }

    private fun createRecognitionListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                isListening = true
                emitState()
            }

            override fun onBeginningOfSpeech() {}

            override fun onRmsChanged(rmsdB: Float) {
                val clamped = min(10.0f, max(0.0f, rmsdB + 2.0f))
                val normalized = (clamped / 10.0f).toDouble()
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
                isListening = false
                emitState()
            }

            override fun onError(error: Int) {
                isListening = false
                emitState()
                resumeWakeServiceIfRunning()
                val errorMessage = mapSpeechError(error)
                emitEvent(
                    mapOf(
                        "type" to "error",
                        "code" to "STT_ERROR_$error",
                        "message" to errorMessage,
                    ),
                )
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                emitState()
                resumeWakeServiceIfRunning()
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val transcript = matches?.firstOrNull()?.trim() ?: ""
                if (transcript.isNotEmpty()) {
                    emitEvent(
                        mapOf(
                            "type" to "transcript",
                            "text" to transcript,
                            "isFinal" to true,
                        ),
                    )
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches =
                    partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val transcript = matches?.firstOrNull()?.trim() ?: ""
                if (transcript.isNotEmpty()) {
                    emitEvent(
                        mapOf(
                            "type" to "transcript",
                            "text" to transcript,
                            "isFinal" to false,
                        ),
                    )
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
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

    private fun emitState() {
        emitEvent(
            mapOf(
                "type" to "state",
                "isListening" to isListening,
                "isSpeaking" to isSpeaking,
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
        emitEvent(
            mapOf(
                "type" to "wakeServiceState",
                "isRunning" to VisionWakeWordService.isRunning,
                "isMicActive" to VisionWakeWordService.isMicActive,
                "error" to "",
            ),
        )
        val pending = queuedOverlayPrompt
        if (!pending.isNullOrBlank()) {
            queuedOverlayPrompt = null
            emitEvent(
                mapOf(
                    "type" to "overlayPrompt",
                    "prompt" to pending,
                ),
            )
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        if (VisionWakeWordService.listener === this) {
            VisionWakeWordService.listener = null
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        speechRecognizer?.destroy()
        speechRecognizer = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
    }
}
