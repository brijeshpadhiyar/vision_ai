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
 * Receives scheduled routine alarms from Android [android.app.AlarmManager]
 * and posts a high-priority tap-to-run notification compliant with Android 14+
 * background activity restrictions (Module 17).
 */
class VisionRoutineAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "vision_scheduled_routines"
        const val EXTRA_ROUTINE_ID = "routine_id"
        const val EXTRA_ROUTINE_NAME = "routine_name"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val routineId = intent.getStringExtra(EXTRA_ROUTINE_ID) ?: return
        val routineName = intent.getStringExtra(EXTRA_ROUTINE_NAME) ?: "Scheduled Routine"

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VISION Scheduled Routines",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts when a scheduled VISION routine is ready to run."
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ROUTINE_ID, routineId)
            putExtra(EXTRA_ROUTINE_NAME, routineName)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            routineId.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("VISION Routine Ready: $routineName")
            .setContentText("Tap to review and run your scheduled routine.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        manager.notify(routineId.hashCode(), notification)
    }
}
