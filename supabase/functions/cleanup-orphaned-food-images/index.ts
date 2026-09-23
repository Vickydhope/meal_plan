import { createClient } from "jsr:@supabase/supabase-js@2";

// Not user-facing: invoked only by the `cleanup_orphaned_food_images`
// pg_cron job (see the matching migration), which computes the orphaned
// storage paths in SQL and posts them here to actually delete the objects.
// Raw `delete from storage.objects` only removes the metadata row - it
// does not remove the underlying bytes from the storage backend, so the
// real deletion has to go through the Storage API (which `.remove()`
// below does), not a SQL statement.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const CRON_SECRET = Deno.env.get("CRON_SECRET");

const BUCKET = "food-images";
// Matches the bulk-delete endpoint's own cap.
const MAX_PATHS_PER_REQUEST = 1000;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!CRON_SECRET || req.headers.get("x-cron-secret") !== CRON_SECRET) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let paths: unknown;
  try {
    ({ paths } = await req.json());
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (
    !Array.isArray(paths) ||
    paths.length === 0 ||
    !paths.every((p) => typeof p === "string")
  ) {
    return new Response(
      JSON.stringify({ error: "'paths' must be a non-empty string array" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
  if (paths.length > MAX_PATHS_PER_REQUEST) {
    return new Response(
      JSON.stringify({
        error: `'paths' exceeds the ${MAX_PATHS_PER_REQUEST}-item limit per request`,
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);

  const { data, error } = await supabase.storage.from(BUCKET).remove(paths);
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ requested: paths.length, deleted: data?.length ?? 0 }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
