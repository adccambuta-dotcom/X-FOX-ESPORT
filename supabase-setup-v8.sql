-- X-FOX ESPORT V8 — executar UMA VEZ no Supabase SQL Editor.
-- Acrescenta o número de vitórias por herói. Não elimina nem substitui dados existentes.

alter table public.player_hero_stats
  add column if not exists wins integer not null default 0;

-- Recupera uma estimativa de vitórias para registos antigos que só tinham a taxa e o total de partidas.
update public.player_hero_stats
set wins = round((win_rate / 100.0) * matches_played)::integer
where wins = 0 and win_rate > 0 and matches_played > 0;

alter table public.player_hero_stats
  drop constraint if exists player_hero_stats_wins_not_over_matches;

alter table public.player_hero_stats
  add constraint player_hero_stats_wins_not_over_matches
  check (wins >= 0 and wins <= matches_played);
