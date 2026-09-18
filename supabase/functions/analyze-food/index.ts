import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent";

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    meal_name: { type: "string" },
    health_score: { type: "number" },
    total_calories: { type: "number" },
    total_protein_g: { type: "number" },
    total_carbs_g: { type: "number" },
    total_fats_g: { type: "number" },
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
  },
  required: [
    "meal_name",
    "health_score",
    "total_calories",
    "total_protein_g",
    "total_carbs_g",
    "total_fats_g",
    "items",
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
  "realistic estimates even if uncertain.";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!GEMINI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  let body: { image?: string; mimeType?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { image, mimeType } = body;
  if (!image || typeof image !== "string") {
    return new Response(
      JSON.stringify({ error: "Missing 'image' (base64 string) in body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const geminiPayload = {
    contents: [
      {
        parts: [
          { text: PROMPT },
          {
            inline_data: {
              mime_type: mimeType ?? "image/jpeg",
              data: image,
            },
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };

  const RETRYABLE_STATUSES = new Set([429, 503]);
  const MAX_ATTEMPTS = 5;

  let geminiRes: Response | undefined;
  let lastDetail = "";

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      geminiRes = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(geminiPayload),
      });
    } catch (err) {
      lastDetail = `${err}`;
      geminiRes = undefined;
    }

    if (geminiRes?.ok) break;

    if (
      attempt < MAX_ATTEMPTS &&
      (geminiRes === undefined || RETRYABLE_STATUSES.has(geminiRes.status))
    ) {
      if (geminiRes) lastDetail = await geminiRes.text();
      await new Promise((resolve) =>
        setTimeout(resolve, 1000 * 2 ** (attempt - 1)),
      );
      continue;
    }

    if (geminiRes) lastDetail = await geminiRes.text();
    break;
  }

  if (!geminiRes?.ok) {
    console.error("Gemini API error:", geminiRes?.status, lastDetail);
    return new Response(
      JSON.stringify({ error: "Gemini API error", detail: lastDetail }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  const geminiJson = await geminiRes.json();
  const rawText = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!rawText || typeof rawText !== "string") {
    return new Response(
      JSON.stringify({ error: "Gemini returned no analyzable content" }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    return new Response(
      JSON.stringify({ error: "Gemini output was not valid JSON", raw: rawText }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify(parsed), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
