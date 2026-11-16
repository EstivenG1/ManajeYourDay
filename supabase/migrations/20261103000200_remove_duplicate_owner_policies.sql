drop policy if exists "aportes_propio" on public.aportes_ahorro;

drop policy if exists "categorias_propio_actualiza" on public.categorias;
drop policy if exists "categorias_propio_elimina" on public.categorias;
drop policy if exists "categorias_propio_modifica" on public.categorias;

drop policy if exists "metas_propio" on public.metas_ahorro;
drop policy if exists "movimientos_propio" on public.movimientos;
drop policy if exists "usuarios gestionan sus movimientos recurrentes"
  on public.movimientos_recurrentes;
drop policy if exists "notificaciones_propio" on public.notificaciones;
drop policy if exists "perfiles_propio_select" on public.perfiles;
drop policy if exists "perfiles_propio_update" on public.perfiles;
drop policy if exists "presupuestos_propio" on public.presupuestos;
drop policy if exists "recomendaciones_propio" on public.recomendaciones_ia;
drop policy if exists "reportes_propio" on public.reportes_semanales;
drop policy if exists "sugerencias_propio" on public.sugerencias_texto;
drop policy if exists "suscripciones_propio" on public.suscripciones;
drop policy if exists "tareas_propio" on public.tareas;
