-- X-FOX ESPORT V9
-- Executar uma vez no Supabase SQL Editor depois de V4, V7 e V8.
-- O site público só consegue ler campos seleccionados de perfis aprovados.

alter table public.profiles enable row level security;
drop policy if exists "Public read approved roster profiles" on public.profiles;
create policy "Public read approved roster profiles"
on public.profiles for select to anon, authenticated
using (status = 'approved' and is_admin = false);

alter table public.heroes_catalog enable row level security;
alter table public.player_hero_stats enable row level security;

drop policy if exists "Public read hero catalogue" on public.heroes_catalog;
create policy "Public read hero catalogue"
on public.heroes_catalog for select to anon, authenticated using (true);

drop policy if exists "Public read approved hero stats" on public.player_hero_stats;
create policy "Public read approved hero stats"
on public.player_hero_stats for select to anon, authenticated
using (exists (
  select 1 from public.profiles p
  where p.id = profile_id and p.status = 'approved' and p.is_admin = false
));

grant select on public.profiles to anon, authenticated;
grant select on public.heroes_catalog to anon, authenticated;
grant select on public.player_hero_stats to anon, authenticated;
