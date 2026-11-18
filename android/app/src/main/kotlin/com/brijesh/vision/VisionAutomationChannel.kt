package com.brijesh.vision

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.SearchManager
import android.app.role.RoleManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.AlarmClock
import android.provider.ContactsContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android device automation channel for permission-guarded phone calling,
 * contact lookup, alarm/timer scheduling, app launching, system settings intents,
 * torch control, and contextual device status on Android / ColorOS.
 */
class VisionAutomationChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val METHOD_CHANNEL_NAME = "com.brijesh.vision/automation"
        const val REQUEST_CALL_PHONE_PERMISSION = 4001
        const val REQUEST_READ_CONTACTS_PERMISSION = 4002

        private val APP_ALIASES = mapOf(
            "camera" to listOf("camera", "cam"),
            "settings" to listOf("settings", "setting"),
            "clock" to listOf("clock", "alarm", "timer"),
            "phone" to listOf("phone", "dialer", "contacts"),
            "messages" to listOf("messages", "messaging", "sms"),
            "photos" to listOf("photos", "gallery", "album"),
            "calculator" to listOf("calculator", "calc"),
            "calendar" to listOf("calendar"),
            "chrome" to listOf("chrome", "browser", "google chrome"),
            "whatsapp" to listOf("whatsapp", "whatsapp business", "wa"),
            "youtube" to listOf("youtube", "yt"),
            "gmail" to listOf("gmail", "mail", "email"),
            "maps" to listOf("maps", "google maps"),
            "files" to listOf("files", "file manager", "my files"),
            "notes" to listOf("notes", "keep notes"),
            "instagram" to listOf("instagram", "insta"),
            "telegram" to listOf("telegram"),
            "spotify" to listOf("spotify"),
            "play store" to listOf("play store", "google play", "playstore"),
        )
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRequestCode: Int? = null
    private var isFlashlightOn: Boolean = false
    private val cameraManager: CameraManager? =
        activity.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
            isFlashlightOn = enabled
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        try {
            cameraManager?.registerTorchCallback(
                torchCallback,
                Handler(Looper.getMainLooper()),
            )
        } catch (_: Exception) {
            // Ignore on devices without Camera2 torch callback support.
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                val permissionKey = call.argument<String>("permission") ?: ""
                if (permissionKey == "notifications") {
                    result.success(VisionNotificationListenerService.isNotificationAccessEnabled(activity))
                    return
                }
                val androidPermission = mapPermissionKey(permissionKey)
                if (androidPermission == null) {
                    result.error("INVALID_PERMISSION", "Unknown permission: $permissionKey", null)
                } else {
                    result.success(hasPermission(androidPermission))
                }
            }

            "requestPermission" -> {
                val permissionKey = call.argument<String>("permission") ?: ""
                if (permissionKey == "notifications") {
                    if (VisionNotificationListenerService.isNotificationAccessEnabled(activity)) {
                        result.success(true)
                        return
                    }
                    try {
                        val notifIntent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        activity.startActivity(notifIntent)
                        result.success(false)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", "Unable to open Notification Access settings: ${e.message}", null)
                    }
                    return
                }
                val androidPermission = mapPermissionKey(permissionKey)
                val requestCode = mapPermissionRequestCode(permissionKey)
                if (androidPermission == null || requestCode == null) {
                    result.error("INVALID_PERMISSION", "Unknown permission: $permissionKey", null)
                    return
                }
                if (hasPermission(androidPermission)) {
                    result.success(true)
                    return
                }
                if (pendingPermissionResult != null) {
                    result.error(
                        "PERMISSION_BUSY",
                        "Another permission request is already in progress.",
                        null,
                    )
                    return
                }
                pendingPermissionResult = result
                pendingRequestCode = requestCode
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(androidPermission),
                    requestCode,
                )
            }

            "lookupContacts" -> {
                val query = call.argument<String>("query")?.trim() ?: ""
                handleLookupContacts(query, result)
            }

            "makePhoneCall" -> {
                val phoneNumber = call.argument<String>("phoneNumber")?.trim() ?: ""
                val directCall = call.argument<Boolean>("directCall") ?: false
                handleMakePhoneCall(phoneNumber, directCall, result)
            }

            "setAlarm" -> {
                val hour = call.argument<Int>("hour")
                val minute = call.argument<Int>("minute")
                val label = call.argument<String>("label")?.trim()
                val skipUi = call.argument<Boolean>("skipUi") ?: false
                handleSetAlarm(hour, minute, label, skipUi, result)
            }

            "setTimer" -> {
                val seconds = call.argument<Int>("seconds")
                val label = call.argument<String>("label")?.trim()
                val skipUi = call.argument<Boolean>("skipUi") ?: false
                handleSetTimer(seconds, label, skipUi, result)
            }

            "dismissAlarm" -> {
                handleDismissAlarm(result)
            }

            "dismissTimer" -> {
                handleDismissTimer(result)
            }

            "getInstalledApps" -> {
                result.success(queryLauncherApps().map { app ->
                    mapOf(
                        "appName" to app.appName,
                        "packageName" to app.packageName,
                    )
                })
            }

            "launchApp" -> {
                val query = call.argument<String>("query")?.trim() ?: ""
                handleLaunchApp(query, result)
            }

            "openSystemSettings" -> {
                val section = call.argument<String>("section")?.trim() ?: "main"
                handleOpenSystemSettings(section, result)
            }

            "sendSms" -> {
                val phoneNumber = call.argument<String>("phoneNumber")?.trim() ?: ""
                val message = call.argument<String>("message")?.trim()
                handleSendSms(phoneNumber, message, result)
            }

            "sendWhatsApp" -> {
                val phoneNumber = call.argument<String>("phoneNumber")?.trim()
                val message = call.argument<String>("message")?.trim()
                handleSendWhatsApp(phoneNumber, message, result)
            }

            "getRecentNotifications" -> {
                val limit = call.argument<Int>("limit") ?: 10
                handleGetRecentNotifications(limit, result)
            }

            "isNetworkConnected" -> {
                result.success(isNetworkConnected())
            }

            "openUrl" -> {
                val url = call.argument<String>("url")?.trim() ?: ""
                handleOpenUrl(url, result)
            }

            "setFlashlight" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                handleSetFlashlight(enabled, result)
            }

            "setRingerMode" -> {
                val mode = call.argument<String>("mode")?.trim()?.lowercase() ?: "normal"
                handleSetRingerMode(mode, result)
            }

            "adjustVolume" -> {
                val direction = call.argument<String>("direction")?.trim()?.lowercase() ?: "up"
                handleAdjustVolume(direction, result)
            }

            "webSearch" -> {
                val query = call.argument<String>("query")?.trim() ?: ""
                handleWebSearch(query, result)
            }

            "navigateTo" -> {
                val destination = call.argument<String>("destination")?.trim() ?: ""
                handleNavigateTo(destination, result)
            }

            "getDeviceStatus" -> {
                result.success(readDeviceStatus())
            }

            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != pendingRequestCode) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        pendingRequestCode = null
        return true
    }

    private fun mapPermissionKey(key: String): String? {
        return when (key) {
            "call_phone" -> Manifest.permission.CALL_PHONE
            "read_contacts" -> Manifest.permission.READ_CONTACTS
            else -> null
        }
    }

    private fun mapPermissionRequestCode(key: String): Int? {
        return when (key) {
            "call_phone" -> REQUEST_CALL_PHONE_PERMISSION
            "read_contacts" -> REQUEST_READ_CONTACTS_PERMISSION
            else -> null
        }
    }

    private fun hasPermission(androidPermission: String): Boolean {
        return ContextCompat.checkSelfPermission(
            activity,
            androidPermission,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun handleLookupContacts(query: String, result: MethodChannel.Result) {
        if (!hasPermission(Manifest.permission.READ_CONTACTS)) {
            result.error(
                "PERMISSION_DENIED",
                "Contacts permission is required to search contacts.",
                "read_contacts",
            )
            return
        }
        if (query.isBlank()) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        val scoredMatches = mutableListOf<Pair<Int, Map<String, String>>>()
        val seenNumbers = HashSet<String>()
        val normalizedQuery = query.lowercase().trim()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.TYPE,
            ContactsContract.CommonDataKinds.Phone.LABEL,
        )

        try {
            activity.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
            )?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                )
                val numberIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                )
                val typeIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.TYPE,
                )
                val labelIndex = cursor.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.LABEL,
                )

                while (cursor.moveToNext()) {
                    val name = if (nameIndex >= 0) cursor.getString(nameIndex)?.trim() ?: "" else ""
                    val rawNumber = if (numberIndex >= 0) cursor.getString(numberIndex)?.trim() ?: "" else ""
                    if (name.isEmpty() || rawNumber.isEmpty()) continue

                    val lowerName = name.lowercase()
                    val cleanDigits = rawNumber.replace(Regex("[^0-9+]"), "")

                    val score = when {
                        lowerName == normalizedQuery || cleanDigits == normalizedQuery -> 100
                        lowerName.startsWith(normalizedQuery) -> 85
                        lowerName.split(' ').any { it.startsWith(normalizedQuery) } -> 75
                        lowerName.contains(normalizedQuery) || cleanDigits.contains(normalizedQuery) -> 60
                        normalizedQuery.length >= 4 &&
                            lowerName.split(' ').any { token ->
                                token.length >= 3 && editDistance(token, normalizedQuery) <= 2
                            } -> 40
                        else -> 0
                    }
                    if (score == 0) continue

                    if (!seenNumbers.add("$name:$cleanDigits")) continue

                    val phoneType = if (typeIndex >= 0) cursor.getInt(typeIndex) else 0
                    val customLabel = if (labelIndex >= 0) cursor.getString(labelIndex) else null
                    val label = ContactsContract.CommonDataKinds.Phone.getTypeLabel(
                        activity.resources,
                        phoneType,
                        customLabel,
                    ).toString()

                    scoredMatches.add(
                        score to mapOf(
                            "name" to name,
                            "phoneNumber" to rawNumber,
                            "label" to label,
                        ),
                    )
                }
            }
            val matches = scoredMatches
                .sortedByDescending { it.first }
                .take(10)
                .map { it.second }
            result.success(matches)
        } catch (e: SecurityException) {
            result.error(
                "PERMISSION_DENIED",
                "Contacts permission was revoked: ${e.message}",
                "read_contacts",
            )
        } catch (e: Exception) {
            result.error(
                "CONTACTS_ERROR",
                "Unable to query contacts: ${e.message}",
                null,
            )
        }
    }

    private fun handleMakePhoneCall(
        phoneNumber: String,
        directCall: Boolean,
        result: MethodChannel.Result,
    ) {
        val sanitized = phoneNumber.replace(Regex("[^0-9+*#-]"), "")
        if (sanitized.isBlank() || !sanitized.any { it.isDigit() }) {
            result.error("INVALID_NUMBER", "Please provide a valid phone number.", null)
            return
        }

        val canCallDirectly = directCall && hasPermission(Manifest.permission.CALL_PHONE)
        val action = if (canCallDirectly) Intent.ACTION_CALL else Intent.ACTION_DIAL
        val intent = Intent(action, Uri.parse("tel:$sanitized")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            activity.startActivity(intent)
            result.success(
                mapOf(
                    "success" to true,
                    "mode" to if (canCallDirectly) "direct_call" else "dialer",
                    "phoneNumber" to sanitized,
                ),
            )
        } catch (e: ActivityNotFoundException) {
            result.error("ACTIVITY_NOT_FOUND", "No phone dialer app found on this device.", null)
        } catch (e: SecurityException) {
            // Fallback to dialer if OEM restricts direct call.
            try {
                val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$sanitized")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(dialIntent)
                result.success(
                    mapOf(
                        "success" to true,
                        "mode" to "dialer",
                        "phoneNumber" to sanitized,
                    ),
                )
            } catch (fallbackError: Exception) {
                result.error("CALL_ERROR", "Unable to open dialer: ${fallbackError.message}", null)
            }
        }
    }

    private fun handleSetAlarm(
        hour: Int?,
        minute: Int?,
        label: String?,
        skipUi: Boolean,
        result: MethodChannel.Result,
    ) {
        if (hour == null || minute == null || hour !in 0..23 || minute !in 0..59) {
            result.error("INVALID_TIME", "Alarm hour (0-23) and minute (0-59) are required.", null)
            return
        }

        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
            if (!label.isNullOrBlank()) {
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            activity.startActivity(intent)
            result.success(
                mapOf(
                    "success" to true,
                    "hour" to hour,
                    "minute" to minute,
                    "label" to (label ?: ""),
                ),
            )
        } catch (e: ActivityNotFoundException) {
            result.error("ACTIVITY_NOT_FOUND", "No clock app available to set alarms.", null)
        } catch (e: Exception) {
            result.error("ALARM_ERROR", "Failed to schedule alarm: ${e.message}", null)
        }
    }

    private fun handleSetTimer(
        seconds: Int?,
        label: String?,
        skipUi: Boolean,
        result: MethodChannel.Result,
    ) {
        if (seconds == null || seconds <= 0) {
            result.error("INVALID_DURATION", "Timer duration must be greater than 0 seconds.", null)
            return
        }

        val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
            putExtra(AlarmClock.EXTRA_LENGTH, seconds)
            putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
            if (!label.isNullOrBlank()) {
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            activity.startActivity(intent)
            result.success(
                mapOf(
                    "success" to true,
                    "seconds" to seconds,
                    "label" to (label ?: ""),
                ),
            )
        } catch (e: ActivityNotFoundException) {
            result.error("ACTIVITY_NOT_FOUND", "No clock app available to start timers.", null)
        } catch (e: Exception) {
            result.error("TIMER_ERROR", "Failed to start timer: ${e.message}", null)
        }
    }

    private fun handleDismissAlarm(result: MethodChannel.Result) {
        val action = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            AlarmClock.ACTION_DISMISS_ALARM
        } else {
            AlarmClock.ACTION_SHOW_ALARMS
        }
        val intent = Intent(action).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(intent)
            result.success(mapOf("success" to true, "action" to action))
        } catch (_: ActivityNotFoundException) {
            try {
                val fallback = Intent(AlarmClock.ACTION_SHOW_ALARMS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(fallback)
                result.success(mapOf("success" to true, "action" to AlarmClock.ACTION_SHOW_ALARMS))
            } catch (e: ActivityNotFoundException) {
                result.error("ACTIVITY_NOT_FOUND", "No clock app available to manage alarms.", null)
            }
        }
    }

    private fun handleDismissTimer(result: MethodChannel.Result) {
        val primaryAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AlarmClock.ACTION_DISMISS_TIMER
        } else {
            AlarmClock.ACTION_SHOW_ALARMS
        }
        val intent = Intent(primaryAction).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(intent)
            result.success(mapOf("success" to true, "action" to primaryAction))
        } catch (_: ActivityNotFoundException) {
            try {
                val showTimers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    AlarmClock.ACTION_SHOW_TIMERS
                } else {
                    AlarmClock.ACTION_SHOW_ALARMS
                }
                val fallback = Intent(showTimers).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(fallback)
                result.success(mapOf("success" to true, "action" to showTimers))
            } catch (_: ActivityNotFoundException) {
                result.error("ACTIVITY_NOT_FOUND", "No clock app available to manage timers.", null)
            }
        }
    }

    private data class LauncherApp(
        val appName: String,
        val packageName: String,
    )

    private fun queryLauncherApps(): List<LauncherApp> {
        val pm = activity.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolved: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, 0)
        }

        val seenPackages = HashSet<String>()
        val apps = mutableListOf<LauncherApp>()
        for (info in resolved) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == activity.packageName || !seenPackages.add(pkg)) continue
            val label = info.loadLabel(pm)?.toString()?.trim()
            if (!label.isNullOrEmpty()) {
                apps.add(LauncherApp(appName = label, packageName = pkg))
            }
        }
        return apps.sortedBy { it.appName.lowercase() }
    }

    private fun handleLaunchApp(query: String, result: MethodChannel.Result) {
        if (query.isBlank()) {
            result.error("INVALID_APP", "Please specify an app name or package to launch.", null)
            return
        }

        val pm = activity.packageManager
        val directIntent = pm.getLaunchIntentForPackage(query)
        if (directIntent != null) {
            directIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(directIntent)
            result.success(
                mapOf(
                    "success" to true,
                    "appName" to query,
                    "packageName" to query,
                ),
            )
            return
        }

        val normalizedQuery = query.lowercase().trim()
        val apps = queryLauncherApps()
        val matched = findBestAppMatch(normalizedQuery, apps)
        if (matched == null) {
            val suggestions = apps
                .map { it to editDistance(normalizedQuery, it.appName.lowercase()) }
                .filter { it.second <= 4 }
                .sortedBy { it.second }
                .take(3)
                .map { it.first.appName }
            val hint = if (suggestions.isNotEmpty()) {
                " Similar apps: ${suggestions.joinToString(", ")}."
            } else {
                ""
            }
            result.error(
                "APP_NOT_FOUND",
                "Could not find an installed app matching \"$query\".$hint",
                null,
            )
            return
        }

        val launchIntent = pm.getLaunchIntentForPackage(matched.packageName)
        if (launchIntent == null) {
            result.error(
                "LAUNCH_ERROR",
                "\"${matched.appName}\" cannot be launched directly.",
                null,
            )
            return
        }

        try {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(launchIntent)
            result.success(
                mapOf(
                    "success" to true,
                    "appName" to matched.appName,
                    "packageName" to matched.packageName,
                ),
            )
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", "Failed to launch ${matched.appName}: ${e.message}", null)
        }
    }

    private fun findBestAppMatch(query: String, apps: List<LauncherApp>): LauncherApp? {
        // 1. Exact label match
        apps.firstOrNull { it.appName.lowercase() == query }?.let { return it }

        // 2. Prefix label match
        apps.firstOrNull { it.appName.lowercase().startsWith(query) }?.let { return it }

        // 3. Contains label match
        apps.firstOrNull { it.appName.lowercase().contains(query) }?.let { return it }

        // 4. Common OPPO/ColorOS/Android aliases
        val aliasCandidates = APP_ALIASES.entries
            .firstOrNull { (_, aliases) -> aliases.any { it == query || query.contains(it) } }
            ?.value ?: emptyList()

        for (alias in aliasCandidates) {
            apps.firstOrNull {
                val lower = it.appName.lowercase()
                lower == alias || lower.contains(alias) || it.packageName.lowercase().contains(alias)
            }?.let { return it }
        }

        // 5. Fuzzy edit-distance match for minor speech-to-text typos
        if (query.length >= 4) {
            val compactQuery = query.replace(Regex("[^a-z0-9]"), "")
            val fuzzyMatch = apps
                .map { app ->
                    val compactApp = app.appName.lowercase().replace(Regex("[^a-z0-9]"), "")
                    app to editDistance(compactQuery, compactApp)
                }
                .filter { it.second <= 2 }
                .minByOrNull { it.second }
                ?.first
            if (fuzzyMatch != null) return fuzzyMatch
        }

        // 6. Package name contains query
        return apps.firstOrNull { it.packageName.lowercase().contains(query) }
    }

    private fun editDistance(a: String, b: String): Int {
        if (a == b) return 0
        if (a.isEmpty()) return b.length
        if (b.isEmpty()) return a.length
        val prev = IntArray(b.length + 1) { it }
        val curr = IntArray(b.length + 1)
        for (i in a.indices) {
            curr[0] = i + 1
            for (j in b.indices) {
                val cost = if (a[i] == b[j]) 0 else 1
                curr[j + 1] = minOf(
                    curr[j] + 1,
                    prev[j + 1] + 1,
                    prev[j] + cost,
                )
            }
            curr.copyInto(prev)
        }
        return prev[b.length]
    }

    private fun handleOpenSystemSettings(section: String, result: MethodChannel.Result) {
        val action = when (section.lowercase()) {
            "wifi", "wi-fi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "sound", "volume", "audio" -> Settings.ACTION_SOUND_SETTINGS
            "display", "brightness" -> Settings.ACTION_DISPLAY_SETTINGS
            "battery" -> Intent.ACTION_POWER_USAGE_SUMMARY
            "location", "gps" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
            "apps", "applications" -> Settings.ACTION_APPLICATION_SETTINGS
            "app_details", "permissions" -> Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            "notifications", "notification" -> Settings.ACTION_APP_NOTIFICATION_SETTINGS
            "storage", "memory" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
            "security" -> Settings.ACTION_SECURITY_SETTINGS
            "privacy" -> Settings.ACTION_PRIVACY_SETTINGS
            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
            "network", "internet", "mobile_data" -> Settings.ACTION_WIRELESS_SETTINGS
            "date", "time" -> Settings.ACTION_DATE_SETTINGS
            "notification_listener" -> Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            "default_assistant", "assistant" -> Settings.ACTION_VOICE_INPUT_SETTINGS
            "battery_optimization" -> Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
            "exact_alarm" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
            } else {
                Settings.ACTION_DATE_SETTINGS
            }
            else -> Settings.ACTION_SETTINGS
        }

        val intent = if (action == Settings.ACTION_APPLICATION_DETAILS_SETTINGS ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && action == Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
        ) {
            Intent(action, Uri.fromParts("package", activity.packageName, null))
        } else if (action == Settings.ACTION_APP_NOTIFICATION_SETTINGS) {
            Intent(action).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
        } else {
            Intent(action)
        }.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            activity.startActivity(intent)
            result.success(mapOf("success" to true, "section" to section))
        } catch (e: ActivityNotFoundException) {
            // Fallback to general system settings on OEMs where a sub-intent is missing.
            try {
                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(fallback)
                result.success(mapOf("success" to true, "section" to "main"))
            } catch (fallbackError: Exception) {
                result.error(
                    "SETTINGS_ERROR",
                    "Unable to open device settings: ${fallbackError.message}",
                    null,
                )
            }
        }
    }

    private fun handleSendSms(
        phoneNumber: String,
        message: String?,
        result: MethodChannel.Result,
    ) {
        val sanitized = phoneNumber.replace(Regex("[^0-9+*#-]"), "")
        if (sanitized.isBlank() || !sanitized.any { it.isDigit() }) {
            result.error("INVALID_NUMBER", "Please provide a valid recipient phone number.", null)
            return
        }

        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$sanitized")).apply {
            if (!message.isNullOrBlank()) {
                putExtra("sms_body", message)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            activity.startActivity(intent)
            result.success(mapOf("success" to true, "phoneNumber" to sanitized))
        } catch (e: ActivityNotFoundException) {
            result.error("ACTIVITY_NOT_FOUND", "No SMS messaging app found on this device.", null)
        }
    }

    private fun handleSendWhatsApp(
        phoneNumber: String?,
        message: String?,
        result: MethodChannel.Result,
    ) {
        val pm = activity.packageManager
        val hasWhatsApp = listOf("com.whatsapp", "com.whatsapp.w4b").any { pkg ->
            pm.getLaunchIntentForPackage(pkg) != null
        }
        if (!hasWhatsApp) {
            result.error("APP_NOT_FOUND", "WhatsApp is not installed on this device.", null)
            return
        }

        val targetPkg = if (pm.getLaunchIntentForPackage("com.whatsapp") != null) {
            "com.whatsapp"
        } else {
            "com.whatsapp.w4b"
        }

        val cleanDigits = phoneNumber?.replace(Regex("[^0-9]"), "") ?: ""
        val intent = if (cleanDigits.isNotEmpty()) {
            val encodedMsg = if (!message.isNullOrBlank()) "?text=${Uri.encode(message)}" else ""
            Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$cleanDigits$encodedMsg")).apply {
                setPackage(targetPkg)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        } else {
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                setPackage(targetPkg)
                if (!message.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_TEXT, message)
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }

        try {
            activity.startActivity(intent)
            result.success(
                mapOf(
                    "success" to true,
                    "packageName" to targetPkg,
                ),
            )
        } catch (e: ActivityNotFoundException) {
            result.error("APP_NOT_FOUND", "Unable to open WhatsApp composer.", null)
        }
    }

    private fun handleGetRecentNotifications(limit: Int, result: MethodChannel.Result) {
        if (!VisionNotificationListenerService.isNotificationAccessEnabled(activity)) {
            result.error(
                "PERMISSION_DENIED",
                "Notification Listener access is not enabled for VISION.",
                "notifications",
            )
            return
        }
        result.success(VisionNotificationListenerService.getRecentNotifications(limit))
    }

    private fun handleOpenUrl(url: String, result: MethodChannel.Result) {
        val normalized = if (url.startsWith("http://") || url.startsWith("https://")) {
            url
        } else if (url.contains('.')) {
            "https://$url"
        } else {
            ""
        }

        val parsed = Uri.parse(normalized)
        if (normalized.isBlank() || (parsed.scheme != "https" && parsed.scheme != "http")) {
            result.error("INVALID_URL", "Only http/https web URLs can be opened.", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW, parsed).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(intent)
            result.success(mapOf("success" to true, "url" to normalized))
        } catch (e: ActivityNotFoundException) {
            result.error("ACTIVITY_NOT_FOUND", "No browser app found to open URL.", null)
        }
    }

    private fun handleSetFlashlight(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val cm = cameraManager
            if (cm == null) {
                result.error("FLASHLIGHT_UNAVAILABLE", "Camera service is unavailable.", null)
                return
            }

            var torchCameraId: String? = null
            for (id in cm.cameraIdList) {
                val chars = cm.getCameraCharacteristics(id)
                val hasFlash = chars.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                val lensFacing = chars.get(CameraCharacteristics.LENS_FACING)
                if (hasFlash && lensFacing == CameraCharacteristics.LENS_FACING_BACK) {
                    torchCameraId = id
                    break
                } else if (hasFlash && torchCameraId == null) {
                    torchCameraId = id
                }
            }

            if (torchCameraId == null) {
                result.error("FLASHLIGHT_UNAVAILABLE", "No camera flash unit found.", null)
                return
            }

            cm.setTorchMode(torchCameraId, enabled)
            isFlashlightOn = enabled
            result.success(mapOf("success" to true, "enabled" to enabled))
        } catch (e: Exception) {
            result.error("FLASHLIGHT_ERROR", "Unable to control flashlight: ${e.message}", null)
        }
    }

    private fun handleSetRingerMode(mode: String, result: MethodChannel.Result) {
        val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            result.error("AUDIO_UNAVAILABLE", "Audio service is unavailable.", null)
            return
        }

        val targetMode = when (mode) {
            "silent" -> AudioManager.RINGER_MODE_SILENT
            "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
            "normal", "ring" -> AudioManager.RINGER_MODE_NORMAL
            else -> {
                result.error("INVALID_RINGER_MODE", "Unknown ringer mode: $mode", null)
                return
            }
        }

        if (targetMode == AudioManager.RINGER_MODE_SILENT &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
        ) {
            val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (nm != null && !nm.isNotificationPolicyAccessGranted) {
                try {
                    val dndIntent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    activity.startActivity(dndIntent)
                    result.error(
                        "DND_ACCESS_REQUIRED",
                        "Do Not Disturb policy access is required to set Silent mode. Opened settings.",
                        null,
                    )
                } catch (_: Exception) {
                    result.error(
                        "DND_ACCESS_REQUIRED",
                        "Do Not Disturb policy access is required to enable Silent mode.",
                        null,
                    )
                }
                return
            }
        }

        try {
            audioManager.ringerMode = targetMode
            val normalizedMode = when (audioManager.ringerMode) {
                AudioManager.RINGER_MODE_SILENT -> "silent"
                AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                else -> "normal"
            }
            result.success(mapOf("success" to true, "mode" to normalizedMode))
        } catch (e: SecurityException) {
            result.error("RINGER_ERROR", "Unable to change ringer mode: ${e.message}", null)
        }
    }

    private fun handleAdjustVolume(direction: String, result: MethodChannel.Result) {
        val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager == null) {
            result.error("AUDIO_UNAVAILABLE", "Audio service is unavailable.", null)
            return
        }

        val adjustFlag = when (direction) {
            "up", "raise", "increase" -> AudioManager.ADJUST_RAISE
            "down", "lower", "decrease" -> AudioManager.ADJUST_LOWER
            "mute" -> AudioManager.ADJUST_MUTE
            "unmute" -> AudioManager.ADJUST_UNMUTE
            else -> {
                result.error("INVALID_VOLUME_ACTION", "Unknown volume direction: $direction", null)
                return
            }
        }

        try {
            audioManager.adjustStreamVolume(
                AudioManager.STREAM_MUSIC,
                adjustFlag,
                AudioManager.FLAG_SHOW_UI,
            )
            val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            result.success(
                mapOf(
                    "success" to true,
                    "direction" to direction,
                    "currentVolume" to current,
                    "maxVolume" to max,
                ),
            )
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", "Unable to adjust volume: ${e.message}", null)
        }
    }

    private fun handleWebSearch(query: String, result: MethodChannel.Result) {
        if (query.isBlank()) {
            result.error("INVALID_QUERY", "Please provide a search query.", null)
            return
        }

        val searchIntent = Intent(Intent.ACTION_WEB_SEARCH).apply {
            putExtra(SearchManager.QUERY, query)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(searchIntent)
            result.success(mapOf("success" to true, "query" to query))
        } catch (_: ActivityNotFoundException) {
            val encoded = Uri.encode(query)
            val browserIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://www.google.com/search?q=$encoded"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                activity.startActivity(browserIntent)
                result.success(mapOf("success" to true, "query" to query))
            } catch (e: ActivityNotFoundException) {
                result.error("ACTIVITY_NOT_FOUND", "No search or browser app found.", null)
            }
        }
    }

    private fun handleNavigateTo(destination: String, result: MethodChannel.Result) {
        if (destination.isBlank()) {
            result.error("INVALID_DESTINATION", "Please provide a destination to navigate to.", null)
            return
        }

        val encoded = Uri.encode(destination)
        val geoIntent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=$encoded")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            activity.startActivity(geoIntent)
            result.success(mapOf("success" to true, "destination" to destination))
        } catch (_: ActivityNotFoundException) {
            val mapsFallback = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://www.google.com/maps/search/?api=1&query=$encoded"),
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                activity.startActivity(mapsFallback)
                result.success(mapOf("success" to true, "destination" to destination))
            } catch (_: ActivityNotFoundException) {
                result.error("ACTIVITY_NOT_FOUND", "No maps or browser app found for navigation.", null)
            }
        }
    }

    private fun readDeviceStatus(): Map<String, Any> {
        val batteryManager =
            activity.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val batteryLevel =
            batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        val isCharging = batteryManager?.isCharging ?: false

        val connectivityManager =
            activity.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val networkType = resolveNetworkType(connectivityManager)

        val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val ringerMode = when (audioManager?.ringerMode) {
            AudioManager.RINGER_MODE_SILENT -> "silent"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "normal"
        }

        val manufacturer = Build.MANUFACTURER ?: "Android"
        val model = Build.MODEL ?: "Device"
        val isColorOs = manufacturer.equals("OPPO", ignoreCase = true) ||
            manufacturer.equals("OnePlus", ignoreCase = true) ||
            manufacturer.equals("realme", ignoreCase = true)

        val isDefaultAssistant = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = activity.getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_ASSISTANT) == true
        } else {
            false
        }

        val powerManager = activity.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isIgnoringBattery = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager?.isIgnoringBatteryOptimizations(activity.packageName) == true
        } else {
            true
        }

        val alarmManager = activity.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val canScheduleExactAlarms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager?.canScheduleExactAlarms() == true
        } else {
            true
        }

        return mapOf(
            "manufacturer" to manufacturer,
            "model" to model,
            "androidVersion" to (Build.VERSION.RELEASE ?: ""),
            "sdkInt" to Build.VERSION.SDK_INT,
            "batteryLevel" to batteryLevel,
            "isCharging" to isCharging,
            "networkType" to networkType,
            "ringerMode" to ringerMode,
            "isColorOs" to isColorOs,
            "isFlashlightOn" to isFlashlightOn,
            "isDefaultAssistant" to isDefaultAssistant,
            "isIgnoringBatteryOptimizations" to isIgnoringBattery,
            "canScheduleExactAlarms" to canScheduleExactAlarms,
        )
    }

    private fun isNetworkConnected(): Boolean {
        val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val activeNetwork = cm.activeNetwork ?: return false
        val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR))
    }

    private fun resolveNetworkType(cm: ConnectivityManager?): String {
        if (cm == null) return "Unknown"
        val activeNetwork = cm.activeNetwork ?: return "Offline"
        val capabilities = cm.getNetworkCapabilities(activeNetwork) ?: return "Offline"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            else -> "Connected"
        }
    }

    fun dispose() {
        try {
            cameraManager?.unregisterTorchCallback(torchCallback)
        } catch (_: Exception) {
            // Ignore unregister errors during teardown.
        }
        methodChannel.setMethodCallHandler(null)
        pendingPermissionResult = null
        pendingRequestCode = null
    }
}
