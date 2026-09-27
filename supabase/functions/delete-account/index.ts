import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

// Deletes the calling user's account: their Storage files first (Storage
// won't delete a user who still owns objects, and a SQL delete would leave
// the bytes behind), then the auth user, which cascades to every table.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// Both buckets store files under `<userId>/`.
const BUCKETS = ["food-images", "avatars"];
const PAGE_SIZE = 1000;

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function deleteUserFiles(admin: SupabaseClient, userId: string) {
  for (const bucket of BUCKETS) {
    while (true) {
      const { data, error } = await admin.storage
        .from(bucket)
        .list(userId, { limit: PAGE_SIZE });
      if (error) throw error;
      if (data.length === 0) break;
      const { error: removeError } = await admin.storage
        .from(bucket)
        .remove(data.map((file) => `${userId}/${file.name}`));
      if (removeError) throw removeError;
    }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(401, { error: "Missing Authorization header" });
  }
  const caller = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse(401, { error: "Invalid or expired session" });
  }
  const userId = userData.user.id;

  const admin = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!);
  try {
    await deleteUserFiles(admin, userId);
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  } catch (err) {
    console.error("delete-account failed", userId, err);
    return jsonResponse(500, {
      error: "Couldn't delete your account. Please try again.",
    });
  }
  return jsonResponse(200, { deleted: true });
});
