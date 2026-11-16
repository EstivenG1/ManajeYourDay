insert into public.planes (
  id,
  nombre,
  precio,
  limite_tareas,
  tiene_publicidad,
  descripcion
)
overriding system value
values
  (1, 'Basico', 0, 20, true, 'Para empezar a organizarte'),
  (
    2,
    'Premium',
    4.99,
    null,
    false,
    'Tareas y categorías ilimitadas, reportes avanzados'
  ),
  (
    3,
    'Empresarial',
    29,
    null,
    false,
    'Para equipos: panel administrativo y reportes consolidados'
  )
on conflict (id) do nothing;

insert into public.categorias (id, usuario_id, nombre, tipo, icono, color)
overriding system value
values
  (1, null, 'Salario', 'ingreso', 'wallet', '#C9A227'),
  (2, null, 'Ventas', 'ingreso', 'trending-up', '#C9A227'),
  (3, null, 'Otros ingresos', 'ingreso', 'plus-circle', '#C9A227'),
  (4, null, 'Comida', 'gasto', 'utensils', '#1B2A4A'),
  (5, null, 'Transporte', 'gasto', 'car', '#1B2A4A'),
  (6, null, 'Vivienda', 'gasto', 'home', '#1B2A4A'),
  (7, null, 'Entretenimiento', 'gasto', 'film', '#1B2A4A'),
  (8, null, 'Salud', 'gasto', 'heart', '#1B2A4A'),
  (9, null, 'Educación', 'gasto', 'book', '#1B2A4A'),
  (10, null, 'Otros gastos', 'gasto', 'more-horizontal', '#1B2A4A')
on conflict (id) do nothing;

select setval(
  pg_get_serial_sequence('public.planes', 'id'),
  coalesce((select max(id) from public.planes), 1),
  exists(select 1 from public.planes)
);

select setval(
  pg_get_serial_sequence('public.categorias', 'id'),
  coalesce((select max(id) from public.categorias), 1),
  exists(select 1 from public.categorias)
);
