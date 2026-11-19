import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/features/smart_home/domain/entities/smart_home_device.dart';
import 'package:vision_ai/features/smart_home/presentation/controllers/smart_home_controller.dart';

/// Module 23: Local-first Smart Home Integration Hub (Home Assistant & Webhooks).
class SmartHomeScreen extends ConsumerStatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  ConsumerState<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends ConsumerState<SmartHomeScreen> {
  final _haUrlController = TextEditingController();
  final _haTokenController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _haUrlController.dispose();
    _haTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartHomeControllerProvider);
    if (!_initialized) {
      _haUrlController.text = state.haBaseUrl;
      _initialized = true;
    }

    final theme = Theme.of(context);
    final accent = VisionColors.primaryAccent(theme.brightness);

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'Smart Home',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Smart Device',
            onPressed: () => _showAddDeviceSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        children: [
          if (state.statusMessage != null) ...[
            VisionGlassCard(
              variant: VisionGlassVariant.subtle,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.statusMessage!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          VisionGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home_outlined, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Home Assistant Bridge (Optional)',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (state.hasHaToken)
                      const Chip(
                        label: Text('Token Saved'),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect a local Home Assistant server or use standalone local HTTP webhooks per device. Tokens are encrypted in Android Keystore.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                VisionGlassInput(
                  controller: _haUrlController,
                  hintText: 'http://homeassistant.local:8123',
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
                const SizedBox(height: 10),
                VisionGlassInput(
                  controller: _haTokenController,
                  hintText: state.hasHaToken
                      ? '•••••••• (Token saved — paste new to replace)'
                      : 'Long-Lived Access Token',
                  obscureText: true,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await ref
                            .read(smartHomeControllerProvider.notifier)
                            .saveHomeAssistantConfig(
                              baseUrl: _haUrlController.text,
                              bearerToken: _haTokenController.text,
                            );
                        _haTokenController.clear();
                      },
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Bridge'),
                    ),
                    if (state.hasHaToken) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => ref
                            .read(smartHomeControllerProvider.notifier)
                            .clearHomeAssistantToken(),
                        child: const Text('Clear Token'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Devices & Scenes (${state.devices.length})',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddDeviceSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Device'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.devices.isEmpty)
            VisionGlassCard(
              variant: VisionGlassVariant.subtle,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 36,
                    color: accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No smart home devices added yet',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add a Home Assistant entity or local HTTP webhook (Tasmota, ESPHome, Shelly, IFTTT), then say "Turn on Living Room Light".',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            for (final device in state.devices)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VisionGlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        device.isOn
                            ? Icons.lightbulb_rounded
                            : Icons.lightbulb_outline_rounded,
                        color: device.isOn ? accent : theme.iconTheme.color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${device.room} • ${device.backend.label}'
                              '${device.entityId.isNotEmpty ? ' • ${device.entityId}' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: device.isOn,
                        onChanged: state.isBusy
                            ? null
                            : (value) => ref
                                  .read(smartHomeControllerProvider.notifier)
                                  .setDevicePower(device, turnOn: value),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        tooltip: 'Delete Device',
                        onPressed: () => ref
                            .read(smartHomeControllerProvider.notifier)
                            .deleteDevice(device.id),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _showAddDeviceSheet(BuildContext context) async {
    final nameController = TextEditingController();
    final roomController = TextEditingController(text: 'Living Room');
    final entityController = TextEditingController();
    final onUrlController = TextEditingController();
    final offUrlController = TextEditingController();
    var backend = SmartHomeBackend.httpWebhook;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Smart Home Device / Scene',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Device or Scene Name',
                        hintText: 'e.g., Living Room Light',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        hintText: 'e.g., Living Room',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<SmartHomeBackend>(
                      segments: const [
                        ButtonSegment(
                          value: SmartHomeBackend.httpWebhook,
                          label: Text('HTTP Webhook'),
                        ),
                        ButtonSegment(
                          value: SmartHomeBackend.homeAssistant,
                          label: Text('Home Assistant'),
                        ),
                      ],
                      selected: {backend},
                      onSelectionChanged: (values) {
                        setSheetState(() => backend = values.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (backend == SmartHomeBackend.homeAssistant)
                      TextField(
                        controller: entityController,
                        decoration: const InputDecoration(
                          labelText: 'Home Assistant Entity ID',
                          hintText: 'e.g., light.living_room or scene.movie',
                        ),
                      )
                    else ...[
                      TextField(
                        controller: onUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Turn ON / Trigger URL',
                          hintText: 'http://192.168.1.50/cm?cmnd=Power%20On',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: offUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Turn OFF URL (Optional)',
                          hintText: 'http://192.168.1.50/cm?cmnd=Power%20Off',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) return;
                          await ref
                              .read(smartHomeControllerProvider.notifier)
                              .addDevice(
                                name: nameController.text,
                                room: roomController.text,
                                backend: backend,
                                entityId: entityController.text,
                                onWebhookUrl: onUrlController.text,
                                offWebhookUrl: offUrlController.text,
                              );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: const Text('Save Device'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    roomController.dispose();
    entityController.dispose();
    onUrlController.dispose();
    offUrlController.dispose();
  }
}
