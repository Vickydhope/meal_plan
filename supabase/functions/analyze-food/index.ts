import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { IncrementalJsonScanner } from "./json_scanner.ts";
import { parseAnalyzeBody } from "./request_body.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:streamGenerateContent";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const RATE_LIMIT_MAX_REQUESTS = 20;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;

// `items` is declared right after `meal_name` and before the aggregate
// fields, since Gemini's structured output tends to fill fields in
// schema-declaration order — this lets the meal name and each ingredient
// stream out before the totals that depend on them.
const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    meal_name: { type: "string" },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          food_name: { type: "string" },
          estimated_weight_g: { type: "number" },
          calories: { type: "number" },
          protein_g: { type: "number" },
          carbs_g: { type: "number" },
          fats_g: { type: "number" },
        },
        required: [
          "food_name",
          "estimated_weight_g",
          "calories",
          "protein_g",
          "carbs_g",
          "fats_g",
        ],
      },
    },
    health_score: { type: "number" },
    total_calories: { type: "number" },
    total_protein_g: { type: "number" },
    total_carbs_g: { type: "number" },
    total_fats_g: { type: "number" },
  },
  required: [
    "meal_name",
    "items",
    "health_score",
    "total_calories",
    "total_protein_g",
    "total_carbs_g",
    "total_fats_g",
  ],
};

const PROMPT =
  "You are a nutrition estimation engine. Look at the food in this image " +
  "and give it a short, appetizing meal name (2-4 words, e.g. 'Grilled " +
  "Chicken Bowl'). Identify each distinct food item, its estimated weight " +
  "in grams, its calories, and its protein/carbs/fats in grams. Then sum " +
  "totals for calories, protein, carbs, and fats across all items. Also " +
  "give a health_score from 1 (unhealthy) to 10 (very healthy) based on " +
  "nutrient balance, processing level, and portion size. Respond with " +
  "realistic estimates even if uncertain. If the image does not show any " +
  "food or drink at all, return an empty items array, set meal_name to " +
  "'No food detected', and set all totals and health_score to 0 — do not " +
  "invent food items that aren't actually present in the image.";

// The description goes in its own part after these instructions, so it's
// treated as data about the meal rather than as further instructions.
const TEXT_PROMPT =
  "You are a nutrition estimation engine. The next message is the user's " +
  "own description of a meal they ate. Give it a short, appetizing meal " +
  "name (2-4 words). Identify each distinct food item, its weight in " +
  "grams (use the stated quantity, or a typical single serving if none is " +
  "given), its calories, and its protein/carbs/fats in grams. Then sum " +
  "totals for calories, protein, carbs, and fats across all items. Also " +
  "give a health_score from 1 (unhealthy) to 10 (very healthy) based on " +
  "nutrient balance, processing level, and portion size. Respond with " +
  "realistic estimates even if uncertain. If the description doesn't " +
  "mention any food or drink, return an empty items array, set meal_name " +
  "to 'No food detected', and set all totals and health_score to 0.";

const RETRYABLE_STATUSES = new Set([429, 503]);
const MAX_ATTEMPTS = 3;
// Caps the wait for Gemini's response headers per attempt; cleared once
// they arrive, so it never cuts off a stream that's already flowing.
const ATTEMPT_TIMEOUT_MS = 20_000;

// Caps the silence between chunks of an already-started Gemini stream, so a
// stall mid-response fails fast instead of holding the request open until
// the edge runtime's wall-clock limit kills it.
const STREAM_STALL_TIMEOUT_MS = 15_000;

/** An error whose message is written for the user, so it can be shown
 * as-is; anything else (parse errors, network failures) gets generic copy. */
class UserFacingError extends Error {}

async function readWithStallTimeout(
  reader: ReadableStreamDefaultReader<Uint8Array>,
): Promise<ReadableStreamReadResult<Uint8Array>> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const stalled = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reader.cancel().catch(() => {});
      reject(
        new UserFacingError("The AI service stopped responding. Try again."),
      );
    }, STREAM_STALL_TIMEOUT_MS);
  });
  try {
    return await Promise.race([reader.read(), stalled]);
  } finally {
    clearTimeout(timer);
  }
}

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

