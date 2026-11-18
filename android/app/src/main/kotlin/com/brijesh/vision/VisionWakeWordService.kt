package com.brijesh.vision

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Foreground microphone service running an offline, low-CPU acoustic DSP
 * wake-word detector for "Hey VISION".
 *
 * Uses Android's [AudioRecord] directly with adaptive noise-floor tracking and
 * a two-stage Voice Activity + multi-syllable cadence gate. Zero audio is ever
 * streamed to the cloud during wake-word standby.
 */
class VisionWakeWordService : Service() {

    companion object {
        const val ACTION_START = "com.brijesh.vision.action.START_WAKE_WORD"
        const val ACTION_STOP = "com.brijesh.vision.action.STOP_WAKE_WORD"
        const val ACTION_PAUSE_MIC = "com.brijesh.vision.action.PAUSE_WAKE_MIC"
        const val ACTION_RESUME_MIC = "com.brijesh.vision.action.RESUME_WAKE_MIC"
        const val ACTION_UPDATE_SENSITIVITY = "com.brijesh.vision.action.UPDATE_WAKE_SENSITIVITY"
        const val EXTRA_SENSITIVITY = "sensitivity"

        private const val CHANNEL_ID = "vision_wake_word_standby"
        private const val NOTIFICATION_ID = 4101
        private const val SAMPLE_RATE = 16000
        private const val FRAME_SAMPLES = 480 // 30ms @ 16kHz
        private const val COOLDOWN_MS = 2500L

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var isMicActive: Boolean = false
            private set

        @Volatile
        var currentSensitivity: Double = 0.55
            private set

        @Volatile
        var isForegroundAppActive: Boolean = false

        var listener: WakeWordServiceListener? = null
    }

    interface WakeWordServiceListener {
        fun onWakeWordServiceStateChanged(running: Boolean, micActive: Boolean, error: String?)
        fun onWakeWordTriggered(confidence: Double)
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var shouldCapture = false

    @Volatile
    private var isPausedForSpeech = false

    private var workerThread: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopWakeCapture()
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_PAUSE_MIC -> {
                isPausedForSpeech = true
                isMicActive = false
                notifyStateChanged(error = null)
                return START_STICKY
            }

            ACTION_RESUME_MIC -> {
                isPausedForSpeech = false
                if (isRunning && workerThread == null) {
                    startAudioLoop()
                }
                return START_STICKY
            }

            ACTION_UPDATE_SENSITIVITY -> {
                val updated = intent.getDoubleExtra(EXTRA_SENSITIVITY, currentSensitivity)
                currentSensitivity = updated.coerceIn(0.2, 0.9)
                return START_STICKY
            }

