# VISION AI v1.5 — Multi-Conversation Threads, Google Sign-In & Supabase Cloud Sync

## Overview

VISION AI v1.5 introduces:
1. **Multi-Conversation Threads & Searchable History** — Create, switch, search, pin, rename, delete, and export conversations as Markdown directly from the **Chat** screen. Respects VISION's session-only privacy default (`saveConversationHistory = false`) and automatically migrates legacy `chatHistory` into an initial thread when enabled.
2. **Optional Google Sign-In + Supabase Cloud Sync** — Guest/offline-first by default; sign in with Google in **Settings → Account & Cloud Sync** to sync conversation threads across devices.
3. **Zero-Knowledge Client-Side Encrypted API Key Vault** — Encrypts AI provider keys (Gemini, OpenAI, Claude) on-device using **AES-256-GCM** + **PBKDF2-HMAC-SHA256** (`120,000` iterations, random 128-bit salt + 96-bit nonce) before uploading to Supabase (`user_api_keys`). Supabase never sees plaintext keys.

---

## Supabase & Google Cloud Setup Guide

### 1. Create Supabase Tables & RLS Policies
Open your Supabase project's **SQL Editor** and run [docs/supabase_schema.sql](supabase_schema.sql).
This creates:
- `public.conversation_threads` (RLS: `auth.uid() = user_id`)
- `public.user_api_keys` (RLS: `auth.uid() = user_id`)

### 2. Configure Google OAuth
1. In **Google Cloud Console → APIs & Services → Credentials**:
   - Create an **Android OAuth 2.0 Client ID** for package `com.brijesh.vision` with your debug/release SHA-1 fingerprint.
   - Create a **Web application OAuth 2.0 Client ID** (this is your `GOOGLE_WEB_CLIENT_ID`).
2. In **Supabase Dashboard → Authentication → Providers → Google**:
   - Enable Google provider and paste the **Web Client ID** (and Secret if using web flow).

### 3. Build or Run with `--dart-define`
Never hardcode credentials into git. Pass them at build/run time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

For an Android release APK:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Without `--dart-define`, VISION AI runs seamlessly in **Guest / Local Mode** with full multi-conversation thread support and zero network dependencies.
