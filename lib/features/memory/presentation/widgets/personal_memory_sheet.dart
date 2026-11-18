import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/features/contacts/data/repositories/contact_alias_repository.dart';
import 'package:vision_ai/features/memory/domain/entities/memory_entry.dart';
import 'package:vision_ai/features/memory/presentation/controllers/memory_controller.dart';

/// Modal management sheet allowing the user to view, add, toggle, edit,
/// or delete explicit local personalization memories.
class PersonalMemorySheet extends ConsumerStatefulWidget {
  const PersonalMemorySheet({super.key});

  @override
  ConsumerState<PersonalMemorySheet> createState() =>
      _PersonalMemorySheetState();
}

class _PersonalMemorySheetState extends ConsumerState<PersonalMemorySheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  MemoryCategory _selectedCategory = MemoryCategory.responseStyle;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final ok = await ref
        .read(memoryControllerProvider.notifier)
        .addEntry(
          category: _selectedCategory,
          title: _titleController.text,
          content: _contentController.text,
        );
    if (!mounted) return;
    if (ok) {
      _titleController.clear();
      _contentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personalization note saved locally.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Provide a valid title & value (passwords or API secrets are blocked).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = ref.watch(memoryControllerProvider);
    final controller = ref.read(memoryControllerProvider.notifier);
    final aliasRepo = ref.read(contactAliasRepositoryProvider);
    final aliases = aliasRepo.getAliases();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personalization Memory',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Switch.adaptive(
                    value: memory.memoryEnabled,
                    onChanged: controller.setMemoryEnabled,
                  ),
                ],
              ),
              Text(
                'Explicit local context used only when enabled. Separate from chat history.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<MemoryCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: MemoryCategory.values
                    .map(
                      (c) => DropdownMenuItem<MemoryCategory>(
                        value: c,
                        child: Text(c.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g., Tone, Work Contact Alias)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Preference detail',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: VisionGlassButton(
                      label: 'Save Memory',
                      icon: Icons.add_rounded,
                      onPressed: _handleAdd,
                    ),
                  ),
                  if (memory.entries.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Delete all memories',
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: VisionColors.error,
                      ),
                      onPressed: controller.clearAllEntries,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (memory.entries.isEmpty)
                Text(
                  'No personal preferences saved yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                for (final entry in memory.entries)
                  VisionGlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: entry.enabled,
                          onChanged: (v) =>
                              controller.toggleEntry(entry.id, v ?? false),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.title} • ${entry.category.displayName}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                entry.content,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => controller.deleteEntry(entry.id),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 18),
              Text(
                'Confirmed Voice Contact Aliases (${aliases.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Only user-confirmed spoken name mappings keyed by Android Contact ID.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (aliases.isEmpty)
                Text(
                  'No contact voice aliases saved yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                for (final alias in aliases)
                  VisionGlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.record_voice_over_outlined, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '"${alias.spokenPhrase}" -> ${alias.contactDisplayName}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                'Contact ID: ${alias.contactId}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete alias',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          onPressed: () async {
                            await aliasRepo.deleteAlias(alias.aliasId);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
