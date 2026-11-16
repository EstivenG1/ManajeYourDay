alter table public.notas
  add column if not exists categoria text not null default 'general',
  add column if not exists fijada boolean not null default false,
  add column if not exists orden integer not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'notas_categoria_check'
      and conrelid = 'public.notas'::regclass
  ) then
    alter table public.notas
      add constraint notas_categoria_check
      check (categoria in ('importante', 'informacion', 'general'));
  end if;
end;
$$;

with notas_ordenadas as (
  select
    id,
    row_number() over (
      partition by usuario_id
      order by actualizado_en desc, creado_en desc, id
    )::integer - 1 as nuevo_orden
  from public.notas
)
update public.notas as n
set orden = notas_ordenadas.nuevo_orden
from notas_ordenadas
where n.id = notas_ordenadas.id;

create index if not exists notas_usuario_fijada_orden_idx
  on public.notas (usuario_id, fijada desc, orden, actualizado_en desc);

create or replace function public.swap_note_order(
  p_note_id uuid,
  p_other_note_id uuid
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
  note_order integer;
  other_order integer;
  note_pinned boolean;
  other_pinned boolean;
  locked_count integer;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_note_id = p_other_note_id then
    raise exception 'Notes must be different';
  end if;

  perform n.id
  from public.notas as n
  where n.id in (p_note_id, p_other_note_id)
    and n.usuario_id = current_user_id
  order by n.id
  for update;

  get diagnostics locked_count = row_count;
  if locked_count <> 2 then
    raise exception 'Note not found';
  end if;

  select n.orden, n.fijada
  into note_order, note_pinned
  from public.notas as n
  where n.id = p_note_id
    and n.usuario_id = current_user_id;

  select n.orden, n.fijada
  into other_order, other_pinned
  from public.notas as n
  where n.id = p_other_note_id
    and n.usuario_id = current_user_id;

  if note_pinned <> other_pinned then
    raise exception 'Pinned notes cannot be reordered with unpinned notes';
  end if;

  update public.notas as n
  set orden = case
    when n.id = p_note_id then other_order
    else note_order
  end
  where n.usuario_id = current_user_id
    and n.id in (p_note_id, p_other_note_id);
end;
$$;

revoke all on function public.swap_note_order(uuid, uuid) from public, anon;
grant execute on function public.swap_note_order(uuid, uuid) to authenticated;
