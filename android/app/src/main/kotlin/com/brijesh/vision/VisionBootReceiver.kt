package com.brijesh.vision

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Handles post-reboot & app-update service recovery on Android 14+ / OPPO ColorOS (Module 04).
 *
 * Android 14+ restricts starting `FOREGROUND_SERVICE_MICROPHONE` directly from
 * `BOOT_COMPLETED`. When the user previously enabled background wake-word standby,
 * this receiver posts a lightweight tap-to-rearm notification.
 */
class VisionBootReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "vision_boot_recovery"
        private const val NOTIFICATION_ID = 4109
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_WAKE_BG = "flutter.vision_pref_wake_word_background"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val wakeBgEnabled = prefs.getBoolean(KEY_WAKE_BG, false)
        if (!wakeBgEnabled) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VISION Standby Recovery",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Prompts to re-arm Hey VISION after device reboot."
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Re-arm Hey VISION Standby")
            .setContentText("Device restarted. Tap to resume background wake-word listening.")
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
    }
}
