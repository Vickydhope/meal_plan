import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  buildInstructions,
  dataParts,
  MEAL_TYPES,
  normalizeSuggestions,
  parseSuggestBody,
  type Suggestion,
} from "./request.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

const RATE_LIMIT_MAX_REQUESTS = 10;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const RECENT_MEALS_DAYS = 30;
const RECENT_MEALS_MAX = 15;

const RETRYABLE_STATUSES = new Set([429, 503]);
const MAX_ATTEMPTS = 3;
const ATTEMPT_TIMEOUT_MS = 30_000;

const ITEM_SCHEMA = {
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
};

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    meals: {
      type: "array",
      items: {
        type: "object",
        properties: {
          meal_type: { type: "string", enum: [...MEAL_TYPES] },
          meal_name: { type: "string" },
          description: { type: "string" },
          health_score: { type: "number" },
          items: { type: "array", items: ITEM_SCHEMA },
        },
        required: [
          "meal_type",
          "meal_name",
          "description",
          "health_score",
          "items",
        ],
      },
    },
  },
  required: ["meals"],
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Calls Gemini, retrying 429/503/timeouts with backoff. Returns the
 * response's JSON text, or null if every attempt failed. */
async function callGemini(payload: unknown): Promise<string | null> {
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), ATTEMPT_TIMEOUT_MS);
    let res: Response | undefined;
    try {
      res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      if (res.ok) {
        const data = await res.json();
        // deno-lint-ignore no-explicit-any
        const parts: any[] = data?.candidates?.[0]?.content?.parts ?? [];
        // Skip "thought" parts from thinking-capable models.
        return parts.filter((p) => !p?.thought && typeof p?.text === "string")
          .map((p) => p.text).join("");
      }
    } catch (err) {
      console.warn(`Gemini attempt ${attempt} threw: ${err}`);
      res = undefined;
    } finally {
      clearTimeout(timer);
    }
    const retryable = res === undefined || RETRYABLE_STATUSES.has(res.status);
    if (res) {
      console.warn(
        `Gemini attempt ${attempt} failed (${res.status}): ${
          (await res.text()).slice(0, 200)
        }`,
      );
    }
    if (!retryable || attempt === MAX_ATTEMPTS) return null;
    await new Promise((r) => setTimeout(r, 1000 * 2 ** (attempt - 1)));
  }
  return null;
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

  // Scoped to the caller's own JWT, so every query runs under RLS as them.
  const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "Invalid or expired session" });
  }
  const userId = userData.user.id;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "Invalid JSON body" });
  }
  const input = parseSuggestBody(body);
  if ("error" in input) return jsonResponse(input.status, { error: input.error });

  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MS).toISOString();
  const { count, error: countError } = await supabase
    .from("meal_suggestion_requests")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", windowStart);
  if (countError) {
    console.error("Rate limit check failed:", countError);
    return jsonResponse(500, { error: "Failed to check rate limit" });
  }
  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    return jsonResponse(429, {
      error: "You've hit the hourly limit for meal ideas. Try again later.",
    });
  }

  const since = new Date(
    Date.now() - RECENT_MEALS_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();
  const [{ data: profile }, { data: logs }] = await Promise.all([
    supabase.from("profiles").select("diet_notes").eq("id", userId)
      .maybeSingle(),
    supabase.from("meal_logs").select("meal_name")
      .eq("user_id", userId).is("deleted_at", null).gte("created_at", since)
      .order("created_at", { ascending: false }).limit(100),
  ]);
  const recentMeals = [
    ...new Set(
      (logs ?? []).map((l) => (l.meal_name as string | null)?.trim())
        .filter((n): n is string => !!n),
    ),
  ].slice(0, RECENT_MEALS_MAX);

  const { error: insertError } = await supabase
    .from("meal_suggestion_requests")
    .insert({ user_id: userId });
  if (insertError) {
    console.error("Failed to log suggestion request:", insertError);
    return jsonResponse(500, { error: "Failed to process request" });
  }

  const text = await callGemini({
    contents: [
      {
        parts: [
          { text: buildInstructions(input) },
          ...dataParts(profile?.diet_notes ?? null, recentMeals),
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  });
  if (text === null) {
    return jsonResponse(502, {
      error: "The AI service isn't responding. Try again in a moment.",
    });
  }

  let meals: Suggestion[];
  try {
    meals = normalizeSuggestions(JSON.parse(text), input.mealTypes);
  } catch (err) {
    console.error("Unparseable suggestion response:", err, text.slice(0, 300));
    meals = [];
  }
  if (meals.length === 0) {
    return jsonResponse(502, {
      error: "Couldn't come up with meal ideas. Try again.",
    });
  }
  return jsonResponse(200, { meals });
});