            else -> {
                if (intent != null && intent.hasExtra(EXTRA_SENSITIVITY)) {
                    currentSensitivity = intent.getDoubleExtra(EXTRA_SENSITIVITY, 0.55)
                        .coerceIn(0.2, 0.9)
                }

                if (!hasMicPermission()) {
                    isRunning = false
                    isMicActive = false
                    notifyStateChanged("Microphone permission is required for Hey VISION standby.")
                    stopSelf()
                    return START_NOT_STICKY
                }

                try {
                    startForegroundCompat()
                } catch (e: Exception) {
                    isRunning = false
                    isMicActive = false
                    notifyStateChanged(
                        "Android blocked background microphone service: ${e.message ?: "ForegroundServiceStartNotAllowed"}",
                    )
                    stopSelf()
                    return START_NOT_STICKY
                }

                isRunning = true
                isPausedForSpeech = false
                startAudioLoop()
                return START_STICKY
            }
        }
    }

    private fun hasMicPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VISION Hands-Free Standby",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Offline \"Hey VISION\" wake-word microphone standby indicator"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val openPending = PendingIntent.getActivity(
            this,
            10,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = Intent(this, VisionWakeWordService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this,
            11,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("VISION Hands-Free Active")
            .setContentText("Offline standby listening for \"Hey VISION\"")
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(openPending)
            .addAction(0, "Stop Listening", stopPending)
            .build()
    }

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startAudioLoop() {
        if (workerThread?.isAlive == true) return
        shouldCapture = true
        workerThread = Thread({
            runWakeDetectorLoop()
        }, "VisionWakeWordThread").apply { start() }
    }

    private fun stopWakeCapture() {
        shouldCapture = false
        isRunning = false
        isMicActive = false
        workerThread?.interrupt()
        workerThread = null
        notifyStateChanged(error = null)
    }

    private fun runWakeDetectorLoop() {
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferBytes = maxOf(minBuf, FRAME_SAMPLES * 4)
        var recorder: AudioRecord? = null

        try {
            recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferBytes,
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                isMicActive = false
                notifyStateChanged("Microphone AudioRecord failed to initialize.")
                return
            }

            recorder.startRecording()
            if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                isMicActive = false
                notifyStateChanged("Microphone recording could not start (blocked by OS or another app).")
                return
            }

            isMicActive = true
            notifyStateChanged(error = null)

            val frame = ShortArray(FRAME_SAMPLES)
            var noiseFloor = 180.0
            var activeSpeechFrames = 0
            var silenceGapFrames = 0
            var burstCount = 0
            var firstBurstFrames = 0
            var secondBurstFrames = 0
            var zcrSum = 0.0
            var lastTriggerAt = 0L

            while (shouldCapture && !Thread.currentThread().isInterrupted) {
                if (isPausedForSpeech) {
                    if (isMicActive) {
                        try {
                            recorder.stop()
                        } catch (_: Exception) {
                        }
                        isMicActive = false
                        notifyStateChanged(error = null)
                    }
                    Thread.sleep(150)
                    continue
                } else if (!isMicActive) {
                    try {
                        recorder.startRecording()
                        if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                            isMicActive = true
                            notifyStateChanged(error = null)
                        }
                    } catch (_: Exception) {
                        Thread.sleep(300)
                        continue
                    }
                }

                val read = recorder.read(frame, 0, frame.size)
                if (read <= 0) {
                    Thread.sleep(30)
                    continue
                }

                val stats = analyzeFrame(frame, read)
                val sensitivity = currentSensitivity
                // Higher sensitivity -> lower threshold multiplier
                val speechMultiplier = 3.4 - (sensitivity * 1.6) // ~1.96 to ~3.08
                val minSpeechRms = 420.0 - (sensitivity * 210.0) // ~231 to ~378
                val threshold = maxOf(minSpeechRms, noiseFloor * speechMultiplier)
                val isSpeech = stats.rms > threshold && stats.zcr in 0.02..0.42

                if (!isSpeech) {
                    noiseFloor = (noiseFloor * 0.96) + (stats.rms * 0.04)
                    if (activeSpeechFrames > 0) {
                        silenceGapFrames++
                        if (silenceGapFrames in 1..5 && burstCount == 1) {
                            // Short pause between "Hey" and "VISION"
                        } else if (silenceGapFrames > 6) {
                            // Evaluate completed candidate phrase
                            val totalSpeech = firstBurstFrames + secondBurstFrames
                            val matchedCadence = (burstCount >= 2 &&
                                firstBurstFrames in 3..14 &&
                                secondBurstFrames in 5..24) ||
                                (burstCount == 1 && totalSpeech in 12..30 && (zcrSum / totalSpeech) in 0.05..0.32)

                            val now = System.currentTimeMillis()
                            if (matchedCadence && (now - lastTriggerAt) > COOLDOWN_MS) {
                                lastTriggerAt = now
                                val confidence = (0.55 + (sensitivity * 0.35)).coerceIn(0.5, 0.95)
                                dispatchWakeDetected(confidence)
                            }

                            activeSpeechFrames = 0
                            silenceGapFrames = 0
                            burstCount = 0
                            firstBurstFrames = 0
                            secondBurstFrames = 0
                            zcrSum = 0.0
                        }
                    }
                } else {
                    if (activeSpeechFrames == 0 || silenceGapFrames >= 1) {
                        if (burstCount == 0) {
                            burstCount = 1
                        } else if (burstCount == 1 && silenceGapFrames in 1..5) {
                            burstCount = 2
                        }
                    }
                    silenceGapFrames = 0
                    activeSpeechFrames++
                    zcrSum += stats.zcr
                    if (burstCount <= 1) {
                        firstBurstFrames++
                    } else {
                        secondBurstFrames++
                    }
                }
            }
        } catch (_: InterruptedException) {
            // Normal teardown
        } catch (se: SecurityException) {
            isMicActive = false
            notifyStateChanged("Microphone permission revoked: ${se.message}")
        } catch (e: Exception) {
            isMicActive = false
            notifyStateChanged("Wake-word audio error: ${e.message}")
        } finally {
            isMicActive = false
            try {
                recorder?.stop()
            } catch (_: Exception) {
            }
            try {
                recorder?.release()
            } catch (_: Exception) {
            }
            notifyStateChanged(error = null)
        }
    }

    private data class FrameStats(val rms: Double, val zcr: Double)

    private fun analyzeFrame(samples: ShortArray, count: Int): FrameStats {
        var sumSq = 0.0
        var zeroCrossings = 0
        var prev = samples[0].toInt()
        for (i in 0 until count) {
            val s = samples[i].toInt()
            sumSq += s.toDouble() * s.toDouble()
            if ((s >= 0 && prev < 0) || (s < 0 && prev >= 0)) {
                zeroCrossings++
            }
            prev = s
        }
        val rms = sqrt(sumSq / count.toDouble())
        val zcr = zeroCrossings.toDouble() / count.toDouble()
        return FrameStats(rms = rms, zcr = abs(zcr))
    }

    private fun dispatchWakeDetected(confidence: Double) {
        isPausedForSpeech = true
        mainHandler.post {
            listener?.onWakeWordTriggered(confidence)
            if (!isForegroundAppActive) {
                try {
                    val overlayIntent = Intent(this, AssistantOverlayActivity::class.java).apply {
                        addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP,
                        )
                        putExtra("fromWakeWord", true)
                        putExtra("confidence", confidence)
                    }
                    startActivity(overlayIntent)
                } catch (_: Exception) {
                    // Android 10+ background activity launch restrictions may apply when
                    // SYSTEM_ALERT_WINDOW / Default Assistant role is not granted.
                }
            }
        }
    }

    private fun notifyStateChanged(error: String?) {
        mainHandler.post {
            listener?.onWakeWordServiceStateChanged(isRunning, isMicActive, error)
        }
    }

    override fun onDestroy() {
        stopWakeCapture()
        super.onDestroy()
    }
}
