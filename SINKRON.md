# Sinkron data antar-perangkat

- Login: email → kode OTP (Supabase Auth). Kode hanya diminta sekali per perangkat; setelah keluar, masuk lagi di perangkat yang sama cukup email.
- Data tiap aplikasi disimpan di tabel `user_data` (satu baris per pembeli per key). RLS: hanya pemilik.
- Foto produk Catat Usaha: Storage bucket `foto-produk/<user_id>/<produk_id>.jpg`.
- **Menambah aplikasi baru?** Tambahkan key localStorage-nya ke `LNS_KEYS` di index.html, dan (kalau datanya dimuat ke variabel memori) ke `memLoaded`/`reloadMem`/`flush` di modul LNS.
- Gabung data: 3 arah per catatan (pakai `id`), yang terakhir diubah menang kalau bentrok; versi yang kalah disimpan di IndexedDB `lnsync` → `backup`.
- SQL: `supabase/01-sinkron.sql` (pasang), `supabase/02-tutup-login-lama.sql` (beberapa hari setelah rilis).
