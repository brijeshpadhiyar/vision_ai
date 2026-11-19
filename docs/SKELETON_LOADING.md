# VISION AI — Skeleton Loading (`skeletonizer`)

## Overview

VISION AI uses `skeletonizer: ^3.0.0` for theme-aware, content-shaped loading placeholders across Midnight Violet (dark) and Pearl Lavender (light) themes.

## Global Theme Configuration

In `lib/app/app.dart`, `VisionApp` wraps the application subtree in `SkeletonizerConfig` via `VisionApp.buildSkeletonizerConfig(...)`:

- **Dark (Midnight Violet)**: `ShimmerEffect` transitioning between `#22212E` (`elevatedSurface`) and `#302D3C` (`border`) on `#191823` (`surface`) containers.
- **Light (Pearl Lavender)**: `ShimmerEffect` transitioning between `#F0EDF5` (`secondaryBackground`) and `#FFFFFF` (`surface`) on `#FFFFFF` containers.
- **Reduced Motion**: Automatically switches from `ShimmerEffect` to `SolidColorEffect` and disables switch animations (`enableSwitchAnimation: false`).

## Reusable Loading Widgets (`lib/core/widgets/vision_loading.dart`)

| Widget / Factory | Intended Surface |
| :--- | :--- |
| `VisionLoading(enabled: ..., child: ...)` | Generic wrapper for any real data-driven widget |
| `VisionLoading.providerCard()` | AI provider status / API key loading card |
| `VisionLoading.modelList(itemCount: 3)` | AI model discovery / picker list |
| `VisionLoading.chatPlaceholder()` | Chat assistant reply placeholder while awaiting first token |
| `VisionLoading.settingsSection(itemCount: 3)` | Settings section loading placeholder |
| `VisionLoading.conversationList(itemCount: 4)` | Conversation history list loading placeholder |
| `VisionLoadingSkeleton` | Backward-compatible single bone / card helper |

## Usage Rules

- Wire skeletons strictly to real Riverpod async loading states (e.g., `apiKeyStatusControllerProvider.isLoading`, `chatState.isLoading` before first token arrives).
- Never introduce artificial `Future.delayed(...)` loading delays.
- Do not wrap purely static screens in `Skeletonizer`.