async function callGeminiStream(
  payload: unknown,
): Promise<ReadableStream<Uint8Array> | { error: string; detail: string }> {
  let lastDetail = "";

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    let res: Response | undefined;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), ATTEMPT_TIMEOUT_MS);
    try {
      res = await fetch(`${GEMINI_URL}?alt=sse&key=${GEMINI_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
    } catch (err) {
      lastDetail = `${err}`;
      res = undefined;
    } finally {
      clearTimeout(timer);
    }

    if (res?.ok && res.body) return res.body;

    if (
      attempt < MAX_ATTEMPTS &&
      (res === undefined || RETRYABLE_STATUSES.has(res.status))
    ) {
      if (res) lastDetail = await res.text();
      console.warn(
        `Gemini attempt ${attempt} failed (${res?.status ?? "no response"}), retrying: ${lastDetail.slice(0, 200)}`,
      );
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!GEMINI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Scoped to the caller's own JWT (not the service role), so the rate-limit
  // queries below run under RLS as this specific user.
  const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: "Invalid or expired session" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const userId = userData.user.id;

  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString();
  const { count, error: countError } = await supabase
    .from("food_analysis_requests")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", windowStart);

  if (countError) {
    console.error("Rate limit check failed:", countError);
    return new Response(JSON.stringify({ error: "Failed to check rate limit" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    return new Response(
      JSON.stringify({
        error: "You've hit the hourly limit for meal scans. Try again later.",
      }),
      {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const input = parseAnalyzeBody(body);
  if ("error" in input) {
    return new Response(JSON.stringify({ error: input.error }), {
      status: input.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { error: insertError } = await supabase
    .from("food_analysis_requests")
    .insert({ user_id: userId });
  if (insertError) {
    console.error("Failed to log analysis request:", insertError);
    return new Response(JSON.stringify({ error: "Failed to process request" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const geminiPayload = {
    contents: [
      {
        parts: input.kind === "text"
          ? [{ text: TEXT_PROMPT }, { text: input.text }]
          : [
            { text: PROMPT },
            {
              inline_data: { mime_type: input.mimeType, data: input.image },
            },
          ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };

  const geminiStream = await callGeminiStream(geminiPayload);
  if (!(geminiStream instanceof ReadableStream)) {
    console.error("Gemini API error:", geminiStream.detail);
    return new Response(JSON.stringify(geminiStream), {
      status: 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const scanner = new IncrementalJsonScanner();
  let textBuffer = ""; // accumulated `text` deltas from Gemini's parts
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
          const { done, value } = await readWithStallTimeout(reader);
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

            // deno-lint-ignore no-explicit-any
            const parts = (chunk as any)?.candidates?.[0]?.content?.parts;
            if (!Array.isArray(parts)) continue;

            for (const part of parts) {
              // Thinking-capable models can stream a "thought" (reasoning)
              // part alongside the actual JSON output part. That prose
              // isn't part of the structured response — feeding it into
              // textBuffer lets the incremental scanner below match a
              // stray quote inside it as a fake `meal_name` closing quote,
              // briefly showing garbled text instead of the real name.
              if (part?.thought) continue;
              const delta = part?.text;
              if (typeof delta !== "string") continue;

              textBuffer += delta;
              scanner.scan(
                textBuffer,
                (name) => emit("meal_name", { name }),
                (item) => emit("item", item),
              );
            }
          }
        }

        const parsed = JSON.parse(textBuffer);
        if (!Array.isArray(parsed.items) || parsed.items.length === 0) {
          emit("error", {
            message: input.kind === "text"
              ? "No food was found in that description. Try naming what " +
                "you ate, e.g. '2 eggs and toast'."
              : "No food was detected in this photo. Try again with a " +
                "clearer picture of your meal.",
          });
        } else {
          emit("done", parsed);
        }
      } catch (err) {
        console.error("Streaming analyze-food failed:", err);
        emit("error", {
          message: err instanceof UserFacingError
            ? err.message
            : "Something went wrong analyzing this meal. Try again.",
        });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(outStream, { status: 200, headers: sseHeaders });
});
