-- littles noor · langkah terakhir (jalankan beberapa hari SETELAH versi login-kode rilis)
-- Menutup cara masuk lama yang cukup pakai email. Setelah ini, isi workbook hanya bisa diambil akun yang sudah masuk pakai kode.
revoke execute on function public.login(text, text) from anon, authenticated, public;
revoke execute on function public.get_content(text, text, text) from anon, authenticated, public;
revoke execute on function public.activate(text, text, text) from anon, authenticated, public;
select 'Login lama sudah ditutup ✓' as hasil;
