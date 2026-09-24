import { assertEquals } from "jsr:@std/assert@1";
import { IncrementalJsonScanner } from "./json_scanner.ts";

/** Feeds [chunks] one delta at a time, as the edge function does. */
function feed(chunks: string[]) {
  const scanner = new IncrementalJsonScanner();
  const names: string[] = [];
  const items: Record<string, unknown>[] = [];
  let buffer = "";
  for (const chunk of chunks) {
    buffer += chunk;
    scanner.scan(buffer, (n) => names.push(n), (i) => items.push(i));
  }
  return { names, items };
}

/** Splits [text] into fixed-size deltas to simulate streaming. */
function chunked(text: string, size: number): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i += size) out.push(text.slice(i, i + size));
  return out;
}

const doc = JSON.stringify({
  meal_name: 'Chicken "Special" Bowl',
  items: [
    { food_name: "Chicken {grilled}", calories: 250 },
    { food_name: "Rice ]", calories: 130 },
  ],
  health_score: 7,
  total_calories: 380,
});

Deno.test("emits the meal name once, unescaped", () => {
  const { names } = feed(chunked(doc, 3));
  assertEquals(names, ['Chicken "Special" Bowl']);
});

Deno.test("emits each item exactly once, in order, across any chunking", () => {
  for (const size of [1, 2, 7, 50, doc.length]) {
    const { items } = feed(chunked(doc, size));
    assertEquals(items, [
      { food_name: "Chicken {grilled}", calories: 250 },
      { food_name: "Rice ]", calories: 130 },
    ], `chunk size ${size}`);
  }
});

Deno.test("does not emit a partially streamed item", () => {
  const { items } = feed(['{"meal_name":"X","items":[{"food_name":"Ri']);
  assertEquals(items, []);
});

Deno.test("ignores objects nested inside an item", () => {
  const { items } = feed([
    '{"items":[{"food_name":"A","meta":{"x":1}},{"food_name":"B"}]}',
  ]);
  assertEquals(items, [
    { food_name: "A", meta: { x: 1 } },
    { food_name: "B" },
  ]);
});

Deno.test("emits nothing for an empty items array", () => {
  const { names, items } = feed(['{"meal_name":"No food detected","items":[]}']);
  assertEquals(names, ["No food detected"]);
  assertEquals(items, []);
});
