import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/widgets/vision_bottom_sheet.dart';
import 'package:vision_ai/core/widgets/vision_dialog.dart';
import 'package:vision_ai/core/widgets/vision_empty_view.dart';
import 'package:vision_ai/core/widgets/vision_loading.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';
import 'package:vision_ai/core/widgets/vision_secondary_button.dart';
import 'package:vision_ai/core/widgets/vision_text_field.dart';
import 'package:vision_ai/features/chat/domain/entities/conversation_thread.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/chat/presentation/controllers/conversation_threads_controller.dart';

/// Bottom sheet for searching, creating, pinning, renaming, exporting, and
/// switching between multi-conversation threads.
class ConversationThreadsSheet extends ConsumerStatefulWidget {
  const ConversationThreadsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return VisionBottomSheet.show<void>(
      context,
      title: 'Conversations',
      child: const ConversationThreadsSheet(),
    );
  }

  @override
  ConsumerState<ConversationThreadsSheet> createState() =>
      _ConversationThreadsSheetState();
}

class _ConversationThreadsSheetState
    extends ConsumerState<ConversationThreadsSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _renameThread(ConversationThread thread) async {
    final editController = TextEditingController(text: thread.title);
    final updated = await VisionDialog.show<String>(
      context,
      title: 'Rename Conversation',
      icon: Icons.edit_outlined,
      content: VisionTextField(
        controller: editController,
        labelText: 'Conversation title',
        hintText: 'Enter a concise title',
      ),
      actions: <Widget>[
        VisionSecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        VisionPrimaryButton(
          label: 'Save',
          onPressed: () => Navigator.of(context).pop(editController.text),
        ),
      ],
    );
    editController.dispose();
    if (updated != null && updated.trim().isNotEmpty) {
      await ref
          .read(conversationThreadsControllerProvider.notifier)
          .renameThread(thread.id, updated);
    }
  }

  Future<void> _copyMarkdown(ConversationThread thread) async {
    final md = thread.toMarkdown();
    await Clipboard.setData(ClipboardData(text: md));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversation copied as Markdown.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadsState = ref.watch(conversationThreadsControllerProvider);
    final threads = threadsState.filteredThreads;
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: VisionTextField(
                  controller: _searchController,
                  hintText: 'Search threads or messages...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (value) => ref
                      .read(conversationThreadsControllerProvider.notifier)
                      .setSearchQuery(value),
                ),
              ),
              const SizedBox(width: VisionSpacing.xs),
              VisionPrimaryButton(
                label: 'New',
                icon: Icons.add_rounded,
                onPressed: () async {
                  await ref
                      .read(chatControllerProvider.notifier)
                      .startNewThread();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: VisionSpacing.sm),
          Flexible(
            child: threadsState.isSyncing
                ? VisionLoading.conversationList(itemCount: 4)
                : threads.isEmpty
                ? const VisionEmptyView(
                    icon: Icons.forum_outlined,
                    title: 'No matching conversations',
                    message:
                        'Try another search term or start a new conversation.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: threads.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: VisionSpacing.xs),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final isActive = thread.id == threadsState.activeThreadId;
                      return Material(
                        color: isActive
                            ? colors.primaryContainer.withValues(alpha: 0.45)
                            : colors.elevatedSurface,
                        borderRadius: VisionRadius.mdBorder,
                        child: InkWell(
                          borderRadius: VisionRadius.mdBorder,
                          onTap: () async {
                            await ref
                                .read(chatControllerProvider.notifier)
                                .openThread(thread);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: VisionSpacing.sm,
                              vertical: VisionSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: VisionRadius.mdBorder,
                              border: Border.all(
                                color: isActive
                                    ? colors.primary
                                    : colors.border,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  thread.isPinned
                                      ? Icons.push_pin_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: thread.isPinned || isActive
                                      ? colors.primary
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: VisionSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        thread.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${thread.messages.length} msg • ${thread.previewText}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Thread options',
                                  onSelected: (action) async {
                                    final ctrl = ref.read(
                                      conversationThreadsControllerProvider
                                          .notifier,
                                    );
                                    switch (action) {
                                      case 'pin':
                                        await ctrl.togglePin(thread.id);
                                      case 'rename':
                                        await _renameThread(thread);
                                      case 'markdown':
                                        await _copyMarkdown(thread);
                                      case 'delete':
                                        final next = await ctrl.deleteThread(
                                          thread.id,
                                        );
                                        await ref
                                            .read(
                                              chatControllerProvider.notifier,
                                            )
                                            .openThread(next);
                                    }
                                  },
                                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'pin',
                                      child: Text(
                                        thread.isPinned ? 'Unpin' : 'Pin',
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'rename',
                                      child: Text('Rename'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'markdown',
                                      child: Text('Copy as Markdown'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
