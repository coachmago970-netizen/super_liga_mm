create or replace function public.enforce_message_antispam()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  if char_length(trim(new.content)) = 0 then
    raise exception 'Message content cannot be empty.';
  end if;

  select count(*)
  into recent_count
  from public.messages m
  where m.user_id = new.user_id
    and m.created_at > (now() - interval '1 minute');

  if recent_count >= 10 then
    raise exception 'Rate limit exceeded: max 10 messages per minute.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_messages_antispam on public.messages;
create trigger trg_messages_antispam
before insert on public.messages
for each row
execute function public.enforce_message_antispam();
