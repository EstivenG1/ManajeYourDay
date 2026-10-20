alter table public.movimientos
  add column if not exists ubicacion_latitud double precision,
  add column if not exists ubicacion_longitud double precision;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.movimientos'::regclass
      and conname = 'movimientos_ubicacion_coordenadas_check'
  ) then
    alter table public.movimientos
      add constraint movimientos_ubicacion_coordenadas_check
      check (
        (ubicacion_latitud is null and ubicacion_longitud is null)
        or (
          ubicacion_latitud is not null
          and ubicacion_longitud is not null
          and
          ubicacion_latitud between -90 and 90
          and ubicacion_longitud between -180 and 180
        )
      );
  end if;
end;
$$;
