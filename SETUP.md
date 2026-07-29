# Setup Supabase untuk Balok ERP

Panduan ini untuk menghubungkan `index.html` ke database Supabase sungguhan
(menggantikan `window.storage` yang hanya jalan di dalam Claude).

## 1. Buat project Supabase
1. Buka https://supabase.com → Sign up / Login → **New Project**.
2. Catat **Database Password** yang kamu buat (simpan baik-baik).
3. Tunggu project selesai provisioning (~2 menit).

## 2. Jalankan skema database
1. Di dashboard project → menu **SQL Editor** → **New query**.
2. Buka file `supabase_schema.sql`, copy semua isinya, paste ke editor.
3. Klik **Run**. Harus muncul "Success. No rows returned".
4. Ini membuat semua tabel, aturan keamanan (RLS), dan pencatatan audit log.

## 3. Buat akun untuk tiap anggota tim

Aplikasi ini login pakai **username** (bukan email penuh) — di baliknya otomatis
ditambahkan domain `@balokerp.local` sebelum dikirim ke Supabase (karena Supabase
Auth memang mewajibkan format email). Domain ini sudah diset di `index.html`
lewat variabel `LOGIN_DOMAIN` — jangan diubah kecuali kamu juga mengubahnya di sini.

1. Menu **Authentication** → **Users** → **Add user** → **Create new user**.
2. Buat 4 akun berikut persis seperti ini (centang **Auto Confirm User** supaya
   tidak perlu verifikasi email, karena domainnya memang bukan email sungguhan):

   | Email (wajib diisi persis) | Password | Nama tampilan | Role |
   |---|---|---|---|
   | `mahen@balokerp.local` | `mahen123` | Mahen | Manager |
   | `edo@balokerp.local` | `edo123` | Edo | Logistik |
   | `naufal@balokerp.local` | `naufal123` | Naufal | Engineering |
   | `anisa@balokerp.local` | `anisa123` | Anisa | Finance |

3. Setelah keempat user dibuat, buka **SQL Editor**, jalankan query berikut untuk
   mengisi nama & role mereka (klik tiap user di halaman Authentication → Users
   untuk menyalin **UID**-nya, tempel di query ini menggantikan placeholder):

```sql
insert into public.profiles (id, nama, role) values
  ('uid-punya-mahen', 'Mahen',  'Manager'),
  ('uid-punya-edo',   'Edo',    'Logistik'),
  ('uid-punya-naufal','Naufal', 'Engineering'),
  ('uid-punya-anisa', 'Anisa',  'Finance');
```

Setelah ini, tiap orang bisa login di aplikasi cukup dengan:
- Username: `mahen` (tanpa @domain) — Password: `mahen123` — dst untuk yang lain.

**Catatan keamanan:** password contoh di atas sengaja sederhana untuk memudahkan
setup awal. Sangat disarankan tiap orang menggantinya lewat menu Authentication
→ Users → (pilih user) → **Reset password**, terutama sebelum dipakai dengan
data proyek/klien sungguhan.

Kalau nanti ada anggota tim baru, ulangi langkah 1-3 dengan username baru.

## 4. Ambil URL & Anon Key
1. Menu **Project Settings** (ikon gear) → **API**.
2. Copy **Project URL** dan **anon public key**.

## 5. Pasang ke index.html
Buka `index.html`, cari baris di paling atas `<script>`:

```js
var SUPABASE_URL = "GANTI_DENGAN_PROJECT_URL_KAMU";
var SUPABASE_ANON_KEY = "GANTI_DENGAN_ANON_KEY_KAMU";
```

Ganti dengan nilai dari langkah 4.

## 6. (Opsional) Isi data awal
Kalau mau mulai dengan data contoh (material, lokasi, vendor demo), lihat bagian
paling bawah `supabase_schema.sql` — aktifkan/jalankan manual setelah profil user dibuat.
Kalau tidak, aplikasi tetap jalan normal dengan tabel kosong — tinggal isi lewat UI.

## 7. Deploy
Setelah `SUPABASE_URL` dan `SUPABASE_ANON_KEY` terisi, `index.html` bisa langsung
di-deploy ke Vercel (atau hosting statis apa pun) — data akan otomatis tersimpan
permanen dan tersinkron real-time ke semua anggota tim yang login.

## Catatan keamanan
- **Jangan pernah** memasukkan *service_role key* ke dalam file `index.html` —
  hanya pakai **anon public key**. Keamanan sesungguhnya dijaga oleh RLS
  (Row Level Security) di database, bukan oleh kunci ini.
- Kalau ada anggota tim keluar/resign, hapus usernya dari **Authentication → Users**
  supaya login lama tidak bisa dipakai lagi.
- Semua perubahan data (tambah/ubah/hapus) otomatis tercatat di tabel `audit_log`,
  bisa dilihat lewat SQL Editor (`select * from audit_log order by changed_at desc`)
  — hanya bisa diakses oleh akun ber-role Manager.
