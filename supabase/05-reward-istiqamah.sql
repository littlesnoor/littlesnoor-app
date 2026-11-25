-- littles noor · reward "istiqamah": hari berturut-turut mengisi aplikasi
-- Hanya mengambil TANGGAL isian (bukan isi tulisan) untuk menghitung hari berturut-turut.
create or replace function public._try_date(x text) returns date
language plpgsql immutable set search_path = public as $$
begin return left(x, 10)::date; exception when others then return null; end $$;

create or replace function public._dates(k text, d jsonb) returns setof date
language sql immutable set search_path = public as $$
  select _try_date(x) from (
    select v as x from jsonb_each_text(case when k = 'mulailagi.v1' and jsonb_typeof(d->'doneAt') = 'object' then d->'doneAt' else '{}'::jsonb end) e(kk, v)
    union all select kk from jsonb_object_keys(case when k = 'planner.v1' and jsonb_typeof(d->'jur') = 'object' then d->'jur' else '{}'::jsonb end) kk
    union all select kk from jsonb_object_keys(case when k = 'majelis.v1' and jsonb_typeof(d->'mut') = 'object' then d->'mut' else '{}'::jsonb end) kk
    union all select e->>'tgl' from jsonb_array_elements(case when k = 'majelis.v1' and jsonb_typeof(d->'notes') = 'array' then d->'notes' else '[]'::jsonb end) e
    union all select e->>'d' from jsonb_array_elements(case when k = 'cukup.v1' and jsonb_typeof(d->'tx') = 'array' then d->'tx' else '[]'::jsonb end) e
    union all select e->>'d' from jsonb_array_elements(case when k = 'catatusaha.v1' and jsonb_typeof(d->'sales') = 'array' then d->'sales' else '[]'::jsonb end) e
  ) t where x ~ '^\d{4}-\d{2}-\d{2}' and _try_date(x) <= (now() at time zone 'Asia/Jakarta')::date + 1
$$;

create or replace function public.admin_rewards() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare today date := (now() at time zone 'Asia/Jakarta')::date;
begin
  if auth.uid() is null or not exists (select 1 from admins where email = _my_email()) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  return jsonb_build_object('ok', true, 'today', today, 'list', (
    with dd as (
      select distinct u.id, lower(u.email) as email, x.dt
      from auth.users u join user_data ud on ud.user_id = u.id
      cross join lateral _dates(ud.k, ud.data) x(dt)
    ), isl as (
      select id, email, dt, dt - (row_number() over (partition by id order by dt))::int as grp from dd
    ), runs as (
      select id, email, min(dt) as s, max(dt) as e, count(*)::int as n from isl group by id, email, grp
    ), agg as (
      select id, email,
        max(n) as terbaik,
        coalesce(max(n) filter (where e >= today - 1), 0) as sekarang,
        coalesce(max(least(e, today) - greatest(s, date_trunc('month', today)::date) + 1) filter (where e >= date_trunc('month', today)::date), 0) as terbaik_bulan_ini
      from runs group by id, email
    ), aktif as (
      select id, count(*) filter (where dt >= date_trunc('month', today)::date and dt <= today)::int as hari_bulan_ini from dd group by id
    )
    select coalesce(jsonb_agg(jsonb_build_object('email', a.email, 'sekarang', a.sekarang, 'terbaik', a.terbaik,
              'terbaik_bulan_ini', a.terbaik_bulan_ini, 'hari_bulan_ini', k.hari_bulan_ini)
            order by a.terbaik_bulan_ini desc, k.hari_bulan_ini desc, a.sekarang desc), '[]'::jsonb)
    from agg a join aktif k on k.id = a.id
  ));
end $$;

revoke execute on function public.admin_rewards() from anon, public;
grant execute on function public.admin_rewards() to authenticated;
revoke execute on function public._dates(text, jsonb), public._try_date(text) from anon, authenticated, public;
select 'Reward istiqamah siap ✓' as hasil;
