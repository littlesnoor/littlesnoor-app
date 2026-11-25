-- littles noor · tambahan dashboard admin: penjualan, masukan pembeli, pemakaian fitur
-- Hanya angka & masukan yang memang dikirim pembeli lewat kotak saran. Isi tulisan pembeli tidak dibaca.
create or replace function public.admin_extra() returns jsonb
language plpgsql stable security definer set search_path = public, storage as $$
begin
  if auth.uid() is null or not exists (select 1 from admins where email = _my_email()) then
    return jsonb_build_object('ok', false, 'reason', 'not_admin');
  end if;
  return jsonb_build_object('ok', true,
    -- satu baris per produk yang dibeli (email + produk + waktu)
    'sales', (select coalesce(jsonb_agg(jsonb_build_object('email', lower(email), 'product', product, 'at', created_at) order by created_at desc), '[]'::jsonb)
              from buyers where created_at > now() - interval '120 days'),
    'feedback', (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'at', created_at, 'email', email, 'kind', kind, 'msg', message, 'ctx', context, 'done', done) order by created_at desc), '[]'::jsonb)
                 from (select * from feedback order by created_at desc limit 100) f),
    'fitur', jsonb_build_object(
      'akun_sinkron', (select count(distinct user_id) from user_data),
      'tulisan_tangan', (select count(*) from storage.objects where bucket_id = 'tulisan-tangan'),
      'penulis_tangan', (select count(distinct (storage.foldername(name))[1]) from storage.objects where bucket_id = 'tulisan-tangan'),
      'foto_produk', (select count(*) from storage.objects where bucket_id = 'foto-produk'),
      'perangkat', (select count(*) from devices)
    ));
end $$;

create or replace function public.admin_feedback_done(p_id bigint, p_done boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not exists (select 1 from admins where email = _my_email()) then
    return jsonb_build_object('ok', false); end if;
  update feedback set done = p_done where id = p_id;
  return jsonb_build_object('ok', true);
end $$;

revoke execute on function public.admin_extra(), public.admin_feedback_done(bigint, boolean) from anon, public;
grant execute on function public.admin_extra(), public.admin_feedback_done(bigint, boolean) to authenticated;
select 'Tambahan dashboard siap ✓' as hasil;
