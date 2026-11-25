-- littles noor · tempat tulisan tangan (pen) per pembeli, privat
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tulisan-tangan', 'tulisan-tangan', false, 1500000, array['application/json'])
on conflict (id) do nothing;
drop policy if exists "tulisan: lihat milik sendiri" on storage.objects;
drop policy if exists "tulisan: unggah milik sendiri" on storage.objects;
drop policy if exists "tulisan: ganti milik sendiri" on storage.objects;
drop policy if exists "tulisan: hapus milik sendiri" on storage.objects;
create policy "tulisan: lihat milik sendiri" on storage.objects for select to authenticated
  using (bucket_id = 'tulisan-tangan' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "tulisan: unggah milik sendiri" on storage.objects for insert to authenticated
  with check (bucket_id = 'tulisan-tangan' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "tulisan: ganti milik sendiri" on storage.objects for update to authenticated
  using (bucket_id = 'tulisan-tangan' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "tulisan: hapus milik sendiri" on storage.objects for delete to authenticated
  using (bucket_id = 'tulisan-tangan' and (storage.foldername(name))[1] = auth.uid()::text);
select 'Tempat tulisan tangan siap ✓' as hasil;
