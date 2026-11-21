-- littles noor · Dashboard admin
-- Menampilkan PROGRES pembeli (angka saja), BUKAN isi tulisan mereka.
-- Aman dijalankan ulang. Jalankan di Supabase > SQL Editor.

-- ========== 1. Daftar email admin ==========
create table if not exists public.admins(email text primary key);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;
-- email yang kamu pakai untuk masuk ke app.littlesnoor.com (ganti/tambah kalau beda)
insert into public.admins(email) values ('littlesnoor@gmail.com') on conflict do nothing;

-- ========== 2. Penghitung kecil (hanya menghitung, tidak membaca isi) ==========
create or replace function public._n_keys(j jsonb) returns int
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(j) = 'object' then (select count(*)::int from jsonb_object_keys(j)) else 0 end
$$;
create or replace function public._n_true(j jsonb) returns int
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(j) = 'object'
    then (select count(*)::int from jsonb_each(j) e where e.value = 'true'::jsonb) else 0 end
$$;
create or replace function public._n_arr(j jsonb) returns int
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(j) = 'array' then jsonb_array_length(j) else 0 end
$$;

-- angka progres per aplikasi
create or replace function public._progress(k text, d jsonb) returns jsonb
language sql immutable set search_path = public as $$
  select case k
    when 'mulailagi.v1'  then jsonb_build_object('hari', _n_true(d->'done'))
    when 'planner.v1'    then jsonb_build_object('jurnal', _n_keys(d->'jur'), 'juz', _n_true(d->'ram'->'juz'))
    when 'majelis.v1'    then jsonb_build_object('catatan', _n_arr(d->'notes'), 'mutabaah', _n_keys(d->'mut'))
    when 'cukup.v1'      then jsonb_build_object('transaksi', _n_arr(d->'tx'))
    when 'catatusaha.v1' then jsonb_build_object('nota', _n_arr(d->'sales'), 'produk', _n_arr(d->'prod'))
    else '{}'::jsonb end
$$;

-- ========== 3. Data dashboard (hanya untuk email di tabel admins) ==========
create or replace function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or not exists (select 1 from admins where email = _my_email()) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  return jsonb_build_object(
    'ok', true,
    'now', now(),
    'products', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'color', color) order by sort), '[]'::jsonb) from products),
    'users', (
      with b as (select lower(email) as email, jsonb_agg(distinct product) as owned from buyers group by lower(email)),
           u as (select id, lower(email) as email, created_at, last_sign_in_at from auth.users),
           dv as (select lower(email) as email, count(*)::int as n from devices group by lower(email))
      select coalesce(jsonb_agg(jsonb_build_object(
        'email', b.email,
        'owned', b.owned,
        'akun', u.id is not null,
        'daftar', u.created_at,
        'login_terakhir', u.last_sign_in_at,
        'perangkat', coalesce(dv.n, 0),
        'aktif_terakhir', (select max(x.updated_at) from user_data x where x.user_id = u.id),
        'progres', (select coalesce(jsonb_object_agg(x.k, jsonb_build_object('at', x.updated_at, 'n', _progress(x.k, x.data))), '{}'::jsonb)
                    from user_data x where x.user_id = u.id
                      and x.k in ('mulailagi.v1','planner.v1','majelis.v1','cukup.v1','catatusaha.v1'))
      ) order by (select max(x.updated_at) from user_data x where x.user_id = u.id) desc nulls last, b.email), '[]'::jsonb)
      from b left join u on u.email = b.email left join dv on dv.email = b.email
    )
  );
end $$;

revoke execute on function public.admin_dashboard() from anon, public;
grant execute on function public.admin_dashboard() to authenticated;
revoke execute on function public._progress(text, jsonb), public._n_keys(jsonb), public._n_true(jsonb), public._n_arr(jsonb) from anon, authenticated, public;

-- ========== 4. Email admin boleh masuk walau bukan pembeli ==========
create or replace function public.hook_only_buyers(event jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(event -> 'user' ->> 'email'));
begin
  if exists (select 1 from buyers where email = e) or exists (select 1 from admins where email = e) then
    return '{}'::jsonb; end if;
  return jsonb_build_object('error', jsonb_build_object('http_code', 403,
    'message', 'Email ini belum terdaftar sebagai pembeli littles noor.'));
end $$;
grant execute on function public.hook_only_buyers(jsonb) to supabase_auth_admin;
grant select on public.admins to supabase_auth_admin;

select 'Dashboard admin siap ✓  Buka app.littlesnoor.com/admin/' as hasil;
