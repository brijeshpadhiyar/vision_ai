import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/developer/data/services/developer_tools_service.dart';
import 'package:vision_ai/features/developer/presentation/controllers/developer_snippets_controller.dart';

enum _DevTab { prompts, tools, snippets }

enum _OfflineTool { jsonFormat, base64Encode, base64Decode, jwtDecode, regex }

class _DevPromptTemplate {
  const _DevPromptTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.prefix,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String prefix;
}

/// Module 26: Developer Assistant Studio (AI Coding Templates, Offline Dev Tools, Snippet Vault).
class DeveloperAssistantScreen extends ConsumerStatefulWidget {
  const DeveloperAssistantScreen({super.key});

  @override
  ConsumerState<DeveloperAssistantScreen> createState() =>
      _DeveloperAssistantScreenState();
}

class _DeveloperAssistantScreenState
    extends ConsumerState<DeveloperAssistantScreen> {
  static const List<_DevPromptTemplate> _templates = <_DevPromptTemplate>[
    _DevPromptTemplate(
      title: 'Debug Error / Stack Trace',
      subtitle: 'Diagnose root cause & propose a minimal fix',
      icon: Icons.bug_report_outlined,
      prefix:
          'Act as a senior software engineer. Diagnose the root cause of this error and give a minimal, production-safe fix:\n\n',
    ),
    _DevPromptTemplate(
      title: 'Code Review & Refactor',
      subtitle: 'Spot bugs, edge cases, and performance bottlenecks',
      icon: Icons.rate_review_outlined,
      prefix:
          'Review this code for bugs, security issues, and performance improvements. Keep feedback concise and actionable:\n\n',
    ),
    _DevPromptTemplate(
      title: 'Flutter / Dart Helper',
      subtitle: 'Widgets, Riverpod state, GoRouter, or performance',
      icon: Icons.flutter_dash_outlined,
      prefix:
          'Write clean, null-safe Flutter/Dart code following Material 3 & Riverpod best practices for:\n\n',
    ),
    _DevPromptTemplate(
      title: 'Kotlin / Android Helper',
      subtitle: 'Intents, Services, Permissions, MethodChannels',
      icon: Icons.android_outlined,
      prefix:
          'Write modern, safe Kotlin Android code (API 26–35 compatible) for:\n\n',
    ),
    _DevPromptTemplate(
      title: 'Generate Unit Tests',
      subtitle: 'Cover happy paths, edge cases, and failure states',
      icon: Icons.verified_outlined,
      prefix:
          'Write comprehensive unit tests covering normal cases, boundary values, and error handling for:\n\n',
    ),
  ];

  _DevTab _tab = _DevTab.prompts;
  _OfflineTool _tool = _OfflineTool.jsonFormat;
  final _toolInputController = TextEditingController();
  final _regexPatternController = TextEditingController();
  DevToolResult? _toolResult;

  @override
  void dispose() {
    _toolInputController.dispose();
    _regexPatternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = VisionColors.primaryAccent(theme.brightness);

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'Developer Assistant',
        actions: [
          if (_tab == _DevTab.snippets)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'New Snippet',
              onPressed: () => _showAddSnippetSheet(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  VisionGlassChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI Prompts',
                    selected: _tab == _DevTab.prompts,
                    onTap: () => setState(() => _tab = _DevTab.prompts),
                  ),
                  const SizedBox(width: 8),
                  VisionGlassChip(
                    icon: Icons.build_outlined,
                    label: 'Offline Tools',
                    selected: _tab == _DevTab.tools,
                    onTap: () => setState(() => _tab = _DevTab.tools),
                  ),
                  const SizedBox(width: 8),
                  VisionGlassChip(
                    icon: Icons.code_rounded,
                    label: 'Snippets',
                    selected: _tab == _DevTab.snippets,
                    onTap: () => setState(() => _tab = _DevTab.snippets),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _DevTab.prompts => _buildPromptsTab(context, theme, accent),
              _DevTab.tools => _buildToolsTab(context, theme, accent),
              _DevTab.snippets => _buildSnippetsTab(context, theme, accent),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromptsTab(
    BuildContext context,
    ThemeData theme,
    Color accent,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tpl = _templates[index];
        return VisionGlassCard(
          onTap: () => _showPromptLaunchDialog(context, tpl),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(tpl.icon, size: 22, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tpl.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(tpl.subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: accent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolsTab(BuildContext context, ThemeData theme, Color accent) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('JSON Format'),
              selected: _tool == _OfflineTool.jsonFormat,
              onSelected: (_) => setState(() {
                _tool = _OfflineTool.jsonFormat;
                _toolResult = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Base64 Enc'),
              selected: _tool == _OfflineTool.base64Encode,
              onSelected: (_) => setState(() {
                _tool = _OfflineTool.base64Encode;
                _toolResult = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Base64 Dec'),
              selected: _tool == _OfflineTool.base64Decode,
              onSelected: (_) => setState(() {
                _tool = _OfflineTool.base64Decode;
                _toolResult = null;
              }),
            ),
            ChoiceChip(
              label: const Text('JWT Decode'),
              selected: _tool == _OfflineTool.jwtDecode,
              onSelected: (_) => setState(() {
                _tool = _OfflineTool.jwtDecode;
                _toolResult = null;
              }),
            ),
            ChoiceChip(
              label: const Text('Regex Test'),
              selected: _tool == _OfflineTool.regex,
              onSelected: (_) => setState(() {
                _tool = _OfflineTool.regex;
                _toolResult = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tool == _OfflineTool.regex) ...[
          TextField(
            controller: _regexPatternController,
            decoration: const InputDecoration(
              labelText: 'RegExp Pattern',
              hintText: r'e.g., \b\d{4}\b',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _toolInputController,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: switch (_tool) {
              _OfflineTool.jsonFormat => 'Raw JSON',
              _OfflineTool.base64Encode => 'Plain Text',
              _OfflineTool.base64Decode => 'Base64 String',
              _OfflineTool.jwtDecode => 'JWT Token (runs 100% offline)',
              _OfflineTool.regex => 'Sample Text',
            },
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _runSelectedTool,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Run Offline'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _toolInputController.clear();
                _regexPatternController.clear();
                setState(() => _toolResult = null);
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        if (_toolResult != null) ...[
          const SizedBox(height: 14),
          VisionGlassCard(
            variant: VisionGlassVariant.subtle,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _toolResult!.success
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: _toolResult!.success
                          ? VisionColors.success
                          : VisionColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _toolResult!.success ? 'Output' : 'Error',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Output',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _toolResult!.output),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied output.')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _toolResult!.output,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSnippetsTab(
    BuildContext context,
    ThemeData theme,
    Color accent,
  ) {
    final snippets = ref.watch(developerSnippetsControllerProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: () => _showAddSnippetSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Save Snippet'),
          ),
        ),
        const SizedBox(height: 10),
        if (snippets.isEmpty)
          VisionGlassCard(
            variant: VisionGlassVariant.subtle,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.code_rounded, size: 34, color: accent),
                const SizedBox(height: 8),
                Text('No saved snippets yet', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Store frequently used Dart, Kotlin, SQL, or shell commands locally for one-tap copy.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          )
        else
          for (final snippet in snippets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VisionGlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            snippet.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Chip(
                          label: Text(snippet.language),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: snippet.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${snippet.title}".'),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          tooltip: 'Delete Snippet',
                          onPressed: () => ref
                              .read(developerSnippetsControllerProvider.notifier)
                              .deleteSnippet(snippet.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      snippet.code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  void _runSelectedTool() {
    final input = _toolInputController.text;
    final result = switch (_tool) {
      _OfflineTool.jsonFormat => DeveloperToolsService.formatJson(input),
      _OfflineTool.base64Encode => DeveloperToolsService.encodeBase64(input),
      _OfflineTool.base64Decode => DeveloperToolsService.decodeBase64(input),
      _OfflineTool.jwtDecode => DeveloperToolsService.decodeJwt(input),
      _OfflineTool.regex => DeveloperToolsService.testRegex(
        pattern: _regexPatternController.text,
        sampleText: input,
      ),
    };
    setState(() => _toolResult = result);
  }

  Future<void> _showPromptLaunchDialog(
    BuildContext context,
    _DevPromptTemplate template,
  ) async {
    final controller = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.title),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Paste your code, error, or question...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Ask VISION'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (submitted == null || submitted.isEmpty || !context.mounted) return;

    final fullPrompt = '${template.prefix}$submitted';
    context.go(AppRoutes.chatPath);
    await ref.read(chatControllerProvider.notifier).sendMessage(fullPrompt);
  }

  Future<void> _showAddSnippetSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final langController = TextEditingController(text: 'dart');
    final codeController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
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
                'Save Code Snippet',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: langController,
                decoration: const InputDecoration(
                  labelText: 'Language (dart, kotlin, sql, bash)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        codeController.text.trim().isEmpty) {
                      return;
                    }
                    await ref
                        .read(developerSnippetsControllerProvider.notifier)
                        .addSnippet(
                          title: titleController.text,
                          language: langController.text,
                          code: codeController.text,
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Save Snippet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    titleController.dispose();
    langController.dispose();
    codeController.dispose();
  }
}
