-- =============================================================================
-- VISION AI v1.5 — Supabase PostgreSQL Schema & Row-Level Security (RLS)
-- =============================================================================
-- Run this script once in your Supabase Project -> SQL Editor.
-- Both tables enforce strict per-user Row-Level Security (auth.uid() = user_id).
-- API keys are encrypted client-side (AES-256-GCM + PBKDF2-HMAC-SHA256) before
-- upload; Supabase never sees plaintext AI provider keys.

-- 1. Multi-Conversation Threads Table
create table if not exists public.conversation_threads (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'New Conversation',
  is_pinned boolean not null default false,
  messages_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_conversation_threads_user_updated
  on public.conversation_threads (user_id, updated_at desc);

alter table public.conversation_threads enable row level security;

drop policy if exists "Users read own threads" on public.conversation_threads;
create policy "Users read own threads"
  on public.conversation_threads
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own threads" on public.conversation_threads;
create policy "Users insert own threads"
  on public.conversation_threads
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own threads" on public.conversation_threads;
create policy "Users update own threads"
  on public.conversation_threads
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own threads" on public.conversation_threads;
create policy "Users delete own threads"
  on public.conversation_threads
  for delete
  using (auth.uid() = user_id);

-- 2. Zero-Knowledge Encrypted API Key Vault Table
create table if not exists public.user_api_keys (
  user_id uuid primary key references auth.users (id) on delete cascade,
  ciphertext text not null,
  nonce text not null,
  salt text not null,
  mac text not null,
  kdf_iterations integer not null default 120000,
  vault_version integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.user_api_keys enable row level security;

drop policy if exists "Users read own encrypted keys" on public.user_api_keys;
create policy "Users read own encrypted keys"
  on public.user_api_keys
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users insert own encrypted keys" on public.user_api_keys;
create policy "Users insert own encrypted keys"
  on public.user_api_keys
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users update own encrypted keys" on public.user_api_keys;
create policy "Users update own encrypted keys"
  on public.user_api_keys
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own encrypted keys" on public.user_api_keys;
create policy "Users delete own encrypted keys"
  on public.user_api_keys
  for delete
  using (auth.uid() = user_id);
