package com.brijesh.vision

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.ArrayDeque

/**
 * Local-only NotificationListenerService for VISION AI.
 *
 * Notifications are kept strictly in an in-memory bounded ring buffer (max 20)
 * and are only read when the user grants Android Notification Access AND
 * enables explicit consent in VISION Settings. Nothing is ever uploaded automatically.
 */
class VisionNotificationListenerService : NotificationListenerService() {

    data class CapturedNotification(
        val appName: String,
        val packageName: String,
        val title: String,
        val text: String,
        val postedAtMillis: Long,
    )

    companion object {
        private const val MAX_RECENT = 20
        private val lock = Any()
        private val recentBuffer = ArrayDeque<CapturedNotification>(MAX_RECENT)

        fun isNotificationAccessEnabled(context: Context): Boolean {
            val enabledListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val expected = ComponentName(
                context,
                VisionNotificationListenerService::class.java,
            ).flattenToString()
            return enabledListeners.split(':').any { it.equals(expected, ignoreCase = true) }
        }

        fun getRecentNotifications(limit: Int = 10): List<Map<String, Any>> {
            synchronized(lock) {
                return recentBuffer.take(limit.coerceIn(1, MAX_RECENT)).map { item ->
                    mapOf(
                        "appName" to item.appName,
                        "packageName" to item.packageName,
                        "title" to item.title,
                        "text" to item.text,
                        "postedAtMillis" to item.postedAtMillis,
                    )
                }
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return

        val notification = sbn.notification ?: return
        if ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) {
            return
        }

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        val appName = resolveAppLabel(pkg)
        val entry = CapturedNotification(
            appName = appName,
            packageName = pkg,
            title = title,
            text = text,
            postedAtMillis = sbn.postTime,
        )

        synchronized(lock) {
            recentBuffer.addFirst(entry)
            while (recentBuffer.size > MAX_RECENT) {
                recentBuffer.removeLast()
            }
        }
    }

    private fun resolveAppLabel(pkg: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(0))
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Throwable) {
            pkg
        }
    }
}
