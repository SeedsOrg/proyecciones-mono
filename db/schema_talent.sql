-- ============================================================
-- Seeds · Rol "talent" (solo lectura) — agregar a la base existente
-- Ejecutar en: Supabase Studio → SQL Editor → New query → Run
-- Permite usuarios de Talent que VEN todo pero no editan nada.
-- ============================================================

-- 1) Permitir el rol 'talent' en la tabla de perfiles
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('comercial','admin','talent'));

-- 2) Helper: ¿es staff (admin o talent)? -> pueden LEER todo
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role in ('admin','talent') from public.profiles where id = auth.uid()), false);
$$;

-- 3) Lectura ampliada a staff (admin + talent), escritura SIN cambios
--    (talent puede leer proyecciones y objetivos de todas las carteras, pero no escribir)
drop policy if exists proj_select on public.projections;
create policy proj_select on public.projections for select
  using (public.is_staff() or comercial_name = public.current_comercial());

drop policy if exists obj_select on public.objectives;
create policy obj_select on public.objectives for select
  using (public.is_staff() or comercial_name = public.current_comercial());

-- Nota: las políticas de escritura (insert/update) NO se tocan.
-- talent no es admin ni tiene comercial_name, así que no puede modificar nada.

-- ============================================================
-- Dar de alta al usuario de Talent (después de que entró una vez):
-- ============================================================
-- update public.profiles set role='talent', comercial_name=null
--   where email='talent@weareseeds.com';
