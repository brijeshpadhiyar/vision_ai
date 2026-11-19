package com.brijesh.vision

import android.app.Notification
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.lang.ref.WeakReference
import java.util.ArrayDeque

/**
 * Local-only NotificationListenerService for VISION AI (Module 15).
 *
 * Notifications are kept strictly in an in-memory bounded ring buffer (max 20)
 * and are only read when the user grants Android Notification Access AND
 * enables explicit consent in VISION Settings. Blocked packages are ignored
 * before buffering. Nothing is ever uploaded automatically.
 */
class VisionNotificationListenerService : NotificationListenerService() {

    data class CapturedNotification(
        val key: String,
        val appName: String,
        val packageName: String,
        val title: String,
        val text: String,
        val postedAtMillis: Long,
        val canReply: Boolean,
        val contentIntent: PendingIntent?,
        val replyAction: Notification.Action?,
    )

    companion object {
        private const val MAX_RECENT = 20
        private val lock = Any()
        private val recentBuffer = ArrayDeque<CapturedNotification>(MAX_RECENT)
        @Volatile
        private var blockedPackages: Set<String> = emptySet()
        @Volatile
        private var activeServiceRef: WeakReference<VisionNotificationListenerService>? = null

        fun setBlockedPackages(packages: Set<String>) {
            blockedPackages = packages.map { it.trim() }.filter { it.isNotEmpty() }.toSet()
            synchronized(lock) {
                val iter = recentBuffer.iterator()
                while (iter.hasNext()) {
                    if (iter.next().packageName in blockedPackages) {
                        iter.remove()
                    }
                }
            }
        }

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
                return recentBuffer
                    .filter { it.packageName !in blockedPackages }
                    .take(limit.coerceIn(1, MAX_RECENT))
                    .map { item ->
                        mapOf(
                            "key" to item.key,
                            "appName" to item.appName,
                            "packageName" to item.packageName,
                            "title" to item.title,
                            "text" to item.text,
                            "postedAtMillis" to item.postedAtMillis,
                            "canReply" to item.canReply,
                        )
                    }
            }
        }

        fun openNotification(key: String): Boolean {
            val entry = synchronized(lock) {
                recentBuffer.firstOrNull { it.key == key }
            } ?: return false
            return try {
                entry.contentIntent?.send()
                entry.contentIntent != null
            } catch (_: Throwable) {
                false
            }
        }

        fun dismissNotification(key: String): Boolean {
            val service = activeServiceRef?.get() ?: return false
            return try {
                service.cancelNotification(key)
                synchronized(lock) {
                    val iter = recentBuffer.iterator()
                    while (iter.hasNext()) {
                        if (iter.next().key == key) {
                            iter.remove()
                            break
                        }
                    }
                }
                true
            } catch (_: Throwable) {
                false
            }
        }

        fun replyNotification(context: Context, key: String, replyText: String): Boolean {
            if (replyText.isBlank()) return false
            val entry = synchronized(lock) {
                recentBuffer.firstOrNull { it.key == key }
            } ?: return false
            val action = entry.replyAction ?: return false
            val remoteInputs = action.remoteInputs ?: return false
            if (remoteInputs.isEmpty()) return false
            return try {
                val fillIn = Intent()
                val bundle = Bundle()
                for (ri in remoteInputs) {
                    bundle.putCharSequence(ri.resultKey, replyText)
                }
                RemoteInput.addResultsToIntent(remoteInputs, fillIn, bundle)
                action.actionIntent.send(context, 0, fillIn)
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        activeServiceRef = WeakReference(this)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (activeServiceRef?.get() === this) {
            activeServiceRef = null
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        activeServiceRef = WeakReference(this)
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg == packageName || pkg in blockedPackages) return

        val notification = sbn.notification ?: return
        if ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) {
            return
        }

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        val replyAction = notification.actions?.firstOrNull { action ->
            action.remoteInputs?.isNotEmpty() == true && action.actionIntent != null
        }

        val appName = resolveAppLabel(pkg)
        val entry = CapturedNotification(
            key = sbn.key ?: "${pkg}_${sbn.postTime}",
            appName = appName,
            packageName = pkg,
            title = title,
            text = text,
            postedAtMillis = sbn.postTime,
            canReply = replyAction != null,
            contentIntent = notification.contentIntent,
            replyAction = replyAction,
        )

        synchronized(lock) {
            val iter = recentBuffer.iterator()
            while (iter.hasNext()) {
                if (iter.next().key == entry.key) {
                    iter.remove()
                    break
                }
            }
            recentBuffer.addFirst(entry)
            while (recentBuffer.size > MAX_RECENT) {
                recentBuffer.removeLast()
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        val removedKey = sbn?.key ?: return
        synchronized(lock) {
            val iter = recentBuffer.iterator()
            while (iter.hasNext()) {
                if (iter.next().key == removedKey) {
                    iter.remove()
                    break
                }
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
