-- ============================================================
-- Seeds · Objetivos por comercial — agregar a la base existente
-- Ejecutar en: Supabase Studio → SQL Editor → New query → Run
-- (Es un agregado al schema.sql que ya corriste. No borra nada.)
-- ============================================================

create table if not exists public.objectives (
  id              uuid primary key default gen_random_uuid(),
  comercial_name  text not null,
  quarter         text not null,              -- ej. '2026-Q3'
  target_existing numeric not null default 0, -- nuevas ventas en cuentas existentes (TCV, US$)
  target_logos    numeric not null default 0, -- nuevas ventas en logos nuevos (TCV, US$)
  target_nrr      numeric not null default 0, -- NRR objetivo: revenue del Q de la cartera, SIN logos (US$)
  updated_by      uuid references auth.users(id),
  updated_at      timestamptz not null default now(),
  unique (comercial_name, quarter)
);

alter table public.objectives enable row level security;

-- Lectura: el admin ve todo; el comercial ve solo el objetivo de su cartera.
drop policy if exists obj_select on public.objectives;
create policy obj_select on public.objectives for select
  using (public.is_admin() or comercial_name = public.current_comercial());

-- Escritura (alta y edición): SOLO el admin. El comercial no puede cambiar sus metas.
drop policy if exists obj_admin_write on public.objectives;
create policy obj_admin_write on public.objectives for all
  using (public.is_admin()) with check (public.is_admin());
