import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';

/// Filter category for the Interactive Help & User Guide Hub (v1.3 Wave 1).
enum HelpCategory {
  all('All', Icons.apps_rounded),
  gettingStarted('Getting Started', Icons.rocket_launch_outlined),
  voice('Voice & Language', Icons.mic_none_rounded),
  aiVision('AI, Camera & Web', Icons.auto_awesome_outlined),
  automation('Automation', Icons.bolt_outlined),
  privacy('Privacy & Device', Icons.shield_outlined),
  planner('Daily Planner', Icons.checklist_rounded);

  const HelpCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Action target triggered from a Help topic or Settings search result.
enum HelpActionTarget {
  openSettingsAi,
  openSettingsVoice,
  openSettingsSystem,
  openChat,
  openVoiceAssistant,
  openAutomation,
  openPrivacyDashboard,
  openPlanner,
  openSmartHome,
  openDeveloper,
  openDiagnostics,
  openOnboarding,
}

extension HelpActionTargetRoute on HelpActionTarget {
  String get routePath => switch (this) {
    HelpActionTarget.openSettingsAi ||
    HelpActionTarget.openSettingsVoice ||
    HelpActionTarget.openSettingsSystem => AppRoutes.settingsPath,
    HelpActionTarget.openChat => AppRoutes.chatPath,
    HelpActionTarget.openVoiceAssistant => AppRoutes.assistantPath,
    HelpActionTarget.openAutomation => AppRoutes.automationPath,
    HelpActionTarget.openPrivacyDashboard => AppRoutes.privacyDashboardPath,
    HelpActionTarget.openPlanner => AppRoutes.plannerPath,
    HelpActionTarget.openSmartHome => AppRoutes.smartHomePath,
    HelpActionTarget.openDeveloper => AppRoutes.developerPath,
    HelpActionTarget.openDiagnostics => AppRoutes.diagnosticsPath,
    HelpActionTarget.openOnboarding => AppRoutes.onboardingPath,
  };
}

/// Complete step-by-step user guide topic covering a VISION AI capability.
@immutable
class HelpGuideTopic {
  const HelpGuideTopic({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.steps,
    required this.actionLabel,
    required this.actionTarget,
    this.exampleCommands = const <String>[],
    this.keywords = const <String>[],
  });

  final String id;
  final HelpCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> steps;
  final String actionLabel;
  final HelpActionTarget actionTarget;
  final List<String> exampleCommands;
  final List<String> keywords;

  bool matchesQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = <String>[
      title,
      subtitle,
      category.label,
      ...steps,
      ...exampleCommands,
      ...keywords,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(haystack.contains);
  }
}

/// Searchable quick-jump entry shown in both Settings Search and Help Search.
@immutable
class SettingSearchEntry {
  const SettingSearchEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sectionLabel,
    required this.icon,
    required this.target,
    required this.keywords,
  });

  final String id;
  final String title;
  final String subtitle;
  final String sectionLabel;
  final IconData icon;
  final HelpActionTarget target;
  final List<String> keywords;

  bool matchesQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = <String>[
      title,
      subtitle,
      sectionLabel,
      ...keywords,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(haystack.contains);
  }
}

