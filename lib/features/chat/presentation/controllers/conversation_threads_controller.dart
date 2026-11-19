import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/entities/conversation_thread.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Immutable state for VISION AI's multi-conversation threads manager.
@immutable
class ConversationThreadsState {
  const ConversationThreadsState({
    this.threads = const <ConversationThread>[],
    this.activeThreadId,
    this.searchQuery = '',
    this.isSyncing = false,
  });

  final List<ConversationThread> threads;
  final String? activeThreadId;
  final String searchQuery;
  final bool isSyncing;

  /// Currently selected thread, if any.
  ConversationThread? get activeThread {
    if (activeThreadId == null) return null;
    for (final thread in threads) {
      if (thread.id == activeThreadId) return thread;
    }
    return null;
  }

  /// Threads filtered by [searchQuery], sorted with pinned threads first and
  /// most-recently-updated threads at the top.
  List<ConversationThread> get filteredThreads {
    final matching = threads
        .where((t) => t.matchesQuery(searchQuery))
        .toList(growable: false);
    final sorted = List<ConversationThread>.from(matching)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return List<ConversationThread>.unmodifiable(sorted);
  }

  ConversationThreadsState copyWith({
    List<ConversationThread>? threads,
    String? activeThreadId,
    String? searchQuery,
    bool? isSyncing,
    bool clearActiveThreadId = false,
  }) {
    return ConversationThreadsState(
      threads: threads ?? this.threads,
      activeThreadId: clearActiveThreadId
          ? null
          : (activeThreadId ?? this.activeThreadId),
      searchQuery: searchQuery ?? this.searchQuery,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Global Riverpod provider for [ConversationThreadsController].
final conversationThreadsControllerProvider =
    NotifierProvider<ConversationThreadsController, ConversationThreadsState>(
      ConversationThreadsController.new,
    );

/// Manages multi-conversation threads in memory (and persists locally when
/// `saveConversationHistory` is enabled).
class ConversationThreadsController extends Notifier<ConversationThreadsState> {
  @override
  ConversationThreadsState build() {
    final saveHistory = ref.watch(
      settingsControllerProvider.select((s) => s.saveConversationHistory),
    );
    final localDataSource = ref.watch(chatLocalDataSourceProvider);

    if (!saveHistory) {
      final initial = ConversationThread.create();
      return ConversationThreadsState(
        threads: <ConversationThread>[initial],
        activeThreadId: initial.id,
      );
    }

    final persisted = localDataSource.readThreads();
    if (persisted.isEmpty) {
      final initial = ConversationThread.create();
      return ConversationThreadsState(
        threads: <ConversationThread>[initial],
        activeThreadId: initial.id,
      );
    }

    final savedActiveId = localDataSource.readActiveThreadId();
    final activeId = persisted.any((t) => t.id == savedActiveId)
        ? savedActiveId
        : persisted.first.id;

    return ConversationThreadsState(
      threads: persisted,
      activeThreadId: activeId,
    );
  }

  bool get _shouldPersist =>
      ref.read(settingsControllerProvider).saveConversationHistory;

  Future<void> _persistIfEnabled() async {
    if (!_shouldPersist) return;
    final local = ref.read(chatLocalDataSourceProvider);
    await local.writeThreads(state.threads);
    await local.writeActiveThreadId(state.activeThreadId);
  }

  /// Creates and activates a fresh empty conversation thread.
  Future<ConversationThread> createNewThread({String? title}) async {
    final created = ConversationThread.create(
      title: title ?? ConversationThread.defaultTitle,
    );
    state = state.copyWith(
      threads: <ConversationThread>[created, ...state.threads],
      activeThreadId: created.id,
    );
    await _persistIfEnabled();
    return created;
  }

  /// Selects an existing thread by [threadId] and returns it.
  Future<ConversationThread?> selectThread(String threadId) async {
    ConversationThread? found;
    for (final t in state.threads) {
      if (t.id == threadId) {
        found = t;
        break;
      }
    }
    if (found == null) return null;
    state = state.copyWith(activeThreadId: threadId);
    await _persistIfEnabled();
    return found;
  }

  /// Updates the active thread's messages and auto-derives its title when
  /// still using the default title.
  Future<void> syncActiveThreadMessages(List<ChatMessage> messages) async {
    final activeId = state.activeThreadId;
    final now = DateTime.now();

    if (activeId == null || !state.threads.any((t) => t.id == activeId)) {
      final created = ConversationThread.create(
        title: ConversationThread.deriveTitle(messages),
        messages: messages,
        now: now,
      );
      state = state.copyWith(
        threads: <ConversationThread>[created, ...state.threads],
        activeThreadId: created.id,
      );
      await _persistIfEnabled();
      return;
    }

    final updated = state.threads
        .map((t) {
          if (t.id != activeId) return t;
          final nextTitle =
              (t.title == ConversationThread.defaultTitle &&
                  messages.isNotEmpty)
              ? ConversationThread.deriveTitle(messages)
              : t.title;
          return t.copyWith(
            title: nextTitle,
            messages: messages,
            updatedAt: now,
          );
        })
        .toList(growable: false);

    state = state.copyWith(threads: updated);
    await _persistIfEnabled();
  }

  /// Renames a thread by [threadId].
  Future<void> renameThread(String threadId, String newTitle) async {
    final cleaned = newTitle.trim();
    if (cleaned.isEmpty) return;
    final updated = state.threads
        .map(
          (t) => t.id == threadId
              ? t.copyWith(title: cleaned, updatedAt: DateTime.now())
              : t,
        )
        .toList(growable: false);
    state = state.copyWith(threads: updated);
    await _persistIfEnabled();
  }

  /// Toggles pinned status on a thread by [threadId].
  Future<void> togglePin(String threadId) async {
    final updated = state.threads
        .map(
          (t) => t.id == threadId
              ? t.copyWith(isPinned: !t.isPinned, updatedAt: DateTime.now())
              : t,
        )
        .toList(growable: false);
    state = state.copyWith(threads: updated);
    await _persistIfEnabled();
  }

  /// Deletes a thread by [threadId], ensuring at least one active thread exists.
  Future<ConversationThread> deleteThread(String threadId) async {
    final remaining = state.threads
        .where((t) => t.id != threadId)
        .toList(growable: false);

    if (remaining.isEmpty) {
      final fresh = ConversationThread.create();
      state = state.copyWith(
        threads: <ConversationThread>[fresh],
        activeThreadId: fresh.id,
      );
      await _persistIfEnabled();
      return fresh;
    }

    final nextActiveId = state.activeThreadId == threadId
        ? remaining.first.id
        : state.activeThreadId;
    state = state.copyWith(threads: remaining, activeThreadId: nextActiveId);
    await _persistIfEnabled();
    return state.activeThread ?? remaining.first;
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSyncing(bool syncing) {
    state = state.copyWith(isSyncing: syncing);
  }

  /// Merges remote threads from Supabase using last-write-wins by `updatedAt`.
  Future<void> mergeRemoteThreads(
    List<ConversationThread> remoteThreads,
  ) async {
    if (remoteThreads.isEmpty) return;

    final byId = <String, ConversationThread>{
      for (final local in state.threads) local.id: local,
    };

    for (final remote in remoteThreads) {
      final existing = byId[remote.id];
      if (existing == null || remote.updatedAt.isAfter(existing.updatedAt)) {
        byId[remote.id] = remote;
      }
    }

    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final nextActiveId =
        (state.activeThreadId != null && byId.containsKey(state.activeThreadId))
        ? state.activeThreadId
        : merged.first.id;

    state = state.copyWith(threads: merged, activeThreadId: nextActiveId);
    await _persistIfEnabled();
  }

  /// Exports a thread as Markdown text.
  String? exportThreadMarkdown(String threadId) {
    for (final t in state.threads) {
      if (t.id == threadId) return t.toMarkdown();
    }
    return null;
  }
}
