import { supabaseAdmin } from "./supabase.js";

export async function appendMemberJoinedMessage(params: {
  serverId: string;
  userId: string;
}): Promise<void> {
  const { data: textChannel, error: textChannelError } = await supabaseAdmin
    .from("channels")
    .select("id")
    .eq("server_id", params.serverId)
    .eq("type", "text")
    .order("created_at", { ascending: true })
    .maybeSingle();

  if (textChannelError) {
    throw new Error(`Failed to find text channel for join event: ${textChannelError.message}`);
  }
  if (!textChannel) {
    return;
  }

  const { data: profile, error: profileError } = await supabaseAdmin
    .from("profiles")
    .select("display_name")
    .eq("id", params.userId)
    .maybeSingle();

  if (profileError) {
    throw new Error(`Failed to load profile for join event: ${profileError.message}`);
  }

  const displayName = (profile?.display_name ?? "").trim();
  const label = displayName.isEmpty ? "Um membro" : displayName;

  const { error: insertError } = await supabaseAdmin.from("messages").insert({
    channel_id: textChannel.id,
    user_id: params.userId,
    content: `${label} entrou no servidor.`
  });

  if (insertError) {
    throw new Error(`Failed to insert join event message: ${insertError.message}`);
  }
}
