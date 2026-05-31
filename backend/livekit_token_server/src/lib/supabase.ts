import { createClient } from "@supabase/supabase-js";
import WebSocket from "ws";
import { env } from "./env.js";

if (typeof globalThis.WebSocket === "undefined") {
  globalThis.WebSocket = WebSocket as unknown as typeof globalThis.WebSocket;
}

export const supabaseAdmin = createClient(env.SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});
