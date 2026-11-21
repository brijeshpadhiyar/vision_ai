import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const DAILY_LIMIT = 30;
const DEFAULT_MODEL = "gemini-2.5-flash";
const ALLOWED_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.0-flash",
]);

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return jsonResponse(
      {
        error: "unauthorized",
        message: "Sign in with Google to use VISION Cloud Free Tier.",
      },
      401,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) {
    return jsonResponse(
      {
        error: "unauthorized",
        message: "Your session expired. Please sign in again.",
      },
      401,
    );
  }

  const geminiApiKey = (Deno.env.get("GEMINI_API_KEY") ?? "").trim();
  if (!geminiApiKey) {
    return jsonResponse(
      {
        error: "server_not_configured",
        message:
          "VISION Cloud Free Tier is awaiting server GEMINI_API_KEY setup in Supabase Edge Function Secrets.",
      },
      503,
    );
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  if (body.action === "quota") {
    const today = new Date().toISOString().slice(0, 10);
    const { data: row } = await supabase
      .from("ai_daily_usage")
      .select("request_count")
      .eq("user_id", user.id)
      .eq("usage_date", today)
      .maybeSingle();
    const used = Number(row?.request_count ?? 0);
    const tomorrow = new Date(Date.now() + 86_400_000);
    tomorrow.setUTCHours(0, 0, 0, 0);
    return jsonResponse({
      quota: {
        allowed: used < DAILY_LIMIT,
        used,
        remaining: Math.max(DAILY_LIMIT - used, 0),
        daily_limit: DAILY_LIMIT,
        reset_at: tomorrow.toISOString(),
      },
    });
  }

  const { data: quota, error: quotaError } = await supabase.rpc(
    "consume_ai_quota",
    { p_daily_limit: DAILY_LIMIT },
  );
  if (quotaError || !quota) {
    return jsonResponse(
      {
        error: "quota_check_failed",
        message: quotaError?.message ?? "Unable to verify daily AI quota.",
      },
      500,
    );
  }
  if (!quota.allowed) {
    return jsonResponse(
      {
        error: "daily_quota_exceeded",
        message:
          "You have used all 30 free VISION Cloud requests for today. Add your own API key in Settings or wait for the daily reset.",
        quota,
      },
      429,
    );
  }

  const requestedModel = String(body.model ?? DEFAULT_MODEL).trim();
  const model = ALLOWED_MODELS.has(requestedModel)
    ? requestedModel
    : DEFAULT_MODEL;

  const contents = Array.isArray(body.contents) ? body.contents : [];
  if (contents.length === 0) {
    return jsonResponse(
      { error: "empty_contents", message: "Prompt messages cannot be empty." },
      400,
    );
  }

  const geminiPayload: Record<string, unknown> = {
    contents,
    generationConfig: {
      temperature: typeof body.temperature === "number" ? body.temperature : 0.7,
      maxOutputTokens:
        typeof body.maxOutputTokens === "number"
          ? Math.min(Math.max(body.maxOutputTokens, 64), 4096)
          : 1024,
    },
  };
  if (typeof body.systemInstruction === "string" && body.systemInstruction.trim()) {
    geminiPayload.systemInstruction = {
      parts: [{ text: body.systemInstruction.trim() }],
    };
  }

  const upstreamUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  try {
    const upstreamResp = await fetch(upstreamUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        "x-goog-api-key": geminiApiKey,
      },
      body: JSON.stringify(geminiPayload),
    });

    const upstreamText = await upstreamResp.text();
    if (!upstreamResp.ok) {
      return jsonResponse(
        {
          error: "upstream_error",
          status: upstreamResp.status,
          message: `Gemini upstream error (${upstreamResp.status}).`,
          quota,
        },
        upstreamResp.status >= 500 ? 502 : upstreamResp.status,
      );
    }

    const decoded = JSON.parse(upstreamText) as Record<string, unknown>;
    const candidates = Array.isArray(decoded.candidates)
      ? decoded.candidates
      : [];
    const first = candidates[0] as Record<string, unknown> | undefined;
    const content = first?.content as Record<string, unknown> | undefined;
    const parts = Array.isArray(content?.parts) ? content.parts : [];
    const replyText = parts
      .map((p) => (typeof (p as Record<string, unknown>)?.text === "string"
        ? String((p as Record<string, unknown>).text)
        : ""))
      .join("")
      .trim();

    const usageMeta = decoded.usageMetadata as
      | Record<string, unknown>
      | undefined;

    return jsonResponse({
      text: replyText,
      model,
      quota,
      usage: usageMeta
        ? {
            input_tokens: Number(usageMeta.promptTokenCount ?? 0),
            output_tokens: Number(usageMeta.candidatesTokenCount ?? 0),
            total_tokens: Number(usageMeta.totalTokenCount ?? 0),
          }
        : null,
    });
  } catch (err) {
    return jsonResponse(
      {
        error: "upstream_network_error",
        message: `Unable to reach Gemini API: ${err}`,
        quota,
      },
      502,
    );
  }
});
