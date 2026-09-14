-- ============================================================
--  Línea de mates — ejercicio de Teoría de las Restricciones
--  Esquema + permisos para Supabase
--
--  Pegá TODO este archivo en el SQL Editor de tu proyecto
--  Supabase y ejecutalo una sola vez.
--  Después editá el bloque del final para cargar tu mail
--  y el de los alumnos.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tablas
-- ------------------------------------------------------------

-- Quién puede entrar. Si un mail no está acá, la persona puede
-- iniciar sesión pero no ve absolutamente nada.
create table if not exists public.members (
  email      text primary key,
  is_admin   boolean not null default false,
  nota       text,
  created_at timestamptz not null default now()
);

-- Los seis equipos. "dice" es una matriz 5x5:
-- dice[estacion][vuelta], con null donde todavía no se cargó nada.
create table if not exists public.teams (
  id         text primary key,
  dice       jsonb not null,
  updated_at timestamptz not null default now()
);

-- Qué ve el curso. Una sola fila, id = 'ui'.
create table if not exists public.config (
  id         text primary key,
  stats      boolean not null default true,
  chart      boolean not null default true,
  dev        boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. Filas iniciales
-- ------------------------------------------------------------

insert into public.teams (id, dice)
select t.id,
       '[[null,null,null,null,null],
         [null,null,null,null,null],
         [null,null,null,null,null],
         [null,null,null,null,null],
         [null,null,null,null,null]]'::jsonb
from (values ('e1'),('e2'),('e3'),('e4'),('e5'),('e6')) as t(id)
on conflict (id) do nothing;

insert into public.config (id) values ('ui')
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 3. Funciones de permiso
--    security definer: leen members sin quedar atrapadas en
--    las propias políticas de members.
-- ------------------------------------------------------------

create or replace function public.is_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.members m
    where m.email = lower(auth.jwt() ->> 'email')
  );
$$;

create or replace function public.is_course_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.members m
    where m.email = lower(auth.jwt() ->> 'email')
      and m.is_admin
  );
$$;

-- ------------------------------------------------------------
-- 4. Row Level Security
--    Sin política = prohibido. No hay INSERT ni DELETE para
--    nadie desde la página: las filas ya existen y solo se
--    actualizan.
-- ------------------------------------------------------------

alter table public.members enable row level security;
alter table public.teams   enable row level security;
alter table public.config  enable row level security;

drop policy if exists "members: ve su propia fila" on public.members;
create policy "members: ve su propia fila"
  on public.members for select to authenticated
  using (email = lower(auth.jwt() ->> 'email'));

drop policy if exists "teams: lee cualquier miembro" on public.teams;
create policy "teams: lee cualquier miembro"
  on public.teams for select to authenticated
  using (public.is_member());

drop policy if exists "teams: escribe cualquier miembro" on public.teams;
create policy "teams: escribe cualquier miembro"
  on public.teams for update to authenticated
  using (public.is_member())
  with check (public.is_member());

drop policy if exists "config: lee cualquier miembro" on public.config;
create policy "config: lee cualquier miembro"
  on public.config for select to authenticated
  using (public.is_member());

drop policy if exists "config: escribe solo admin" on public.config;
create policy "config: escribe solo admin"
  on public.config for update to authenticated
  using (public.is_course_admin())
  with check (public.is_course_admin());

-- ------------------------------------------------------------
-- 5. Realtime
--    replica identity full hace que el evento de UPDATE viaje
--    con todas las columnas, no solo la clave.
-- ------------------------------------------------------------

alter table public.teams  replica identity full;
alter table public.config replica identity full;

do $$ begin
  alter publication supabase_realtime add table public.teams;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.config;
exception when duplicate_object then null;
end $$;

-- ============================================================
-- 6. TU LISTA DE GENTE  ← editá esto
--
--    Todos los mails en minúscula.
--    is_admin = true  → ve la pestaña Admin y puede ocultar
--                       las estadísticas.
--    is_admin = false → carga dados y nada más.
--
--    Podés volver a correr solo este bloque cada vez que
--    sumes o saques a alguien.
-- ============================================================

insert into public.members (email, is_admin, nota) values
  ('cambiame@tumail.com', true,  'docente')
  -- ('alumno1@ejemplo.com', false, 'Equipo 1'),
  -- ('alumno2@ejemplo.com', false, 'Equipo 1'),
  -- ('alumno3@ejemplo.com', false, 'Equipo 2'),
on conflict (email) do update
  set is_admin = excluded.is_admin,
      nota     = excluded.nota;

-- Para sacar a alguien:
--   delete from public.members where email = 'alguien@ejemplo.com';

-- Para ver la lista:
--   select email, is_admin, nota from public.members order by email;
