-- X-FOX ESPORT V11 — executar uma vez depois do SQL V10.
-- Adiciona a função/categoria do herói sem apagar o catálogo ou as estatísticas existentes.

alter table public.heroes_catalog
 add column if not exists category text not null default 'Função por definir';

alter table public.heroes_catalog
 drop constraint if exists heroes_catalog_category_check;

alter table public.heroes_catalog
 add constraint heroes_catalog_category_check
 check (category in ('Tanque','Assassino','Mago','Atirador','Lutador','Suporte','Função por definir'));

grant select on public.heroes_catalog to anon, authenticated;

-- A leitura pública já é permitida pela política criada na V9.
-- A edição continua dependente das políticas de administrador existentes.