/// Centralized, searchable catalog of every VISION AI feature and setting.
abstract final class HelpGuideCatalog {
  static const List<HelpGuideTopic> topics = <HelpGuideTopic>[
    HelpGuideTopic(
      id: 'ai_providers_keys',
      category: HelpCategory.gettingStarted,
      title: 'AI Providers, API Keys & On-Device Edge AI',
      subtitle: 'Configure Gemini, OpenAI, Claude, or offline Gemini Nano',
      icon: Icons.hub_outlined,
      steps: <String>[
        'Open Settings → AI Providers to choose your default provider manually.',
        'Tap "Configure API Key" on Gemini, OpenAI, or Claude — keys are encrypted in Android Keystore and never logged.',
        'Tap "Test Connection" to verify your key and discover live models.',
        'Select "On-Device Edge AI (Gemini Nano)" for private offline inference with zero API key on AICore-supported devices.',
        'Track your local request and token counts under "Local Usage Counters".',
      ],
      actionLabel: 'Open AI Settings',
      actionTarget: HelpActionTarget.openSettingsAi,
      keywords: <String>[
        'gemini',
        'openai',
        'claude',
        'edge ai',
        'nano',
        'api key',
        'model',
        'fallback',
        'usage',
        'tokens',
      ],
    ),
    HelpGuideTopic(
      id: 'assistant_identity',
      category: HelpCategory.gettingStarted,
      title: 'Assistant Identity & Custom Behaviour',
      subtitle: 'Customize personality, tone, greeting, and custom rules',
      icon: Icons.auto_awesome_outlined,
      steps: <String>[
        'Go to Settings → Assistant Identity.',
        'Pick a Personality Preset (Balanced, Professional, Friendly, or Concise).',
        'Choose a Communication Style (Conversational, Direct & Brief, or Detailed).',
        'Set a Custom Home Greeting and optional Custom Behaviour Instructions injected into every AI prompt.',
      ],
      actionLabel: 'Customize Identity',
      actionTarget: HelpActionTarget.openSettingsAi,
      keywords: <String>[
        'identity',
        'personality',
        'greeting',
        'style',
        'instructions',
        'prompt',
      ],
    ),
    HelpGuideTopic(
      id: 'voice_and_multilingual',
      category: HelpCategory.voice,
      title: 'Voice Identity & Multilingual Auto Mode',
      subtitle: 'English, Hindi, Gujarati, Auto detection & native TTS voices',
      icon: Icons.record_voice_over_outlined,
      steps: <String>[
        'Open Settings → Voice & Language.',
        'Choose Auto (EN / HI / GU) to detect your language automatically and switch Android TTS voices per reply, or lock to English, Hindi, or Gujarati.',
        'Adjust Speech Rate (0.5x–2.0x), Voice Pitch, and Speech Pause Tolerance.',
        'Tap "Native Android TTS Voice" to pick from installed offline/online voices and tap "Preview Voice" to test.',
      ],
      actionLabel: 'Open Voice Settings',
      actionTarget: HelpActionTarget.openSettingsVoice,
      exampleCommands: <String>[
        'नमस्ते VISION, आज का समय क्या है?',
        'નમસ્તે VISION, ફ્લેશલાઇટ ચાલુ કરો',
        'Stop speaking',
      ],
      keywords: <String>[
        'voice',
        'tts',
        'stt',
        'speech',
        'rate',
        'pitch',
        'hindi',
        'gujarati',
        'english',
        'auto',
        'language',
      ],
    ),
    HelpGuideTopic(
      id: 'activation_wakeword',
      category: HelpCategory.voice,
      title: 'Hey VISION Wake-Word, Widget & Assistant Role',
      subtitle: 'Hands-free activation, lock screen & OEM battery setup',
      icon: Icons.hearing_rounded,
      steps: <String>[
        'Enable "Hey VISION" standby in Settings → Wake Word and tune sensitivity.',
        'Tap "Default Digital Assistant (ROLE_ASSISTANT)" in Settings → Permissions so power/corner gestures launch VISION.',
        'Add the VISION AI Home-Screen Widget from your launcher for one-tap voice overlay.',
        'Open your device-tailored Setup Guide in Settings → Permissions to allow unrestricted background battery.',
        'After restarting your Android 14+ phone, tap the "Re-arm Hey VISION" notification to resume background mic standby.',
      ],
      actionLabel: 'Open Voice & Permissions',
      actionTarget: HelpActionTarget.openSettingsVoice,
      keywords: <String>[
        'wake word',
        'hey vision',
        'widget',
        'lock screen',
        'reboot',
        'battery',
        'assistant role',
        'background',
      ],
    ),
    HelpGuideTopic(
      id: 'camera_visual_ocr',
      category: HelpCategory.aiVision,
      title: 'Camera, Gallery & Offline ML Kit OCR',
      subtitle: 'Analyze photos with multimodal AI or extract text offline',
      icon: Icons.photo_camera_outlined,
      steps: <String>[
        'Open Chat and tap the Camera icon to snap a photo or Gallery icon to pick an image.',
        'Tap "Read Text (OCR)" on the staged photo preview to extract text 100% offline with Google ML Kit (zero cloud upload).',
        'Or type/speak a question and tap Send to analyze the photo with Gemini, OpenAI, or Claude.',
        'If your phone is offline when you send a photo, VISION automatically runs Offline ML Kit OCR.',
        'Photo bytes stay in memory for the current session only and are never written to local history.',
      ],
      actionLabel: 'Open Chat Camera',
      actionTarget: HelpActionTarget.openChat,
      exampleCommands: <String>[
        'Explain what is in this photo',
        'Summarize the key points from this document',
      ],
      keywords: <String>[
        'camera',
        'photo',
        'gallery',
        'image',
        'ocr',
        'ml kit',
        'scan',
        'visual',
        'multimodal',
      ],
    ),
    HelpGuideTopic(
      id: 'internet_research',
      category: HelpCategory.aiVision,
      title: 'Internet Research & Clickable Citations',
      subtitle: 'Live multi-source web answers with zero extra API key',
      icon: Icons.public_rounded,
      steps: <String>[
        'In Chat, tap the "Web" toggle chip to ground your next question with live web sources.',
        'Or start any voice/text prompt with "research ...", "search the web for ...", or "latest news about ...".',
        'VISION fetches deduplicated DuckDuckGo & Wikipedia sources and synthesizes an answer with [1], [2] citations.',
        'Tap any citation chip below the reply to open the source URL directly.',
        'Tip: Tap the Toolkit icon in the Chat top bar to try the optional Flutter AI Toolkit view.',
      ],
      actionLabel: 'Try Web Research',
      actionTarget: HelpActionTarget.openChat,
      exampleCommands: <String>[
        'Research latest Flutter release highlights',
        'Latest news about Android AI features',
      ],
      keywords: <String>[
        'web',
        'research',
        'internet',
        'search',
        'citations',
        'sources',
        'toolkit',
        'news',
      ],
    ),
    HelpGuideTopic(
      id: 'automation_calls_messaging',
      category: HelpCategory.automation,
      title: 'Phone Calls, Contacts, SMS, WhatsApp & Apps',
      subtitle: 'Hands-free Android device control & phonetic contact matching',
      icon: Icons.phonelink_setup_rounded,
      steps: <String>[
        'Grant Contacts permission in Settings → Permissions so VISION can match names (including phonetic & Indic spellings).',
        'Speak or type commands for alarms, timers, flashlight, volume, Wi-Fi/Bluetooth/Display settings, or launching any installed app.',
        'For calls, SMS, and WhatsApp, VISION resolves ambiguous contacts and asks for confirmation before sensitive actions.',
        'Safe device commands work even offline in Airplane Mode.',
      ],
      actionLabel: 'Open Device Control Hub',
      actionTarget: HelpActionTarget.openAutomation,
      exampleCommands: <String>[
        'Set an alarm for 7 AM',
        'Turn on flashlight',
        'Open YouTube',
        'WhatsApp Mom saying I am on my way',
      ],
      keywords: <String>[
        'call',
        'contacts',
        'sms',
        'whatsapp',
        'alarm',
        'timer',
        'flashlight',
        'app',
        'wifi',
        'bluetooth',
        'offline',
      ],
    ),
    HelpGuideTopic(
      id: 'trusted_commands_routines',
      category: HelpCategory.automation,
      title: 'Trusted Commands, Routines & Schedules',
      subtitle: 'Chain multi-step commands and manage command trust tiers',
      icon: Icons.verified_user_outlined,
      steps: <String>[
        'Open Device Control Hub → Trusted Routines and tap "Add" to chain multiple commands (one per line).',
        'Assign voice trigger phrases (e.g., "bedtime") and an optional daily schedule time.',
        'Safe commands run immediately; sensitive commands (calls, SMS, WhatsApp, URLs, notifications) require confirmation unless explicitly trusted.',
        'Review or revoke any trusted command anytime in Settings → Trusted Commands or the Privacy Dashboard.',
      ],
      actionLabel: 'Manage Routines',
      actionTarget: HelpActionTarget.openAutomation,
      exampleCommands: <String>[
        'Turn off flashlight and set alarm for 7 AM',
        'Run Good Night',
      ],
      keywords: <String>[
        'routine',
        'schedule',
        'multi-step',
        'trusted',
        'revoke',
        'confirmation',
        'history',
      ],
    ),
    HelpGuideTopic(
      id: 'privacy_security_dashboard',
      category: HelpCategory.privacy,
      title: 'Privacy & Security Dashboard, Memory & Notifications',
      subtitle: 'Unified control over permissions, blocklist & local data',
      icon: Icons.shield_outlined,
      steps: <String>[
        'Open Settings → Privacy → Privacy & Security Dashboard.',
        'Inspect Android Keystore encryption, Secret Redaction, and active runtime permissions in one view.',
        'Keep "Save Conversation History" and "Personalization Memory" OFF for strict session-only privacy, or opt in anytime.',
        'Add banking or OTP app package names to the Notification Privacy Blocklist so VISION never reads them.',
        'Use "Clear All Local Activity Data" to wipe transcripts, execution logs, and usage counters while preserving your API keys.',
      ],
      actionLabel: 'Open Privacy Dashboard',
      actionTarget: HelpActionTarget.openPrivacyDashboard,
      keywords: <String>[
        'privacy',
        'security',
        'dashboard',
        'memory',
        'history',
        'notifications',
        'blocklist',
        'keystore',
        'clear data',
      ],
    ),
    HelpGuideTopic(
      id: 'daily_planner_briefing',
      category: HelpCategory.planner,
      title: 'Daily Planner & Spoken Voice Briefing',
      subtitle: 'Manage tasks, reminders & hear your daily briefing aloud',
      icon: Icons.checklist_rounded,
      steps: <String>[
        'Open Daily Planner from Home Quick Actions or Help.',
        'Tap "Add Task" to create a task with priority (Low / Normal / High) and an optional reminder time.',
        'Tap "Speak Briefing" to have VISION read your date, device status, pending tasks, and routine count aloud.',
        'Check off completed tasks or clear completed items with one tap.',
      ],
      actionLabel: 'Open Daily Planner',
      actionTarget: HelpActionTarget.openPlanner,
      keywords: <String>[
        'planner',
        'daily',
        'task',
        'todo',
        'reminder',
        'briefing',
        'schedule',
      ],
    ),
    HelpGuideTopic(
      id: 'external_app_integrations',
      category: HelpCategory.automation,
      title:
          'External App Integrations (Maps, YouTube, Spotify, Calendar, Email)',
      subtitle: 'Launch navigation, media searches, calendar events & email drafts by voice',
      icon: Icons.open_in_new_rounded,
      steps: <String>[
        'Say or type "Navigate to <place>" to launch turn-by-turn Google Maps navigation.',
        'Say "Play <song/topic> on YouTube" or "Play <artist> on Spotify" to open direct app search (with browser fallback).',
        'Say "Schedule meeting <title>" or "Add calendar event <title>" to open the native Calendar composer.',
        'Say "Compose email to <address> subject <subject>" to open your default mail app prefilled.',
      ],
      actionLabel: 'Try in Chat',
      actionTarget: HelpActionTarget.openChat,
      exampleCommands: <String>[
        'Navigate to Ahmedabad Airport',
        'Play lo-fi beats on YouTube',
        'Schedule meeting Project Review',
      ],
      keywords: <String>[
        'maps',
        'youtube',
        'spotify',
        'calendar',
        'email',
        'gmail',
        'navigation',
        'external apps',
      ],
    ),
    HelpGuideTopic(
      id: 'smart_home_hub',
      category: HelpCategory.automation,
      title: 'Smart Home Hub (Home Assistant & Webhooks)',
      subtitle: 'Control local Wi-Fi lights, switches & scenes hands-free',
      icon: Icons.home_outlined,
      steps: <String>[
        'Open Smart Home from Home Quick Actions or Settings Search.',
        'Optional: Enter your local Home Assistant URL and Long-Lived Access Token (encrypted in Android Keystore).',
        'Tap "Add Device" to register a Home Assistant entity (e.g., light.living_room) or a local HTTP webhook (Tasmota, ESPHome, Shelly).',
        'Toggle devices in the Hub or say "Turn on Living Room Light" / "Turn off Bedroom Fan" in Chat or Voice.',
      ],
      actionLabel: 'Open Smart Home',
      actionTarget: HelpActionTarget.openSmartHome,
      exampleCommands: <String>[
        'Turn on Living Room Light',
        'Turn off Bedroom Fan',
      ],
      keywords: <String>[
        'smart home',
        'home assistant',
        'webhook',
        'light',
        'switch',
        'scene',
        'iot',
      ],
    ),
    HelpGuideTopic(
      id: 'proactive_intelligence',
      category: HelpCategory.gettingStarted,
      title: 'Proactive Intelligence & Smart Home Nudges',
      subtitle:
          'On-device contextual cards for briefings, battery & setup readiness',
      icon: Icons.tips_and_updates_outlined,
      steps: <String>[
        'VISION evaluates your local time of day, Daily Planner tasks, and setup status 100% on-device.',
        'Actionable cards appear on Home for morning/evening briefings, pending priorities, or setup reminders.',
        'Tap the action button on any card (e.g., Speak Briefing) or tap × to dismiss it for the session.',
      ],
      actionLabel: 'Open Daily Planner',
      actionTarget: HelpActionTarget.openPlanner,
      keywords: <String>[
        'proactive',
        'suggestions',
        'smart cards',
        'briefing',
        'nudges',
      ],
    ),
    HelpGuideTopic(
      id: 'developer_assistant_studio',
      category: HelpCategory.aiVision,
      title: 'Developer Assistant Studio (AI Prompts, Tools & Snippets)',
      subtitle: 'Coding prompt templates, offline JSON/JWT/Base64/Regex tools & snippet vault',
      icon: Icons.code_rounded,
      steps: <String>[
        'Open Dev Studio from Home Quick Actions or Settings Search.',
        'Use "AI Prompts" for one-tap Debug, Code Review, Flutter, Kotlin, or Unit Test templates.',
        'Use "Offline Tools" to format JSON, encode/decode Base64, inspect JWT payloads offline, or test RegExp patterns.',
        'Save reusable code blocks in the local "Snippets" vault for one-tap copy.',
      ],
      actionLabel: 'Open Dev Studio',
      actionTarget: HelpActionTarget.openDeveloper,
      keywords: <String>[
        'developer',
        'code',
        'debug',
        'json',
        'jwt',
        'base64',
        'regex',
        'snippets',
      ],
    ),
  ];

