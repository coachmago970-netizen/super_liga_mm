insert into public.servers (id, name, slug)
values (
  '00000000-0000-0000-0000-000000000100',
  'Super Liga M&M',
  'super-liga-mm'
)
on conflict (slug) do nothing;

insert into public.channels (id, server_id, name, type)
values
  (
    '00000000-0000-0000-0000-000000000200',
    '00000000-0000-0000-0000-000000000100',
    'geral',
    'text'
  ),
  (
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000100',
    'voz',
    'voice'
  )
on conflict do nothing;
