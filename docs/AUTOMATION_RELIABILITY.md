# VISION AI — Mobile Automation Reliability & Lifecycle Architecture

---

## 1. Execution Lifecycle

Every automation command dispatched through `AutomationController` follows a transparent, audited lifecycle:

`Received -> Understood -> Validated -> PermissionRequired / ConfirmationRequired -> Executing -> Success / Failed / Cancelled`

1. **Permission Checks:** Runtime permissions (`CALL_PHONE`, `READ_CONTACTS`) and special access (`BIND_NOTIFICATION_LISTENER_SERVICE`) are checked before invoking restricted content resolvers. Denied permissions return `DeviceActionStatus.permissionRequired` and surface exact Missing Permission prompts instead of crashing.
2. **Safety Confirmation & Input Validation:** Consequential AI tool outputs pass through `DeviceIntentParser.extractAiAction` + `ConfidenceManager.validateRequiredParameters` (strict allowlist + numeric bounds such as `hour in 0..23`, `seconds in 1..86400`), preventing hallucinated or malformed parameters from launching intents.
3. **Truthful Status Reporting:** No action reports `success == true` unless the underlying Android `MethodChannel` call completed cleanly without `PlatformException` or `ActivityNotFoundException`.

---

## 2. Key Reliability Enhancements (Flutter + Kotlin)

### A. Contact Lookup & Ordinal Calling (`VisionAutomationChannel.kt`, `AutomationController`)
- `handleLookupContacts` scores contact matches cleanly (`exact: 100`, `prefix: 85`, `word-start: 75`, `substring: 60`, mild typo Levenshtein `<= 2`: `40`) and preserves all distinct phone numbers for matching contacts.
- Prompts like `"Call the first number of Tisha"` or `"Dial the second number for Tisha"` set `DeviceActionRequest.contactOrdinalIndex`, allowing `AutomationController` to select `matches[index]` deterministically (or report an exact out-of-bounds message if fewer numbers exist).

### B. Alarm & Timer Management (`VisionAutomationChannel.kt`)
- Relative tomorrow/time phrases (`"Set an alarm for seven tomorrow"`, `"Kal savare saat vage alarm muk"`) map cleanly to 24-hour `(hour, minute)` with explicit `(tomorrow)` metadata.
- Relative offset phrases (`"set an alarm in 15 minutes"`) compute `DateTime.now().add(...)` locally.
- Added `dismissAlarm` (`AlarmClock.ACTION_DISMISS_ALARM` -> fallback `ACTION_SHOW_ALARMS`) and `dismissTimer` (`AlarmClock.ACTION_DISMISS_TIMER` -> fallback `ACTION_SHOW_TIMERS`) so Clock UI management opens safely on ColorOS / stock Android.

### C. Fuzzy App Resolution & Missing-App Guidance
- Expanded `APP_ALIASES` across English, Hindi, and Gujarati names (WhatsApp, YouTube, Instagram, Telegram, Spotify, Play Store, Chrome, Camera, Clock, Calendar, Calculator, Maps, Gmail, Files).
- Added compact alphanumeric normalization and Levenshtein edit distance (`<= 2`) fallback in `findBestAppMatch`.
- When an app is not installed, `handleLaunchApp` suggests up to 3 similarly named installed launcher apps in the `APP_NOT_FOUND` error detail.

### D. Multi-Step Sequential Execution
- `CommandNormalizer.splitSequentialClauses` + `IntentEngine.analyze` support sequential workflows (`"Open WhatsApp and find Tisha"`, `"Torch chalu kar aur alarm 6 baje laga"`).
- `AutomationController.executeRequest` executes primary and `followUpActions` in order, collecting `"Step 1: ... | Step 2: ..."` summaries and stopping immediately with explicit step failure attribution (`"Step 2 failed: ..."`) if any stage fails.