  static const List<SettingSearchEntry> settingEntries = <SettingSearchEntry>[
    SettingSearchEntry(
      id: 'set_ai_keys',
      title: 'AI Providers & API Keys',
      subtitle: 'Configure Gemini, OpenAI, Claude, Edge AI & Test Connection',
      sectionLabel: 'AI Settings',
      icon: Icons.vpn_key_outlined,
      target: HelpActionTarget.openSettingsAi,
      keywords: <String>[
        'api',
        'key',
        'gemini',
        'openai',
        'claude',
        'edge',
        'model',
        'fallback',
        'usage',
      ],
    ),
    SettingSearchEntry(
      id: 'set_identity',
      title: 'Assistant Identity & Greeting',
      subtitle: 'Personality preset, communication style & custom instructions',
      sectionLabel: 'AI Settings',
      icon: Icons.auto_awesome_outlined,
      target: HelpActionTarget.openSettingsAi,
      keywords: <String>[
        'identity',
        'personality',
        'greeting',
        'style',
        'instructions',
      ],
    ),
    SettingSearchEntry(
      id: 'set_voice',
      title: 'Voice, Language, Rate & Pitch',
      subtitle: 'Auto / English / Hindi / Gujarati, native Android TTS voices',
      sectionLabel: 'Voice Settings',
      icon: Icons.record_voice_over_outlined,
      target: HelpActionTarget.openSettingsVoice,
      keywords: <String>[
        'voice',
        'language',
        'hindi',
        'gujarati',
        'english',
        'auto',
        'tts',
        'rate',
        'pitch',
      ],
    ),
    SettingSearchEntry(
      id: 'set_wakeword',
      title: 'Hey VISION Wake-Word & Sensitivity',
      subtitle: 'Hands-free offline standby & background microphone service',
      sectionLabel: 'Voice Settings',
      icon: Icons.hearing_rounded,
      target: HelpActionTarget.openSettingsVoice,
      keywords: <String>[
        'wake',
        'hey vision',
        'mic',
        'standby',
        'sensitivity',
        'background',
      ],
    ),
    SettingSearchEntry(
      id: 'set_device_guide',
      title: 'Permissions, Assistant Role & OEM Setup Guide',
      subtitle: 'Microphone, Contacts, Calls, Battery & installed device guide',
      sectionLabel: 'System & Permissions',
      icon: Icons.admin_panel_settings_outlined,
      target: HelpActionTarget.openSettingsSystem,
      keywords: <String>[
        'permission',
        'battery',
        'coloros',
        'one ui',
        'hyperos',
        'assistant role',
        'reboot',
      ],
    ),
    SettingSearchEntry(
      id: 'set_privacy',
      title: 'Privacy & Security Dashboard',
      subtitle: 'Trusted commands revoke, notification blocklist & clear data',
      sectionLabel: 'Privacy',
      icon: Icons.shield_outlined,
      target: HelpActionTarget.openPrivacyDashboard,
      keywords: <String>[
        'privacy',
        'security',
        'trusted',
        'revoke',
        'blocklist',
        'memory',
        'history',
        'clear',
      ],
    ),
    SettingSearchEntry(
      id: 'set_routines',
      title: 'Device Control Hub & Trusted Routines',
      subtitle: 'Multi-step routines, schedules, apps & execution history',
      sectionLabel: 'Automation',
      icon: Icons.bolt_outlined,
      target: HelpActionTarget.openAutomation,
      keywords: <String>[
        'routine',
        'automation',
        'schedule',
        'alarm',
        'apps',
        'history',
      ],
    ),
    SettingSearchEntry(
      id: 'set_planner',
      title: 'Daily Planner & Voice Briefing',
      subtitle: 'Tasks, priorities, reminders & spoken daily summary',
      sectionLabel: 'Planner',
      icon: Icons.checklist_rounded,
      target: HelpActionTarget.openPlanner,
      keywords: <String>['planner', 'task', 'todo', 'reminder', 'briefing'],
    ),
    SettingSearchEntry(
      id: 'set_smart_home',
      title: 'Smart Home Hub (Home Assistant & Webhooks)',
      subtitle: 'Control local Wi-Fi lights, switches & scenes by voice',
      sectionLabel: 'Smart Home',
      icon: Icons.home_outlined,
      target: HelpActionTarget.openSmartHome,
      keywords: <String>[
        'smart home',
        'home assistant',
        'webhook',
        'light',
        'scene',
        'iot',
      ],
    ),
    SettingSearchEntry(
      id: 'set_developer',
      title: 'Developer Assistant Studio',
      subtitle: 'AI coding templates, JSON/Base64/JWT/Regex tools & snippets',
      sectionLabel: 'Developer',
      icon: Icons.code_rounded,
      target: HelpActionTarget.openDeveloper,
      keywords: <String>[
        'developer',
        'code',
        'json',
        'jwt',
        'base64',
        'regex',
        'snippet',
        'debug',
      ],
    ),
    SettingSearchEntry(
      id: 'set_diagnostics',
      title: 'System Diagnostics & Telemetry Export',
      subtitle: 'Latency metrics, provider health & sanitized JSON report',
      sectionLabel: 'About',
      icon: Icons.monitor_heart_outlined,
      target: HelpActionTarget.openDiagnostics,
      keywords: <String>[
        'diagnostics',
        'logs',
        'latency',
        'telemetry',
        'export',
        'debug',
      ],
    ),
  ];

  static List<HelpGuideTopic> searchTopics(
    String query, {
    HelpCategory category = HelpCategory.all,
  }) {
    return topics
        .where((topic) {
          final categoryMatch =
              category == HelpCategory.all || topic.category == category;
          return categoryMatch && topic.matchesQuery(query);
        })
        .toList(growable: false);
  }

  static List<SettingSearchEntry> searchSettings(String query) {
    if (query.trim().isEmpty) return settingEntries;
    return settingEntries
        .where((entry) => entry.matchesQuery(query))
        .toList(growable: false);
  }
}
