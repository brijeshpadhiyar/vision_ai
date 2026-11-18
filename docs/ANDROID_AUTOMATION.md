# VISION AI — Android Device Automation Guide

## 1. Command Architecture

```text
Voice / Chat Input
   │
   ▼
DeviceIntentParser (Local EN/HI/GU regex OR AI tool call / [[VISION_ACTION:...]])
   │
   ▼
AutomationController (Validation, Contact Disambiguation, Confirmation & Permission Guards)
   │
   ▼
MethodChannel ('com.brijesh.vision/automation')
   │
   ▼
VisionAutomationChannel.kt (Android Intents, ContactsContract, AudioManager, Camera2, NotificationListener)
   │
   ▼
Typed DeviceActionResult (success | failed | permissionRequired | confirmationRequired | notSupported | ambiguousContact | cancelled)
   │
   ▼
Chat Transcript + Spoken TTS Response
```

---

## 2. Implemented Actions & Required Permissions

| Action | Android Mechanism | Permission / Special Access | Behavior |
| :--- | :--- | :--- | :--- |
| **Phone Calls** | `Intent.ACTION_DIAL` (default) / `Intent.ACTION_CALL` | `CALL_PHONE` (for direct call) + `READ_CONTACTS` (for names) | Resolves contacts, disambiguates multiple matches, requires explicit confirmation before direct `ACTION_CALL` |
| **Contacts Lookup** | `ContactsContract.CommonDataKinds.Phone` | `READ_CONTACTS` | Searches by name or digits, returns up to 10 deduplicated entries |
| **Alarms & Timers** | `AlarmClock.ACTION_SET_ALARM`, `ACTION_SET_TIMER` | `com.android.alarm.permission.SET_ALARM` | Supports exact and relative times (`"in 30 minutes"`), opens system clock when UI confirmation is needed, checks `canScheduleExactAlarms` |
| **App Launching** | `PackageManager.queryIntentActivities` + `getLaunchIntentForPackage` | `<queries>` launcher intent in `AndroidManifest.xml` | Exact, prefix, contains, and ColorOS/OPPO app alias matching |
| **System Settings** | `Settings.ACTION_*` | None | Opens Wi-Fi, Bluetooth, Sound, Display, Battery, Location, Apps, Notifications, Storage, Security, Privacy, Accessibility, Notification Access, Battery Optimization, Default Assistant |
| **SMS** | `Intent.ACTION_SENDTO` (`smsto:`) | `READ_CONTACTS` (if contact name) | Opens SMS composer pre-filled; user confirms send |
| **WhatsApp** | `https://wa.me/<digits>?text=...` / `Intent.ACTION_SEND` (`com.whatsapp`) | `<queries>` for `com.whatsapp`, `com.whatsapp.w4b` + `READ_CONTACTS` (if contact name) | User-confirmed composer only; never uses unsupported background accessibility hacks |
| **Notifications** | `VisionNotificationListenerService` (`NotificationListenerService`) | Explicit in-app consent + Android Notification Access (`ACTION_NOTIFICATION_LISTENER_SETTINGS`) | Stores up to 20 recent non-ongoing notifications in memory only; never uploaded without user action |
| **Device Status** | `BatteryManager`, `ConnectivityManager`, `AudioManager`, `RoleManager`, `PowerManager` | `ACCESS_NETWORK_STATE` | Reports battery, charging, network, ringer mode, torch state, ColorOS detection, assistant role, and battery optimization state |
| **Flashlight / Volume / Ringer / Search / Maps** | `CameraManager`, `AudioManager`, `ACTION_WEB_SEARCH`, `geo:0,0?q=` | DND Policy Access (`ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`) for Silent mode | Real-time torch callback sync + safe DND redirect |

---

## 3. Testing Steps

1. Run **Device Control Hub** from Home or Settings (`/automation`).
2. Tap **Grant** on `Contacts (READ_CONTACTS)` and `Phone Calls (CALL_PHONE)`.
3. Test contact lookup (`"find contact Mom"`), disambiguation, dialer/direct call confirmation, alarm (`"set alarm for 6:30 AM"`), timer (`"set timer for 5 minutes"`), app launch (`"open Camera"`), WhatsApp (`"whatsapp Rahul saying Hello"`), and settings shortcuts (`"open Wi-Fi settings"`).
4. To test Notification Reader: enable **Local Notification Reader Consent** in Settings, grant Notification Access in Android Settings, wait for a new notification, then ask `"read my recent notifications"`.
