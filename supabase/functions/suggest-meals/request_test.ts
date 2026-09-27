import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  buildInstructions,
  dataParts,
  normalizeSuggestions,
  parseSuggestBody,
} from "./request.ts";

Deno.test("parses and clamps a request, keeping meal-type order", () => {
  assertEquals(
    parseSuggestBody({
      remaining: { calories: 1234.6, protein: -5, carbs: 99999, fats: 40 },
      mealTypes: ["snack", "dinner", "brunch", "dinner"],
    }),
    {
      remaining: { calories: 1235, protein: 0, carbs: 800, fats: 40 },
      mealTypes: ["dinner", "snack"],
    },
  );
});

Deno.test("rejects missing input or no calories left", () => {
  assertEquals((parseSuggestBody({}) as { status: number }).status, 400);
  assertEquals(
    (parseSuggestBody({
      remaining: { calories: 50 },
      mealTypes: ["dinner"],
    }) as { error: string }).error,
    "You've already hit today's calorie goal.",
  );
  assertEquals(
    (parseSuggestBody({ remaining: { calories: 800 }, mealTypes: [] }) as {
      status: number;
    }).status,
    400,
  );
});

Deno.test("instructions carry the budget; user text stays in data parts", () => {
  const input = {
    remaining: { calories: 900, protein: 60, carbs: 90, fats: 30 },
    mealTypes: ["dinner" as const],
  };
  assertStringIncludes(buildInstructions(input), "900 kcal");
  assertEquals(dataParts("  vegetarian ", []), [
    { text: "Dietary preferences: vegetarian" },
    { text: "Recently logged meals: none yet" },
  ]);
  assertEquals(dataParts(null, ["Oatmeal", "Dal"])[1].text,
    "Recently logged meals: Oatmeal; Dal");
});

Deno.test("normalizes the model's answer to one valid meal per type", () => {
  const out = normalizeSuggestions(
    {
      meals: [
        {
          meal_type: "snack",
          meal_name: " Greek Yogurt ",
          health_score: 14,
          items: [{ food_name: "Yogurt", calories: 150, protein_g: -2 }],
        },
        { meal_type: "dinner", meal_name: "Empty", items: [] },
        { meal_type: "breakfast", meal_name: "Unrequested", items: [{ food_name: "x" }] },
        {
          meal_type: "dinner",
          meal_name: "Dal Rice",
          description: "Comforting.",
          items: [{ food_name: "Dal", calories: 300 }],
        },
      ],
    },
    ["dinner", "snack"],
  );
  assertEquals(out.map((m) => m.meal_type), ["dinner", "snack"]);
  assertEquals(out[1].meal_name, "Greek Yogurt");
  assertEquals(out[1].health_score, 10);
  assertEquals(out[1].items[0].protein_g, 0);
  assertEquals(normalizeSuggestions({ nope: 1 }, ["dinner"]), []);
});
