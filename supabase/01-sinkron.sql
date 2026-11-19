-- littles noor · langkah 1: login aman (OTP) + sinkron data + foto
-- Aman dijalankan ulang. Tidak mengubah tabel/fungsi lama yang sedang dipakai aplikasi.

-- ========== 1. Tabel data sinkron (satu baris per pembeli per aplikasi) ==========
create table if not exists public.user_data(
  user_id uuid not null references auth.users(id) on delete cascade,
  k text not null check (k ~ '^[a-z0-9._-]{1,40}$'),
  data jsonb not null,
  rev bigint not null default 1,
  updated_at timestamptz not null default now(),
  primary key (user_id, k)
);
alter table public.user_data enable row level security;
drop policy if exists "baca data sendiri" on public.user_data;
create policy "baca data sendiri" on public.user_data
  for select to authenticated using (user_id = auth.uid());
-- Menulis hanya lewat fungsi sync_put di bawah (yang tetap memeriksa pemiliknya).
revoke insert, update, delete on public.user_data from anon, authenticated;
revoke all on public.user_data from anon;

-- email akun yang sedang login (dari token)
create or replace function public._my_email() returns text
language sql stable set search_path = public as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- ========== 2. Fungsi sinkron ==========
-- daftar versi tiap aplikasi milik pembeli ini (kecil, dipanggil sering)
create or replace function public.sync_revs() returns jsonb
language sql stable security invoker set search_path = public as $$
  select coalesce(jsonb_object_agg(k, jsonb_build_object('rev', rev, 'at', updated_at)), '{}'::jsonb)
  from user_data where user_id = auth.uid()
$$;

-- ambil isi beberapa aplikasi
create or replace function public.sync_get(p_keys text[]) returns jsonb
language sql stable security invoker set search_path = public as $$
  select coalesce(jsonb_object_agg(k, jsonb_build_object('rev', rev, 'at', updated_at, 'data', data)), '{}'::jsonb)
  from user_data where user_id = auth.uid() and k = any(p_keys)
$$;

-- simpan isi satu aplikasi. p_base = versi yang terakhir dilihat perangkat ini.
-- Kalau server sudah lebih baru, ditolak dengan 'conflict' + isi terbaru, lalu aplikasi menggabungkan.
create or replace function public.sync_put(p_k text, p_data jsonb, p_base bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); r bigint; d jsonb; t timestamptz;
begin
  if u is null then return jsonb_build_object('ok', false, 'reason', 'auth'); end if;
  if not exists (select 1 from buyers where email = _my_email()) then
    return jsonb_build_object('ok', false, 'reason', 'not_buyer'); end if;
  if p_k !~ '^[a-z0-9._-]{1,40}$' or p_data is null or pg_column_size(p_data) > 4000000 then
    return jsonb_build_object('ok', false, 'reason', 'invalid'); end if;
  select rev into r from user_data where user_id = u and k = p_k for update;
  if r is null then
    insert into user_data(user_id, k, data) values (u, p_k, p_data) on conflict do nothing;
    if found then return jsonb_build_object('ok', true, 'rev', 1, 'at', now()); end if;
    select rev, data, updated_at into r, d, t from user_data where user_id = u and k = p_k;
    return jsonb_build_object('ok', false, 'reason', 'conflict', 'rev', r, 'data', d, 'at', t);
  end if;
  if r <> coalesce(p_base, 0) then
    select data, updated_at into d, t from user_data where user_id = u and k = p_k;
    return jsonb_build_object('ok', false, 'reason', 'conflict', 'rev', r, 'data', d, 'at', t);
  end if;
  update user_data set data = p_data, rev = r + 1, updated_at = now() where user_id = u and k = p_k;
  return jsonb_build_object('ok', true, 'rev', r + 1, 'at', now());
end $$;

-- ========== 3. Login versi aman (pakai token dari kode OTP, bukan email saja) ==========
-- cek apakah email terdaftar sebagai pembeli, sebelum kode dikirim
create or replace function public.buyer_status(p_email text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('ok', exists(select 1 from buyers where email = lower(trim(p_email))))
$$;

-- sama seperti login lama, tapi email diambil dari akun yang sudah terverifikasi
create or replace function public.me(p_device text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e text := _my_email(); m int; n int;
begin
  if auth.uid() is null or e = '' then return jsonb_build_object('ok', false, 'reason', 'auth'); end if;
  select max(max_devices) into m from buyers where email = e;
  if m is null then return jsonb_build_object('ok', false, 'reason', 'not_buyer'); end if;
  if not exists (select 1 from devices where email = e and device_id = p_device) then
    select count(*) into n from devices where email = e;
    if n >= m then return jsonb_build_object('ok', false, 'reason', 'device_limit'); end if;
    insert into devices(email, device_id) values (e, p_device);
  end if;
  return jsonb_build_object('ok', true, 'email', e,
    'owned', (select coalesce(jsonb_agg(product), '[]'::jsonb) from buyers where email = e),
    'products', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'tagline',tagline,'color',color,'live',live,'category',category) order by sort), '[]'::jsonb) from products));
end $$;

create or replace function public.my_content(p_device text, p_product text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e text := _my_email();
begin
  if auth.uid() is null
     or not exists (select 1 from devices where email = e and device_id = p_device)
     or not exists (select 1 from buyers where email = e and product = p_product) then
    return jsonb_build_object('ok', false, 'reason', 'no_access'); end if;
  return jsonb_build_object('ok', true, 'data', (select data from content where id = p_product));
end $$;

revoke execute on function public.sync_put(text, jsonb, bigint), public.me(text),
  public.my_content(text, text), public.sync_revs(), public.sync_get(text[]) from anon, public;
grant execute on function public.sync_put(text, jsonb, bigint), public.me(text),
  public.my_content(text, text), public.sync_revs(), public.sync_get(text[]) to authenticated;
grant execute on function public.buyer_status(text) to anon, authenticated;

-- ========== 4. Hanya email pembeli yang bisa dibuatkan akun ==========
-- (dipasang di Authentication > Hooks > "Before User Created")
create or replace function public.hook_only_buyers(event jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from buyers where email = lower(trim(event -> 'user' ->> 'email'))) then
    return '{}'::jsonb; end if;
  return jsonb_build_object('error', jsonb_build_object('http_code', 403,
    'message', 'Email ini belum terdaftar sebagai pembeli littles noor.'));
end $$;
grant execute on function public.hook_only_buyers(jsonb) to supabase_auth_admin;
revoke execute on function public.hook_only_buyers(jsonb) from anon, authenticated, public;
grant select on public.buyers to supabase_auth_admin;

-- ========== 5. Tempat foto produk Catat Usaha (privat, per pembeli) ==========
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('foto-produk', 'foto-produk', false, 300000, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists "foto: lihat milik sendiri" on storage.objects;
drop policy if exists "foto: unggah milik sendiri" on storage.objects;
drop policy if exists "foto: ganti milik sendiri" on storage.objects;
drop policy if exists "foto: hapus milik sendiri" on storage.objects;
create policy "foto: lihat milik sendiri" on storage.objects for select to authenticated
  using (bucket_id = 'foto-produk' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "foto: unggah milik sendiri" on storage.objects for insert to authenticated
  with check (bucket_id = 'foto-produk' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "foto: ganti milik sendiri" on storage.objects for update to authenticated
  using (bucket_id = 'foto-produk' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "foto: hapus milik sendiri" on storage.objects for delete to authenticated
  using (bucket_id = 'foto-produk' and (storage.foldername(name))[1] = auth.uid()::text);

select 'Langkah 1 selesai ✓' as hasil;
