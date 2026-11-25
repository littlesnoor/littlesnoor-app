-- littles noor · pesan dari admin ke pembeli (muncul di aplikasi pembeli)
create table if not exists public.messages(
  id bigserial primary key,
  email text not null,
  title text not null,
  body text not null,
  kind text default 'ucapan',
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists messages_email_idx on public.messages(lower(email));
alter table public.messages enable row level security;
revoke all on public.messages from anon, authenticated;

-- admin mengirim pesan ke satu pembeli
create or replace function public.admin_send_message(p_email text, p_title text, p_body text, p_kind text default 'ucapan')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not exists (select 1 from admins where email = _my_email()) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin'); end if;
  if coalesce(trim(p_email), '') = '' or coalesce(trim(p_body), '') = '' then
    return jsonb_build_object('ok', false, 'reason', 'kosong'); end if;
  insert into messages(email, title, body, kind)
  values (lower(trim(p_email)), left(coalesce(nullif(trim(p_title), ''), 'Pesan dari littles noor'), 120), left(p_body, 4000), left(coalesce(p_kind, 'ucapan'), 20));
  return jsonb_build_object('ok', true);
end $$;

-- admin melihat pesan yang sudah dikirim ke seorang pembeli
create or replace function public.admin_messages(p_email text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or not exists (select 1 from admins where email = _my_email()) then
    return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'title', title, 'at', created_at, 'read', read_at) order by created_at desc), '[]'::jsonb)
          from messages where email = lower(trim(p_email)));
end $$;

-- pembeli membaca pesannya sendiri
create or replace function public.my_messages() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'title', title, 'body', body, 'kind', kind, 'at', created_at, 'read', read_at is not null) order by created_at desc), '[]'::jsonb)
  from (select * from messages where email = _my_email() and auth.uid() is not null order by created_at desc limit 50) m
$$;

create or replace function public.read_message(p_id bigint) returns jsonb
language sql security definer set search_path = public as $$
  update messages set read_at = coalesce(read_at, now()) where id = p_id and email = _my_email() and auth.uid() is not null;
  select jsonb_build_object('ok', true);
$$;

revoke execute on function public.admin_send_message(text, text, text, text), public.admin_messages(text), public.my_messages(), public.read_message(bigint) from anon, public;
grant execute on function public.admin_send_message(text, text, text, text), public.admin_messages(text), public.my_messages(), public.read_message(bigint) to authenticated;
select 'Pesan untuk pembeli siap ✓' as hasil;
