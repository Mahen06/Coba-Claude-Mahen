-- ============================================================
-- BALOK ERP — Skema Supabase (PostgreSQL)
-- Jalankan file ini di Supabase Dashboard → SQL Editor → New Query → Run
-- Aman dijalankan ulang (pakai IF NOT EXISTS / DROP ... IF EXISTS di beberapa bagian)
-- ============================================================

-- ------------------------------------------------------------
-- 0. Ekstensi yang dibutuhkan
-- ------------------------------------------------------------
create extension if not exists "pgcrypto"; -- untuk gen_random_uuid()

-- ------------------------------------------------------------
-- 1. Tabel profil pengguna (menempel ke auth.users bawaan Supabase)
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  role text not null check (role in ('Manager','Engineering','Logistik','Finance')),
  created_at timestamptz not null default now()
);

-- Helper: ambil role user yang sedang login (dipakai di banyak RLS policy)
create or replace function public.current_role()
returns text
language sql
security definer
stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ------------------------------------------------------------
-- 2. Master data
-- ------------------------------------------------------------
create table if not exists public.master_barang (
  kode text primary key,
  nama text not null unique,
  kategori text not null check (kategori in ('Material','Alat')),
  satuan text not null,
  stok_min numeric not null default 0 check (stok_min >= 0),
  keterangan text default '',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.master_lokasi (
  kode text primary key,
  nama text not null unique,
  pic text default '',
  status text not null default 'Aktif' check (status in ('Aktif','Selesai')),
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.master_vendor (
  kode text primary key,
  nama text not null unique,
  pic text default '',
  telp text default '',
  alamat text default '',
  kategori text default '',
  rating int not null default 3 check (rating between 1 and 5),
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. Transaksi stok
-- ------------------------------------------------------------
create table if not exists public.material_masuk (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  kode_barang text not null references public.master_barang(kode),
  dari text default '',
  lokasi text not null references public.master_lokasi(nama),
  qty numeric not null check (qty > 0),
  no_ref text default '',
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.material_keluar (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  kode_barang text not null references public.master_barang(kode),
  lokasi text not null references public.master_lokasi(nama),
  qty numeric not null check (qty > 0),
  no_ref text default '',
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.mutasi (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  kode_barang text not null references public.master_barang(kode),
  dari_lokasi text not null references public.master_lokasi(nama),
  ke_lokasi text not null references public.master_lokasi(nama),
  qty numeric not null check (qty > 0),
  jenis_mutasi text default '',
  no_ref text default '',
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint mutasi_lokasi_beda check (dari_lokasi <> ke_lokasi)
);

-- ------------------------------------------------------------
-- 4. Harga vendor
-- ------------------------------------------------------------
create table if not exists public.harga_vendor (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  kode_barang text not null references public.master_barang(kode),
  kode_vendor text not null references public.master_vendor(kode),
  harga numeric not null check (harga > 0),
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5. Progress proyek (Engineering)
-- ------------------------------------------------------------
create table if not exists public.progress_proyek (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  lokasi_proyek text not null references public.master_lokasi(nama),
  persen_progress numeric not null check (persen_progress between 0 and 100),
  tahap text default '',
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 6. Anggaran proyek (Engineering input, khusus Manager & Engineering yang bisa lihat)
-- ------------------------------------------------------------
create table if not exists public.anggaran_proyek (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  lokasi_proyek text not null references public.master_lokasi(nama),
  anggaran_total numeric not null check (anggaran_total > 0),
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 7. Skema termin pembayaran (Finance)
-- ------------------------------------------------------------
create table if not exists public.termin_pembayaran (
  id uuid primary key default gen_random_uuid(),
  lokasi_proyek text not null references public.master_lokasi(nama),
  nama_termin text not null,
  persen_pembayaran numeric not null check (persen_pembayaran > 0 and persen_pembayaran <= 100),
  progress_minimum numeric not null check (progress_minimum between 0 and 100),
  sudah_ditagih boolean not null default false,
  sudah_terbayar boolean not null default false,
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint termin_bayar_perlu_tagih check (not sudah_terbayar or sudah_ditagih)
);

-- ------------------------------------------------------------
-- 8. Addendum / pekerjaan tambah (Engineering, Finance, Manager)
-- ------------------------------------------------------------
create table if not exists public.addendum_proyek (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null default current_date,
  lokasi_proyek text not null references public.master_lokasi(nama),
  deskripsi_pekerjaan text not null,
  kode_barang text references public.master_barang(kode),
  qty_material numeric default 0 check (qty_material >= 0),
  nilai_addendum numeric not null check (nilai_addendum > 0),
  sudah_terbayar boolean not null default false,
  pic text default '',
  keterangan text default '',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 9. Audit log — mencatat semua INSERT/UPDATE/DELETE di tabel-tabel di atas
-- ------------------------------------------------------------
create table if not exists public.audit_log (
  id bigserial primary key,
  table_name text not null,
  record_id text not null,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  old_data jsonb,
  new_data jsonb,
  changed_by uuid references public.profiles(id),
  changed_at timestamptz not null default now()
);

create or replace function public.audit_trigger_func()
returns trigger
language plpgsql
security definer
as $$
declare
  rec_id text;
begin
  if (tg_op = 'DELETE') then
    rec_id := coalesce(old.id::text, old.kode::text);
    insert into public.audit_log(table_name, record_id, action, old_data, changed_by)
      values (tg_table_name, rec_id, tg_op, to_jsonb(old), auth.uid());
    return old;
  elsif (tg_op = 'UPDATE') then
    rec_id := coalesce(new.id::text, new.kode::text);
    insert into public.audit_log(table_name, record_id, action, old_data, new_data, changed_by)
      values (tg_table_name, rec_id, tg_op, to_jsonb(old), to_jsonb(new), auth.uid());
    return new;
  else
    rec_id := coalesce(new.id::text, new.kode::text);
    insert into public.audit_log(table_name, record_id, action, new_data, changed_by)
      values (tg_table_name, rec_id, tg_op, to_jsonb(new), auth.uid());
    return new;
  end if;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'master_barang','master_lokasi','master_vendor',
    'material_masuk','material_keluar','mutasi','harga_vendor',
    'progress_proyek','anggaran_proyek','termin_pembayaran','addendum_proyek'
  ]
  loop
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$s', t);
    execute format(
      'create trigger trg_audit_%1$s after insert or update or delete on public.%1$s
       for each row execute function public.audit_trigger_func()', t
    );
  end loop;
end $$;

-- ------------------------------------------------------------
-- 10. updated_at otomatis
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['master_barang','master_lokasi','master_vendor','termin_pembayaran','addendum_proyek']
  loop
    execute format('drop trigger if exists trg_updated_at_%1$s on public.%1$s', t);
    execute format(
      'create trigger trg_updated_at_%1$s before update on public.%1$s
       for each row execute function public.set_updated_at()', t
    );
  end loop;
end $$;

-- ============================================================
-- 11. Row Level Security (RLS)
-- ============================================================
alter table public.profiles enable row level security;
alter table public.master_barang enable row level security;
alter table public.master_lokasi enable row level security;
alter table public.master_vendor enable row level security;
alter table public.material_masuk enable row level security;
alter table public.material_keluar enable row level security;
alter table public.mutasi enable row level security;
alter table public.harga_vendor enable row level security;
alter table public.progress_proyek enable row level security;
alter table public.anggaran_proyek enable row level security;
alter table public.termin_pembayaran enable row level security;
alter table public.addendum_proyek enable row level security;
alter table public.audit_log enable row level security;

-- profiles: semua user login boleh lihat semua profil (untuk tampilkan nama PIC dsb), tidak boleh ubah punya orang lain
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (auth.role() = 'authenticated');
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update using (id = auth.uid());

-- master_barang: semua boleh lihat; input hanya Manager & Logistik
drop policy if exists barang_select on public.master_barang;
create policy barang_select on public.master_barang for select using (auth.role() = 'authenticated');
drop policy if exists barang_insert on public.master_barang;
create policy barang_insert on public.master_barang for insert with check (public.current_role() in ('Manager','Logistik'));
drop policy if exists barang_update on public.master_barang;
create policy barang_update on public.master_barang for update using (public.current_role() in ('Manager','Logistik'));

-- master_lokasi: semua boleh lihat; input hanya Manager & Engineering
drop policy if exists lokasi_select on public.master_lokasi;
create policy lokasi_select on public.master_lokasi for select using (auth.role() = 'authenticated');
drop policy if exists lokasi_insert on public.master_lokasi;
create policy lokasi_insert on public.master_lokasi for insert with check (public.current_role() in ('Manager','Engineering'));
drop policy if exists lokasi_update on public.master_lokasi;
create policy lokasi_update on public.master_lokasi for update using (public.current_role() in ('Manager','Engineering'));

-- master_vendor: semua boleh lihat; input Manager, Engineering, Logistik
drop policy if exists vendor_select on public.master_vendor;
create policy vendor_select on public.master_vendor for select using (auth.role() = 'authenticated');
drop policy if exists vendor_insert on public.master_vendor;
create policy vendor_insert on public.master_vendor for insert with check (public.current_role() in ('Manager','Engineering','Logistik'));
drop policy if exists vendor_update on public.master_vendor;
create policy vendor_update on public.master_vendor for update using (public.current_role() in ('Manager','Engineering','Logistik'));

-- material_masuk / material_keluar / mutasi: semua boleh lihat; input Manager & Logistik
drop policy if exists masuk_select on public.material_masuk;
create policy masuk_select on public.material_masuk for select using (auth.role() = 'authenticated');
drop policy if exists masuk_insert on public.material_masuk;
create policy masuk_insert on public.material_masuk for insert with check (public.current_role() in ('Manager','Logistik'));

drop policy if exists keluar_select on public.material_keluar;
create policy keluar_select on public.material_keluar for select using (auth.role() = 'authenticated');
drop policy if exists keluar_insert on public.material_keluar;
create policy keluar_insert on public.material_keluar for insert with check (public.current_role() in ('Manager','Logistik'));

drop policy if exists mutasi_select on public.mutasi;
create policy mutasi_select on public.mutasi for select using (auth.role() = 'authenticated');
drop policy if exists mutasi_insert on public.mutasi;
create policy mutasi_insert on public.mutasi for insert with check (public.current_role() in ('Manager','Logistik'));

-- harga_vendor: semua boleh lihat; input Manager & Finance
drop policy if exists harga_select on public.harga_vendor;
create policy harga_select on public.harga_vendor for select using (auth.role() = 'authenticated');
drop policy if exists harga_insert on public.harga_vendor;
create policy harga_insert on public.harga_vendor for insert with check (public.current_role() in ('Manager','Finance'));

-- progress_proyek: semua boleh lihat; input Manager & Engineering
drop policy if exists progress_select on public.progress_proyek;
create policy progress_select on public.progress_proyek for select using (auth.role() = 'authenticated');
drop policy if exists progress_insert on public.progress_proyek;
create policy progress_insert on public.progress_proyek for insert with check (public.current_role() in ('Manager','Engineering'));

-- anggaran_proyek: HANYA Manager & Engineering yang boleh lihat maupun input (sesuai permintaan)
drop policy if exists anggaran_select on public.anggaran_proyek;
create policy anggaran_select on public.anggaran_proyek for select using (public.current_role() in ('Manager','Engineering'));
drop policy if exists anggaran_insert on public.anggaran_proyek;
create policy anggaran_insert on public.anggaran_proyek for insert with check (public.current_role() in ('Manager','Engineering'));

-- termin_pembayaran: semua boleh lihat (untuk notice dashboard); input & update status Manager & Finance
drop policy if exists termin_select on public.termin_pembayaran;
create policy termin_select on public.termin_pembayaran for select using (auth.role() = 'authenticated');
drop policy if exists termin_insert on public.termin_pembayaran;
create policy termin_insert on public.termin_pembayaran for insert with check (public.current_role() in ('Manager','Finance'));
drop policy if exists termin_update on public.termin_pembayaran;
create policy termin_update on public.termin_pembayaran for update using (public.current_role() in ('Manager','Finance'));

-- addendum_proyek: HANYA Manager, Finance, Engineering yang boleh lihat/input/update (Logistik dikecualikan)
drop policy if exists addendum_select on public.addendum_proyek;
create policy addendum_select on public.addendum_proyek for select using (public.current_role() in ('Manager','Finance','Engineering'));
drop policy if exists addendum_insert on public.addendum_proyek;
create policy addendum_insert on public.addendum_proyek for insert with check (public.current_role() in ('Manager','Finance','Engineering'));
drop policy if exists addendum_update on public.addendum_proyek;
create policy addendum_update on public.addendum_proyek for update using (public.current_role() in ('Manager','Finance','Engineering'));

-- audit_log: hanya Manager yang boleh membaca; tidak ada yang boleh insert/update/delete langsung dari client
drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select using (public.current_role() = 'Manager');

-- ============================================================
-- 12. Data contoh (opsional) — hapus/skip bagian ini kalau tidak mau seed data demo
-- Jalankan HANYA SETELAH kamu membuat minimal 1 akun user & profil (lihat SETUP.md)
-- karena kolom created_by butuh id user yang valid. Kalau mau skip, cukup tidak
-- menjalankan blok di bawah ini — aplikasi tetap jalan normal dengan tabel kosong.
-- ============================================================
-- insert into public.master_lokasi (kode, nama, pic, status) values
--   ('LOK-001','Gudang Pusat','Rina','Aktif'),
--   ('LOK-002','Proyek Villa Karang','Dedi','Aktif'),
--   ('LOK-003','Proyek Ruko Balikpapan','Sinta','Aktif');
