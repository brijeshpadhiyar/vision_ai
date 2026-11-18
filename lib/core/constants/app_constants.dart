/// Centralized application-wide constants for VISION AI.
abstract final class AppConstants {
  /// Display name of the application.
  static const String appName = 'VISION';

  /// Extended product title.
  static const String appFullTitle = 'VISION AI';

  /// Official brand tagline.
  static const String appTagline = 'Your Intelligence. Your Assistant.';

  /// Android application package identifier.
  static const String applicationId = 'com.brijesh.vision';

  /// Branding asset paths.
  static const String brandIconPngAsset = 'assets/branding/vision_icon.png';
  static const String brandLogoPngAsset = 'assets/branding/vision_logo.png';
  static const String brandLogoDarkPngAsset =
      'assets/branding/vision_logo_dark.png';
  static const String brandLogoLightPngAsset =
      'assets/branding/vision_logo_light.png';

  /// Coordinated Flutter splash timing constants.
  static const Duration splashMinimumDuration = Duration(milliseconds: 700);
  static const Duration splashTransitionDuration = Duration(milliseconds: 350);

  /// Current semantic version and build number.
  static const String appVersion = '1.0.0+1';

  /// Current development milestone label (honest verified status).
  static const String currentPhaseLabel =
      'Phase 4 • Android Automation & Hands-Free Assistant';

  /// MethodChannel identifier for the native Android voice engine.
  static const String voiceMethodChannel = 'com.brijesh.vision/voice';

  /// EventChannel identifier for streaming STT transcripts, amplitude, and TTS state.
  static const String voiceEventChannel = 'com.brijesh.vision/voice_events';

  /// MethodChannel identifier for native Android device automation and system intents.
  static const String automationMethodChannel = 'com.brijesh.vision/automation';

  /// Default wake-word phrase displayed to users.
  static const String wakeWordDisplayPhrase = 'Hey VISION';

  /// Network request timeout for AI provider completions.
  static const Duration aiRequestTimeout = Duration(seconds: 45);

  /// Maximum number of recent messages included as context in AI requests.
  static const int maxContextMessages = 16;

  /// Target hardware profile used for layout calibration.
  static const String targetDeviceName = 'OPPO Reno 16';

  /// Primary greeting displayed on the Assistant home screen.
  static const String homeGreeting = "Hello, I'm VISION.";

  /// Subtitle displayed below the primary greeting.
  static const String homeSubtitle = 'Your personal AI assistant.';

  /// Honest status message shown when interacting with the microphone placeholder in Phase 1.
  static const String micPlaceholderMessage =
      'Voice recognition is disabled in Phase 1. '
      'Speech-to-text and wake-word engines will be integrated in Phase 3.';

  /// Responsive breakpoint distinguishing compact phones from wide/landscape layouts.
  static const double compactBreakpoint = 600.0;

  /// Maximum constrained width for content cards on wide screens.
  static const double maxContentWidth = 560.0;

  /// Default diameter for the central assistant orb.
  static const double orbBaseSize = 200.0;

  /// Breathing cycle duration for the central assistant orb.
  static const Duration orbPulseDuration = Duration(milliseconds: 3200);

  /// Standard UI transition duration.
  static const Duration standardTransitionDuration = Duration(
    milliseconds: 250,
  );
}
