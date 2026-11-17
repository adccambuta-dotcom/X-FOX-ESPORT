-- X-FOX ESPORT V4
-- Executar no Supabase > SQL Editor.
-- IMPORTANTE: depois de executar, substituir o e-mail do administrador no bloco final.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists status text not null default 'pending',
  add column if not exists is_admin boolean not null default false,
  add column if not exists ml_nickname text not null default '',
  add column if not exists country text not null default '',
  add column if not exists division text not null default '',
  add column if not exists game_role text not null default '',
  add column if not exists main_heroes text not null default '';

-- Cria automaticamente um perfil pendente sempre que alguém se regista.
create or replace function public.xfox_create_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, status, is_admin)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    'pending',
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists xfox_on_auth_user_created on auth.users;
create trigger xfox_on_auth_user_created
after insert on auth.users
for each row execute procedure public.xfox_create_profile();

-- Cria perfis pendentes para contas que já existiam antes deste trigger.
insert into public.profiles (id, display_name, status, is_admin)
select id, coalesce(raw_user_meta_data ->> 'display_name',''), 'pending', false
from auth.users
on conflict (id) do nothing;

-- Função segura para verificar o administrador sem expor a lista de perfis.
create or replace function public.xfox_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin = true
  );
$$;

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Members read own profile" on public.profiles;
drop policy if exists "Admins read all profiles" on public.profiles;
drop policy if exists "Admins update profiles" on public.profiles;

create policy "Members read own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id or public.xfox_is_admin());

-- Utilizadores não podem escolher o seu estado nem tornar-se administradores.
-- O trigger cria os perfis; por isso não é necessária uma política INSERT para o browser.
create policy "Admins update profiles"
on public.profiles for update
to authenticated
using (public.xfox_is_admin())
with check (public.xfox_is_admin());

-- Caixa de mensagens: cada membro envia mensagens; só esse membro e o administrador as podem ler.
create table if not exists public.member_messages (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null default 'Mensagem para a administração',
  body text not null check (char_length(body) between 1 and 4000),
  admin_reply text,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.member_messages enable row level security;

drop policy if exists "Members send own messages" on public.member_messages;
drop policy if exists "Members read own messages" on public.member_messages;
drop policy if exists "Admins read all messages" on public.member_messages;
drop policy if exists "Admins reply to messages" on public.member_messages;

create policy "Members send own messages"
on public.member_messages for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Members read own messages"
on public.member_messages for select
to authenticated
using (auth.uid() = user_id or public.xfox_is_admin());

create policy "Admins reply to messages"
on public.member_messages for update
to authenticated
using (public.xfox_is_admin())
with check (public.xfox_is_admin());

-- PROMOÇÃO DO ÚNICO ADMINISTRADOR:
-- Substitui o endereço abaixo pelo e-mail exacto da tua conta já registada.
-- Executa este bloco apenas depois de confirmares o e-mail.
-- update public.profiles p
-- set is_admin = true, status = 'approved'
-- from auth.users u
-- where p.id = u.id and lower(u.email) = lower('TEU_EMAIL_AQUI');


-- V5: estatísticas individuais e gerais da equipa.
alter table public.profiles
  add column if not exists matches_played integer not null default 0 check (matches_played >= 0),
  add column if not exists wins integer not null default 0 check (wins >= 0 and wins <= matches_played);

create table if not exists public.team_stats (
  id integer primary key default 1 check (id = 1),
  matches_played integer not null default 0 check (matches_played >= 0),
  wins integer not null default 0 check (wins >= 0 and wins <= matches_played),
  updated_at timestamptz not null default now()
);
insert into public.team_stats (id, matches_played, wins) values (1,0,0) on conflict (id) do nothing;
alter table public.team_stats enable row level security;
drop policy if exists "Public can read team stats" on public.team_stats;
drop policy if exists "Admins manage team stats" on public.team_stats;
create policy "Public can read team stats" on public.team_stats for select to anon, authenticated using (true);
create policy "Admins manage team stats" on public.team_stats for all to authenticated using (public.xfox_is_admin()) with check (public.xfox_is_admin());


-- V5: estatísticas individuais e gerais da equipa.
alter table public.profiles
  add column if not exists matches_played integer not null default 0 check (matches_played >= 0),
  add column if not exists wins integer not null default 0 check (wins >= 0 and wins <= matches_played);

create table if not exists public.team_stats (
  id integer primary key default 1 check (id = 1),
  matches_played integer not null default 0 check (matches_played >= 0),
  wins integer not null default 0 check (wins >= 0 and wins <= matches_played),
  updated_at timestamptz not null default now()
);
insert into public.team_stats (id, matches_played, wins) values (1,0,0) on conflict (id) do nothing;
alter table public.team_stats enable row level security;
drop policy if exists "Public can read team stats" on public.team_stats;
drop policy if exists "Admins manage team stats" on public.team_stats;
create policy "Public can read team stats" on public.team_stats for select to anon, authenticated using (true);
create policy "Admins manage team stats" on public.team_stats for all to authenticated using (public.xfox_is_admin()) with check (public.xfox_is_admin());

-- O site público pode consultar apenas os perfis aprovados e não administrativos.
drop policy if exists "Public can read approved roster" on public.profiles;
create policy "Public can read approved roster" on public.profiles
for select to anon, authenticated
using (status = 'approved' and is_admin = false);
