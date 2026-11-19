# VISION AI — Reusable Widget Library

Located in `lib/core/widgets/`. All widgets read tokens from `context.visionColors` and `Theme.of(context)`.

| Widget | File | Purpose |
|---|---|---|
| `VisionCard` | `vision_card.dart` | Standard, elevated, and bordered surface card |
| `VisionGradientCard` | `vision_gradient_card.dart` | Soft violet-accented gradient highlight card |
| `VisionGlassPanel` | `vision_glass_panel.dart` | Selective translucent panel for overlays & banners |
| `VisionPrimaryButton` | `vision_primary_button.dart` | Primary FilledButton with built-in loading state |
| `VisionSecondaryButton` | `vision_secondary_button.dart` | Outlined secondary button with semantic border |
| `VisionIconButton` | `vision_icon_button.dart` | Accessible 44×44 bordered icon button |
| `VisionTextField` | `vision_text_field.dart` | Semantic themed text input |
| `VisionStatusBadge` | `vision_status_badge.dart` | Pill status indicator for standby/listening/thinking |
| `VisionSectionHeader` | `vision_section_header.dart` | Consistent section title, subtitle, icon & trailing |
| `VisionBottomNavigation` | `vision_bottom_navigation.dart` | Floating navigation bar |
| `VisionDialog` | `vision_dialog.dart` | Semantic Material 3 dialog helper |
| `VisionBottomSheet` | `vision_bottom_sheet.dart` | Rounded modal sheet with drag handle |
| `VisionSnackBar` | `vision_snackbar.dart` | Floating tone-aware snackbar (`info`, `success`, `warning`, `error`) |
| `VisionLoadingSkeleton` | `vision_loading.dart` | Reduced-motion-aware shimmer skeleton & card placeholder |
| `VisionErrorView` | `vision_error_view.dart` | Semantic error/offline panel with retry CTA |
| `VisionEmptyView` | `vision_empty_view.dart` | Semantic empty state with optional CTA |
| `VisionOrb` | `vision_orb.dart` | 6-state animated AI orb (`idle`, `listening`, `thinking`, `speaking`, `error`, `offline`) |

## Usage Example

```dart
VisionGradientCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const VisionSectionHeader(
        title: 'AI Provider',
        subtitle: 'Connected to Gemini',
        icon: Icons.auto_awesome_rounded,
      ),
      const SizedBox(height: 12),
      VisionPrimaryButton(
        label: 'Test Connection',
        icon: Icons.bolt_rounded,
        onPressed: onTest,
      ),
    ],
  ),
)
```
