import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const RATE_LIMIT_MAX_REQUESTS = 30;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const MAX_QUESTION_LENGTH = 1000;
const MAX_HISTORY_MESSAGES = 20;

const SYSTEM_PROMPT =
  "You are the in-app nutrition assistant for a calorie-tracking app. " +
  "Answer the user's question about nutrition, their meals, or their " +
  "plan. You're given the user's daily calorie target, goal, and a " +
  "summary of what they've eaten today (if any) as context below — use " +
  "it to personalize your answer when relevant, but don't recite it back " +
  "verbatim unless asked. Keep answers conversational and concise (a " +
  "few sentences, occasionally a short list). If the context is missing " +
  "or doesn't cover the question, answer from general nutrition " +
  "knowledge instead. Never invent specific numbers for the user's own " +
  "data that weren't given to you.";

const RETRYABLE_STATUSES = new Set([429, 503]);
const MAX_ATTEMPTS = 5;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const sseHeaders = {
  ...corsHeaders,
  "Content-Type": "text/event-stream",
  "Cache-Control": "no-cache",
  Connection: "keep-alive",
};

function sseEvent(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function callGeminiStream(
  payload: unknown,
): Promise<ReadableStream<Uint8Array> | { error: string; detail: string }> {
  let lastDetail = "";

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    let res: Response | undefined;
    try {
      res = await fetch(`${GEMINI_URL}?alt=sse&key=${GEMINI_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
    } catch (err) {
      lastDetail = `${err}`;
      res = undefined;
    }

    if (res?.ok && res.body) return res.body;

    if (
      attempt < MAX_ATTEMPTS &&
      (res === undefined || RETRYABLE_STATUSES.has(res.status))
    ) {
      if (res) lastDetail = await res.text();
      await new Promise((resolve) =>
        setTimeout(resolve, 1000 * 2 ** (attempt - 1)),
      );
      continue;
    }

    if (res) lastDetail = await res.text();
    return { error: "Gemini API error", detail: lastDetail };
  }

  return { error: "Gemini API error", detail: lastDetail };
}

/** Builds the "today so far" nutrition summary injected into the system prompt. */
function buildContextBlock(
  profile: Record<string, unknown> | null,
  todayLogs: Array<Record<string, unknown>>,
): string {
  const lines: string[] = [];

  if (profile) {
    if (profile.daily_calorie_target) {
      lines.push(`Daily calorie target: ${profile.daily_calorie_target} kcal`);
    }
    if (profile.goal) lines.push(`Goal: ${profile.goal}`);
    if (profile.activity_level) {
      lines.push(`Activity level: ${profile.activity_level}`);
    }
  }

  if (todayLogs.length === 0) {
    lines.push("No meals logged yet today.");
  } else {
    const totals = todayLogs.reduce(
      (acc, log) => ({
        calories: acc.calories + (Number(log.total_calories) || 0),
        protein: acc.protein + (Number(log.total_protein) || 0),
        carbs: acc.carbs + (Number(log.total_carbs) || 0),
        fats: acc.fats + (Number(log.total_fats) || 0),
      }),
      { calories: 0, protein: 0, carbs: 0, fats: 0 },
    );
    lines.push(
      `Eaten today: ${totals.calories} kcal (protein ${totals.protein}g, ` +
        `carbs ${totals.carbs}g, fats ${totals.fats}g) across ${todayLogs.length} ` +
        `logged meal(s): ${
          todayLogs.map((log) => log.meal_name).join(", ")
        }.`,
    );
  }

  return lines.join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  if (!GEMINI_API_KEY) {
    return jsonResponse(500, { error: "GEMINI_API_KEY not configured" });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(401, { error: "Missing Authorization header" });
  }

  // Scoped to the caller's own JWT (not the service role), so every query
  // below — rate limit, profile, meal logs — runs under RLS as this user.
  const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "Invalid or expired session" });
  }
  const userId = userData.user.id;

  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString();
  const { count, error: countError } = await supabase
    .from("ask_ai_requests")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", windowStart);

  if (countError) {
    console.error("Rate limit check failed:", countError);
    return jsonResponse(500, { error: "Failed to check rate limit" });
  }

  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    return jsonResponse(429, {
      error: "You've hit the hourly limit for AI questions. Try again later.",
    });
  }

  let body: {
    question?: string;
    history?: Array<{ role?: string; text?: string }>;
  };
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON body" });
  }

  const question = body.question;
  if (!question || typeof question !== "string" || !question.trim()) {
    return jsonResponse(400, { error: "Missing 'question' in body" });
  }
  if (question.length > MAX_QUESTION_LENGTH) {
    return jsonResponse(413, { error: "Question is too long" });
  }

  const history = Array.isArray(body.history)
    ? body.history
        .filter(
          (m): m is { role: string; text: string } =>
            (m?.role === "user" || m?.role === "assistant") &&
            typeof m?.text === "string" &&
            m.text.trim().length > 0,
        )
        .slice(-MAX_HISTORY_MESSAGES)
    : [];

  const { error: insertError } = await supabase
    .from("ask_ai_requests")
    .insert({ user_id: userId });
  if (insertError) {
    console.error("Failed to log ask-ai request:", insertError);
    return jsonResponse(500, { error: "Failed to process request" });
  }

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const [{ data: profile }, { data: todayLogs }] = await Promise.all([
    supabase
      .from("profiles")
      .select("daily_calorie_target, goal, activity_level")
      .eq("id", userId)
      .maybeSingle(),
    supabase
      .from("meal_logs")
      .select("meal_name, total_calories, total_protein, total_carbs, total_fats")
      .eq("user_id", userId)
      .gte("created_at", todayStart.toISOString()),
  ]);

  const contextBlock = buildContextBlock(profile ?? null, todayLogs ?? []);

  const geminiPayload = {
    systemInstruction: {
      parts: [{ text: `${SYSTEM_PROMPT}\n\nContext:\n${contextBlock}` }],
    },
    contents: [
      ...history.map((message) => ({
        role: message.role === "assistant" ? "model" : "user",
        parts: [{ text: message.text }],
      })),
      { role: "user", parts: [{ text: question }] },
    ],
  };

  const geminiStream = await callGeminiStream(geminiPayload);
  if (!(geminiStream instanceof ReadableStream)) {
    console.error("Gemini API error:", geminiStream.detail);
    return jsonResponse(502, geminiStream);
  }

  let textBuffer = "";
  let sseLineBuffer = ""; // raw bytes from Gemini's own SSE framing

  const outStream = new ReadableStream<Uint8Array>({
    async start(controller) {
      const encoder = new TextEncoder();
      const emit = (event: string, data: unknown) =>
        controller.enqueue(encoder.encode(sseEvent(event, data)));

      try {
        const reader = geminiStream.getReader();
        const decoder = new TextDecoder();

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          sseLineBuffer += decoder.decode(value, { stream: true });
          const lines = sseLineBuffer.split("\n");
          sseLineBuffer = lines.pop() ?? "";

          for (const line of lines) {
            if (!line.startsWith("data:")) continue;
            const payload = line.slice(5).trim();
            if (!payload || payload === "[DONE]") continue;

            let chunk: unknown;
            try {
              chunk = JSON.parse(payload);
            } catch {
              continue;
            }

            const delta =
              // deno-lint-ignore no-explicit-any
              (chunk as any)?.candidates?.[0]?.content?.parts?.[0]?.text;
            if (typeof delta !== "string" || delta.length === 0) continue;

            textBuffer += delta;
            emit("delta", { text: delta });
          }
        }

        if (textBuffer.trim().length === 0) {
          emit("error", { message: "The assistant didn't return a response." });
        } else {
          emit("done", {});
        }
      } catch (err) {
        console.error("Streaming ask-ai failed:", err);
        emit("error", { message: `${err}` });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(outStream, { status: 200, headers: sseHeaders });
});
