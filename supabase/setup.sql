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
  team       text,
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
  cmp        boolean not null default false,
  foot       boolean not null default true,
  lede       boolean not null default true,
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
-- 2b. Migración para proyectos que ya existían
--     Todo es "if not exists": correr el archivo entero de nuevo
--     sobre un proyecto viejo no rompe ni pisa datos.
-- ------------------------------------------------------------

alter table public.members add column if not exists team text;
alter table public.config  add column if not exists cmp  boolean not null default false;
alter table public.config  add column if not exists foot boolean not null default true;
alter table public.config  add column if not exists lede boolean not null default true;

-- La clave foránea va acá y no en el create table porque members
-- se crea antes que teams.
do $$ begin
  alter table public.members
    add constraint members_team_fkey
    foreign key (team) references public.teams(id);
exception when duplicate_object then null;
end $$;

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

-- Qué equipo tiene asignado quien está pidiendo. null = ninguno,
-- y entonces puede escribir en cualquiera, como era antes.
create or replace function public.my_team()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select m.team from public.members m
  where m.email = lower(auth.jwt() ->> 'email');
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

drop policy if exists "members: el admin ve a todos" on public.members;
create policy "members: el admin ve a todos"
  on public.members for select to authenticated
  using (public.is_course_admin());

-- El admin puede editar members para asignar equipos. Postgres no
-- restringe por columna en RLS: el docente puede tocar toda la fila,
-- incluido is_admin. Es la misma confianza que ya tiene.
drop policy if exists "members: el admin asigna equipo" on public.members;
create policy "members: el admin asigna equipo"
  on public.members for update to authenticated
  using (public.is_course_admin())
  with check (public.is_course_admin());

drop policy if exists "teams: lee cualquier miembro" on public.teams;
create policy "teams: lee cualquier miembro"
  on public.teams for select to authenticated
  using (public.is_member());

-- Escritura: el admin toca cualquier equipo; quien tiene equipo
-- asignado solo el suyo; quien no tiene asignación, cualquiera.
-- El bloqueo vive acá y no solo en la página, así que esconder una
-- pestaña con la consola del navegador no alcanza para escribir.
drop policy if exists "teams: escribe cualquier miembro" on public.teams;
drop policy if exists "teams: escribe su equipo" on public.teams;
create policy "teams: escribe su equipo"
  on public.teams for update to authenticated
  using (
    public.is_member() and (
      public.is_course_admin()
      or public.my_team() is null
      or public.my_team() = id
    )
  )
  with check (
    public.is_member() and (
      public.is_course_admin()
      or public.my_team() is null
      or public.my_team() = id
    )
  );

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

alter table public.teams   replica identity full;
alter table public.config  replica identity full;
alter table public.members replica identity full;

do $$ begin
  alter publication supabase_realtime add table public.teams;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.config;
exception when duplicate_object then null;
end $$;

-- members también: así, cuando el docente asigna un equipo, al alumno
-- se le aplica en el momento sin recargar. Realtime respeta RLS, con lo
-- cual cada alumno recibe solo su propia fila.
do $$ begin
  alter publication supabase_realtime add table public.members;
exception when duplicate_object then null;
end $$;

-- ============================================================
-- 6. TU LISTA DE GENTE  ← editá esto
--
--    Todos los mails en minúscula.
--    is_admin = true  → ve la pestaña Admin, oculta estadísticas
--                       y asigna equipos.
--    is_admin = false → carga dados y nada más.
--
--    No hace falta poner el equipo acá: se asigna desde la
--    pestaña Admin de la página, con un desplegable. Si igual
--    querés dejarlo cargado de entrada, la columna es 'team' y
--    los valores válidos son 'e1' a 'e6'.
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
--   select email, is_admin, team, nota from public.members order by email;

-- Para soltar a todos de su equipo y que vuelvan a ver los seis:
--   update public.members set team = null;
