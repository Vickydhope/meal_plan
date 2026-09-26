import { assertEquals } from "jsr:@std/assert@1";
import { MAX_TEXT_CHARS, parseAnalyzeBody } from "./request_body.ts";

Deno.test("text input is trimmed", () => {
  assertEquals(parseAnalyzeBody({ text: "  2 eggs and toast \n" }), {
    kind: "text",
    text: "2 eggs and toast",
  });
});

Deno.test("blank or oversized text is rejected", () => {
  assertEquals(parseAnalyzeBody({ text: "   " }), {
    status: 400,
    error: "Describe what you ate.",
  });
  assertEquals(
    (parseAnalyzeBody({ text: "a".repeat(MAX_TEXT_CHARS + 1) }) as {
      status: number;
    }).status,
    413,
  );
});

Deno.test("image input defaults its mime type", () => {
  assertEquals(parseAnalyzeBody({ image: "abcd" }), {
    kind: "image",
    image: "abcd",
    mimeType: "image/jpeg",
  });
});

Deno.test("missing input and oversized images are rejected", () => {
  assertEquals((parseAnalyzeBody({}) as { status: number }).status, 400);
  assertEquals((parseAnalyzeBody(null) as { status: number }).status, 400);
  assertEquals(
    (parseAnalyzeBody({ image: "a".repeat(3 * 1024 * 1024) }) as {
      status: number;
    }).status,
    413,
  );
});
