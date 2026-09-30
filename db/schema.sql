-- ============================================================
-- Seeds · Motor de Proyección de Ventas — Esquema de producción
-- Base: Supabase (Postgres)
-- Ejecutar en: Supabase Studio → SQL Editor → New query → Run
-- ============================================================
-- IMPORTANTE: este esquema asume que la data es CONFIDENCIAL.
-- Toda la seguridad se apoya en Row Level Security (RLS).
-- Nunca se debe usar la service_role key en el frontend.
-- ============================================================

-- ---------- 1. PERFILES DE USUARIO ----------
-- Cada usuario logueado se mapea a un comercial y un rol.
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text,
  full_name     text,
  role          text not null default 'comercial' check (role in ('comercial','admin')),
  comercial_name text,            -- debe coincidir EXACTO con las claves del mapeo OWNERS de la app
  created_at    timestamptz not null default now()
);

-- ---------- 2. PROYECCIONES ----------
-- Una fila por comercial y trimestre. El detalle (nuevos, extensiones,
-- meta) se guarda como JSON para no acoplar el esquema a la UI.
create table if not exists public.projections (
  id             uuid primary key default gen_random_uuid(),
  comercial_name text not null,
  quarter        text not null,                 -- ej. '2026-Q3'
  growth_pct     numeric not null default 15,
  payload        jsonb  not null default '{}'::jsonb,  -- { newLines:[...], unchecked:{}, prob:{} }
  updated_by     uuid references auth.users(id),
  updated_at     timestamptz not null default now(),
  unique (comercial_name, quarter)
);

-- ---------- 3. SNAPSHOTS DE REVENUE (opcional, Fase 1.5) ----------
-- Persiste el export de Power BI ya parseado, para que el consolidado
-- del admin no dependa de re-subir el CSV cada vez.
create table if not exists public.revenue_snapshots (
  id             uuid primary key default gen_random_uuid(),
  quarter        text not null,
  months         jsonb not null,                -- ['2025-01', ...]
  contracts      jsonb not null,                -- filas parseadas
  uploaded_by    uuid references auth.users(id),
  created_at     timestamptz not null default now(),
  unique (quarter)
);

-- ============================================================
-- FUNCIONES AUXILIARES (security definer para evitar recursión de RLS)
-- ============================================================
create or replace function public.current_role_name()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_comercial()
returns text language sql stable security definer set search_path = public as $$
  select comercial_name from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false);
$$;

-- ============================================================
-- TRIGGER: crear perfil automáticamente al registrarse
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles          enable row level security;
alter table public.projections        enable row level security;
alter table public.revenue_snapshots  enable row level security;

-- ----- profiles -----
-- Cada uno ve su propio perfil; el admin ve todos.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_admin());

-- Solo el admin puede cambiar roles / asignar comercial_name.
drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles for update
  using (public.is_admin()) with check (public.is_admin());

-- ----- projections -----
-- Lectura: el admin ve todo; el comercial solo su cartera.
drop policy if exists proj_select on public.projections;
create policy proj_select on public.projections for select
  using (public.is_admin() or comercial_name = public.current_comercial());

-- Alta: el comercial solo puede crear filas de SU cartera; el admin, cualquiera.
drop policy if exists proj_insert on public.projections;
create policy proj_insert on public.projections for insert
  with check (public.is_admin() or comercial_name = public.current_comercial());

-- Edición: idem.
drop policy if exists proj_update on public.projections;
create policy proj_update on public.projections for update
  using (public.is_admin() or comercial_name = public.current_comercial())
  with check (public.is_admin() or comercial_name = public.current_comercial());

-- ----- revenue_snapshots -----
-- Lectura para cualquier usuario autenticado (la app filtra por cartera en cliente).
-- Escritura: solo admin (quien sube el export maestro de Power BI).
drop policy if exists rev_select on public.revenue_snapshots;
create policy rev_select on public.revenue_snapshots for select
  using (auth.uid() is not null);

drop policy if exists rev_admin_write on public.revenue_snapshots;
create policy rev_admin_write on public.revenue_snapshots for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
-- BOOTSTRAP DEL ADMIN (ejecutar UNA vez, después del primer login)
-- Reemplazá el email por el del Head of Sales.
-- ============================================================
-- update public.profiles
--   set role = 'admin', comercial_name = 'Jose María Imaz (Mono)'
--   where email = 'jose.imaz@weareseeders.com';

-- ============================================================
-- ASIGNACIÓN DE COMERCIALES (ejecutar tras crear cada usuario)
-- comercial_name DEBE coincidir con las claves del objeto OWNERS de la app.
-- ============================================================
-- update public.profiles set comercial_name = 'Tomi Barale'      where email = 'tomi@weareseeders.com';
-- update public.profiles set comercial_name = 'Camila Jordan'    where email = 'camila@weareseeders.com';
-- update public.profiles set comercial_name = 'Benjamin Miguens' where email = 'benjamin@weareseeders.com';
-- update public.profiles set comercial_name = 'Pedro Uriarte'    where email = 'pedro@weareseeders.com';
-- update public.profiles set comercial_name = 'Teresa Cirio'     where email = 'teresa@weareseeders.com';
