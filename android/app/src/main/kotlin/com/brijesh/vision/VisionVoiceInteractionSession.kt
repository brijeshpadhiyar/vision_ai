package com.brijesh.vision

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
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
import java.util.Locale

/**
 * Gemini-style system assistant overlay rendered via Android's
 * [VoiceInteractionSession] directly over the user's current screen.
 */
class VisionVoiceInteractionSession(context: Context) : VoiceInteractionSession(context) {

    private var statusView: TextView? = null
    private var transcriptView: TextView? = null
    private var responseView: TextView? = null
    private var micButton: Button? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var textToSpeech: TextToSpeech? = null
    private var isTtsReady = false
    private var isListening = false

    override fun onCreate() {
        super.onCreate()
        textToSpeech = TextToSpeech(context.applicationContext) { status ->
            isTtsReady = (status == TextToSpeech.SUCCESS)
        }
    }

    override fun onCreateContentView(): View {
        val view = LayoutInflater.from(context).inflate(R.layout.vision_assistant_overlay, null)
        statusView = view.findViewById(R.id.vision_overlay_status)
        transcriptView = view.findViewById(R.id.vision_overlay_transcript)
        responseView = view.findViewById(R.id.vision_overlay_response)
        micButton = view.findViewById(R.id.vision_overlay_mic_btn)

        val openAppBtn: Button = view.findViewById(R.id.vision_overlay_open_app_btn)
        val dismissBtn: Button = view.findViewById(R.id.vision_overlay_dismiss_btn)

        micButton?.setOnClickListener {
            if (isListening) {
                stopListening()
            } else {
                startListening()
            }
        }

        openAppBtn.setOnClickListener {
            openFullVisionAssistant(prompt = null)
        }

        dismissBtn.setOnClickListener {
            hide()
        }

        return view
    }

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        statusView?.text = "Ready"
        responseView?.text = ""
        if (hasMicPermission()) {
            startListening()
        } else {
            transcriptView?.text = "Microphone permission is needed for voice input."
            statusView?.text = "Permission Needed"
        }
    }

    private fun hasMicPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun startListening() {
        if (!hasMicPermission()) {
            openFullVisionAssistant(prompt = null)
            return
        }

        if (speechRecognizer == null) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(createListener())
            }
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }

        isListening = true
        statusView?.text = "Listening..."
        micButton?.text = "Stop"
        transcriptView?.text = "Listening for your request..."
        speechRecognizer?.startListening(intent)
    }

    private fun stopListening() {
        speechRecognizer?.stopListening()
        isListening = false
        statusView?.text = "Ready"
        micButton?.text = "Speak"
    }

    private fun openFullVisionAssistant(prompt: String?) {
        val intent = Intent(context, AssistantOverlayActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (!prompt.isNullOrBlank()) {
                putExtra("initialPrompt", prompt)
            }
        }
        try {
            startAssistantActivity(intent)
        } catch (_: Exception) {
            context.startActivity(intent)
        }
        hide()
    }

    private fun createListener(): RecognitionListener {
        return object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                statusView?.text = "Listening..."
            }

            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                isListening = false
                statusView?.text = "Processing..."
                micButton?.text = "Speak"
            }

            override fun onError(error: Int) {
                isListening = false
                statusView?.text = "Tap Speak"
                micButton?.text = "Speak"
                responseView?.text = "Could not hear clearly. Tap Speak or Open VISION."
            }

            override fun onResults(results: Bundle?) {
                isListening = false
                micButton?.text = "Speak"
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val transcript = matches?.firstOrNull()?.trim() ?: ""
                if (transcript.isNotEmpty()) {
                    transcriptView?.text = transcript
                    statusView?.text = "Handing off..."
                    openFullVisionAssistant(transcript)
                } else {
                    statusView?.text = "Ready"
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val text = matches?.firstOrNull()?.trim() ?: ""
                if (text.isNotEmpty()) {
                    transcriptView?.text = text
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }
    }

    override fun onHide() {
        speechRecognizer?.cancel()
        textToSpeech?.stop()
        isListening = false
        super.onHide()
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
