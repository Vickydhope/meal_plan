// Client compresses to <200KB JPEG; this is a generous server-side ceiling
// independent of that, not the expected steady-state size.
export const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
export const MAX_TEXT_CHARS = 500;

export type AnalyzeInput =
  | { kind: "image"; image: string; mimeType: string }
  | { kind: "text"; text: string };

/** Validates an analyze-food request body: a base64 `image` or a `text`
 * description of the meal. Returns the input or an HTTP error. */
export function parseAnalyzeBody(
  body: unknown,
): AnalyzeInput | { status: number; error: string } {
  const { image, mimeType, text } = (body ?? {}) as Record<string, unknown>;

  if (typeof text === "string") {
    const trimmed = text.trim();
    if (!trimmed) return { status: 400, error: "Describe what you ate." };
    if (trimmed.length > MAX_TEXT_CHARS) {
      return { status: 413, error: "That description is too long." };
    }
    return { kind: "text", text: trimmed };
  }

  if (!image || typeof image !== "string") {
    return {
      status: 400,
      error: "Missing 'image' (base64 string) or 'text' in body",
    };
  }
  // Base64 encodes 3 bytes as 4 chars, so decoded size ~= length * 0.75.
  if (image.length * 0.75 > MAX_IMAGE_BYTES) {
    return { status: 413, error: "Image payload too large" };
  }
  return {
    kind: "image",
    image,
    mimeType: typeof mimeType === "string" ? mimeType : "image/jpeg",
  };
}
