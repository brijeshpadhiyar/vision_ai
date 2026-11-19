import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Lightweight, high-performance Markdown & code-block renderer for AI replies.
///
/// Supports fenced code blocks (with language tag + copy button), headings,
/// bullet/numbered lists, blockquotes, inline code, bold, and italic spans.
class VisionMarkdownText extends StatelessWidget {
  const VisionMarkdownText({
    required this.data,
    super.key,
    this.isStreaming = false,
  });

  final String data;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(data);
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    if (blocks.isEmpty) {
      return isStreaming
          ? _StreamingCursor(color: VisionColors.primaryAccent(brightness))
          : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildBlock(
            context,
            blocks[i],
            appendCursor: isStreaming && i == blocks.length - 1,
          ),
        ],
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    _MdBlock block, {
    required bool appendCursor,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final baseStyle = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 15,
      height: 1.5,
      color: VisionColors.primaryText(brightness),
    );

    switch (block) {
      case _CodeBlock(:final language, :final code):
        return _GlassCodeBlock(language: language, code: code);
      case _HeadingBlock(:final level, :final text):
        final size = switch (level) {
          1 => 19.0,
          2 => 17.5,
          _ => 16.0,
        };
        return SelectableText.rich(
          TextSpan(
            children: _parseInline(
              text,
              baseStyle.copyWith(fontSize: size, fontWeight: FontWeight.w700),
              brightness,
            ),
          ),
        );
      case _QuoteBlock(:final text):
        return Container(
          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: VisionColors.primaryAccent(brightness),
                width: 3,
              ),
            ),
          ),
          child: SelectableText.rich(
            TextSpan(
              children: _parseInline(
                text,
                baseStyle.copyWith(
                  color: VisionColors.secondaryText(brightness),
                  fontStyle: FontStyle.italic,
                ),
                brightness,
              ),
            ),
          ),
        );
      case _ListItemBlock(:final marker, :final text):
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 8),
              child: Text(
                marker,
                style: baseStyle.copyWith(
                  color: VisionColors.primaryAccent(brightness),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: SelectableText.rich(
                TextSpan(children: _parseInline(text, baseStyle, brightness)),
              ),
            ),
          ],
        );
      case _ParagraphBlock(:final text):
        final spans = _parseInline(text, baseStyle, brightness);
        if (appendCursor) {
          spans.add(
            TextSpan(
              text: ' ▍',
              style: baseStyle.copyWith(
                color: VisionColors.primaryAccent(brightness),
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        return SelectableText.rich(TextSpan(children: spans));
    }
  }

  List<_MdBlock> _parseBlocks(String input) {
    final normalized = input.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final blocks = <_MdBlock>[];
    final paragraphLines = <String>[];

    void flushParagraph() {
      if (paragraphLines.isNotEmpty) {
        blocks.add(_ParagraphBlock(paragraphLines.join('\n').trimRight()));
        paragraphLines.clear();
      }
    }

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('```')) {
        flushParagraph();
        final language = trimmed.substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        blocks.add(
          _CodeBlock(
            language: language.isEmpty ? 'code' : language,
            code: codeLines.join('\n'),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(trimmed);
      if (headingMatch != null) {
        flushParagraph();
        blocks.add(
          _HeadingBlock(
            level: headingMatch.group(1)!.length,
            text: headingMatch.group(2)!.trim(),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('> ')) {
        flushParagraph();
        blocks.add(_QuoteBlock(trimmed.substring(2).trim()));
        i++;
        continue;
      }

      final bulletMatch = RegExp(r'^[-*•]\s+(.+)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        flushParagraph();
        blocks.add(
          _ListItemBlock(marker: '•', text: bulletMatch.group(1)!.trim()),
        );
        i++;
        continue;
      }

      final orderedMatch = RegExp(r'^(\d+\.)\s+(.+)$').firstMatch(trimmed);
      if (orderedMatch != null) {
        flushParagraph();
        blocks.add(
          _ListItemBlock(
            marker: orderedMatch.group(1)!,
            text: orderedMatch.group(2)!.trim(),
          ),
        );
        i++;
        continue;
      }

      paragraphLines.add(line);
      i++;
    }

    flushParagraph();
    return blocks;
  }

  List<InlineSpan> _parseInline(
    String text,
    TextStyle baseStyle,
    Brightness brightness,
  ) {
    final spans = <InlineSpan>[];
    final tokenPattern = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*|\*[^*]+\*)');
    var cursor = 0;

    for (final match in tokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        spans.add(
          TextSpan(
            text: ' ${token.substring(1, token.length - 1)} ',
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (baseStyle.fontSize ?? 15) - 1,
              color: VisionColors.primaryAccent(brightness),
              backgroundColor: VisionColors.glassSurface(
                brightness,
                opacity: 0.12,
              ),
            ),
          ),
        );
      } else if (token.startsWith('**') &&
          token.endsWith('**') &&
          token.length >= 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length >= 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: baseStyle));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return spans;
  }
}

sealed class _MdBlock {
  const _MdBlock();
}

final class _ParagraphBlock extends _MdBlock {
  const _ParagraphBlock(this.text);
  final String text;
}

final class _HeadingBlock extends _MdBlock {
  const _HeadingBlock({required this.level, required this.text});
  final int level;
  final String text;
}

final class _QuoteBlock extends _MdBlock {
  const _QuoteBlock(this.text);
  final String text;
}

final class _ListItemBlock extends _MdBlock {
  const _ListItemBlock({required this.marker, required this.text});
  final String marker;
  final String text;
}

final class _CodeBlock extends _MdBlock {
  const _CodeBlock({required this.language, required this.code});
  final String language;
  final String code;
}

class _GlassCodeBlock extends StatelessWidget {
  const _GlassCodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: VisionRadii.mdBorder,
        color: isDark
            ? VisionColors.darkSecondaryBackground
            : VisionColors.darkSurface,
        border: Border.all(
          color: VisionColors.glassBorder(Brightness.dark, opacity: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: VisionColors.glassSurface(Brightness.dark, opacity: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(VisionRadii.md),
              ),
              border: Border(
                bottom: BorderSide(
                  color: VisionColors.glassBorder(
                    Brightness.dark,
                    opacity: 0.12,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  language.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VisionColors.accentPrimary,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Copy code snippet',
                  child: Semantics(
                    button: true,
                    label: 'Copy code snippet',
                    child: InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code copied to clipboard.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      borderRadius: VisionRadii.xsBorder,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: VisionColors.textSecondaryDark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: VisionColors.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
                color: VisionColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingCursor extends StatelessWidget {
  const _StreamingCursor({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '▍',
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
    );
  }
}
