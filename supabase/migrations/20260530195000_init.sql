create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  role text not null default 'member' check (role in ('owner', 'admin', 'moderator', 'member')),
  is_banned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.servers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.server_members (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'moderator', 'member')),
  joined_at timestamptz not null default now(),
  invited_by uuid references auth.users(id) on delete set null,
  unique(server_id, user_id)
);

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  name text not null,
  type text not null check (type in ('text', 'voice')),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) <= 2000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);

create table if not exists public.voice_sessions (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  livekit_room text not null,
  joined_at timestamptz not null default now(),
  left_at timestamptz
);

create table if not exists public.bans (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  banned_by uuid not null references auth.users(id) on delete restrict,
  reason text,
  created_at timestamptz not null default now(),
  unique(server_id, user_id)
);

create table if not exists public.mutes (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  muted_by uuid not null references auth.users(id) on delete restrict,
  reason text,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  server_id uuid not null references public.servers(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz,
  max_uses integer check (max_uses is null or max_uses > 0),
  current_uses integer not null default 0 check (current_uses >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.invite_uses (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  used_at timestamptz not null default now(),
  ip_hash text,
  user_agent_hash text
);

create table if not exists public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete restrict,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_server_members_user_id on public.server_members(user_id);
create index if not exists idx_server_members_server_id on public.server_members(server_id);
create index if not exists idx_channels_server_id on public.channels(server_id);
create index if not exists idx_messages_channel_created on public.messages(channel_id, created_at desc);
create index if not exists idx_messages_user_id on public.messages(user_id);
create index if not exists idx_voice_sessions_server_id on public.voice_sessions(server_id);
create index if not exists idx_bans_server_user on public.bans(server_id, user_id);
create index if not exists idx_mutes_server_user on public.mutes(server_id, user_id);
create index if not exists idx_invites_server_id on public.invites(server_id);
create index if not exists idx_invite_uses_invite_id on public.invite_uses(invite_id);
create index if not exists idx_admin_logs_server_created on public.admin_logs(server_id, created_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_touch_updated_at on public.profiles;
create trigger trg_profiles_touch_updated_at
before update on public.profiles
for each row
execute function public.touch_updated_at();

create or replace function public.server_role_for_user(p_server_id uuid, p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select sm.role
  from public.server_members sm
  where sm.server_id = p_server_id and sm.user_id = p_user_id
  limit 1;
$$;

create or replace function public.is_server_member(p_server_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.server_members sm
    where sm.server_id = p_server_id and sm.user_id = p_user_id
  );
$$;

create or replace function public.is_server_mod_plus(p_server_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.server_members sm
    where sm.server_id = p_server_id
      and sm.user_id = p_user_id
      and sm.role in ('owner', 'admin', 'moderator')
  );
$$;

create or replace function public.is_server_admin_or_owner(p_server_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.server_members sm
    where sm.server_id = p_server_id
      and sm.user_id = p_user_id
      and sm.role in ('owner', 'admin')
  );
$$;

create or replace function public.is_banned_in_server(p_server_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.bans b
    where b.server_id = p_server_id and b.user_id = p_user_id
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = p_user_id and p.is_banned = true
  );
$$;

alter table public.profiles enable row level security;
alter table public.servers enable row level security;
alter table public.server_members enable row level security;
alter table public.channels enable row level security;
alter table public.messages enable row level security;
alter table public.voice_sessions enable row level security;
alter table public.bans enable row level security;
alter table public.mutes enable row level security;
alter table public.invites enable row level security;
alter table public.invite_uses enable row level security;
alter table public.admin_logs enable row level security;

drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self
on public.profiles
for insert
to authenticated
with check (id = auth.uid() and role = 'member' and is_banned = false);

drop policy if exists profiles_update_self_safe on public.profiles;
create policy profiles_update_self_safe
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and role = (select p.role from public.profiles p where p.id = auth.uid())
  and is_banned = (select p.is_banned from public.profiles p where p.id = auth.uid())
);

drop policy if exists servers_select_members on public.servers;
create policy servers_select_members
on public.servers
for select
to authenticated
using (public.is_server_member(id));

drop policy if exists servers_admin_write on public.servers;
create policy servers_admin_write
on public.servers
for all
to authenticated
using (public.is_server_admin_or_owner(id))
with check (public.is_server_admin_or_owner(id));

drop policy if exists channels_select_members on public.channels;
create policy channels_select_members
on public.channels
for select
to authenticated
using (public.is_server_member(server_id));

drop policy if exists channels_admin_write on public.channels;
create policy channels_admin_write
on public.channels
for all
to authenticated
using (public.is_server_admin_or_owner(server_id))
with check (public.is_server_admin_or_owner(server_id));

drop policy if exists server_members_select_members on public.server_members;
create policy server_members_select_members
on public.server_members
for select
to authenticated
using (public.is_server_member(server_id));

drop policy if exists server_members_admin_write on public.server_members;
create policy server_members_admin_write
on public.server_members
for all
to authenticated
using (public.is_server_admin_or_owner(server_id))
with check (public.is_server_admin_or_owner(server_id));

drop policy if exists messages_select_members on public.messages;
create policy messages_select_members
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.channels c
    where c.id = channel_id and public.is_server_member(c.server_id)
  )
);

drop policy if exists messages_insert_member_only on public.messages;
create policy messages_insert_member_only
on public.messages
for insert
to authenticated
with check (
  user_id = auth.uid()
  and char_length(content) <= 2000
  and exists (
    select 1
    from public.channels c
    where c.id = channel_id
      and public.is_server_member(c.server_id)
      and not public.is_banned_in_server(c.server_id)
  )
);

drop policy if exists messages_update_own_only on public.messages;
create policy messages_update_own_only
on public.messages
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and char_length(content) <= 2000);

drop policy if exists messages_delete_none on public.messages;
create policy messages_delete_none
on public.messages
for delete
to authenticated
using (false);

drop policy if exists voice_sessions_select_members on public.voice_sessions;
create policy voice_sessions_select_members
on public.voice_sessions
for select
to authenticated
using (public.is_server_member(server_id));

drop policy if exists voice_sessions_insert_member on public.voice_sessions;
create policy voice_sessions_insert_member
on public.voice_sessions
for insert
to authenticated
with check (user_id = auth.uid() and public.is_server_member(server_id));

drop policy if exists voice_sessions_update_own on public.voice_sessions;
create policy voice_sessions_update_own
on public.voice_sessions
for update
to authenticated
using (user_id = auth.uid() and public.is_server_member(server_id))
with check (user_id = auth.uid() and public.is_server_member(server_id));

drop policy if exists bans_select_mod_plus on public.bans;
create policy bans_select_mod_plus
on public.bans
for select
to authenticated
using (public.is_server_mod_plus(server_id));

drop policy if exists bans_admin_write on public.bans;
create policy bans_admin_write
on public.bans
for all
to authenticated
using (public.is_server_admin_or_owner(server_id))
with check (public.is_server_admin_or_owner(server_id));

drop policy if exists mutes_select_mod_plus on public.mutes;
create policy mutes_select_mod_plus
on public.mutes
for select
to authenticated
using (public.is_server_mod_plus(server_id));

drop policy if exists mutes_mod_plus_write on public.mutes;
create policy mutes_mod_plus_write
on public.mutes
for all
to authenticated
using (public.is_server_mod_plus(server_id))
with check (public.is_server_mod_plus(server_id));

drop policy if exists invites_admin_select on public.invites;
create policy invites_admin_select
on public.invites
for select
to authenticated
using (public.is_server_admin_or_owner(server_id));

drop policy if exists invites_admin_write on public.invites;
create policy invites_admin_write
on public.invites
for all
to authenticated
using (public.is_server_admin_or_owner(server_id))
with check (public.is_server_admin_or_owner(server_id));

drop policy if exists invite_uses_admin_read on public.invite_uses;
create policy invite_uses_admin_read
on public.invite_uses
for select
to authenticated
using (
  exists (
    select 1
    from public.invites i
    where i.id = invite_id and public.is_server_admin_or_owner(i.server_id)
  )
);

drop policy if exists invite_uses_admin_insert on public.invite_uses;
create policy invite_uses_admin_insert
on public.invite_uses
for insert
to authenticated
with check (
  exists (
    select 1
    from public.invites i
    where i.id = invite_id and public.is_server_admin_or_owner(i.server_id)
  )
);

drop policy if exists admin_logs_admin_read on public.admin_logs;
create policy admin_logs_admin_read
on public.admin_logs
for select
to authenticated
using (public.is_server_admin_or_owner(server_id));

drop policy if exists admin_logs_mod_plus_insert on public.admin_logs;
create policy admin_logs_mod_plus_insert
on public.admin_logs
for insert
to authenticated
with check (public.is_server_mod_plus(server_id) and actor_id = auth.uid());
