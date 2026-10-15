# MYD — Manage Your Day 📱

MYD reúne en una aplicación Flutter la organización de tareas, las finanzas
personales y el seguimiento de metas. Está dirigido a estudiantes, jóvenes
profesionales y emprendedores que quieren planear sus actividades y entender
mejor sus hábitos de gasto y productividad.

## Funcionalidades

### Tareas

- Crear, consultar, editar, eliminar y completar tareas.
- Definir prioridad, fecha y hora límite, y recordatorios locales.
- Repetir tareas a diario, semanal o mensualmente. Al completar una ocurrencia,
  MYD crea la siguiente.
- Buscar tareas y filtrar por estado, prioridad y fecha.

### Finanzas

- Registrar ingresos y gastos por categoría.
- Consultar los movimientos recientes y un balance calculado con el historial
  completo del usuario.
- Crear, editar y eliminar presupuestos por categoría y periodo; consultar el
  consumo y el monto disponible.
- Recibir alertas locales al acercarse o superar el límite de un presupuesto.
- Programar recordatorios para ingresos y pagos periódicos. **Estos avisos no
  crean movimientos automáticamente**: el usuario registra cada movimiento.

### Metas y reportes

- Crear metas de ahorro, registrar aportes y consultar su progreso e historial.
- Definir un aporte y una frecuencia para recibir recordatorios.
- Recibir avisos al alcanzar hitos del 25%, 50%, 75% y 100%.
- Consultar reportes de hoy y semana; el reporte mensual depende del plan
  asignado en Supabase.
- Consultar gráficos, presupuestos, metas y conclusiones calculadas localmente.
- Exportar movimientos y tareas de un rango de fechas a CSV o PDF para compartir.

### Cuenta y accesibilidad

- Iniciar sesión con correo/contraseña o Google.
- Editar el perfil y la foto de usuario.
- Elegir moneda e idioma (español/inglés), modo oscuro, alto contraste, tamaño
  del texto y activar/desactivar notificaciones.
- Consultar historial y solicitar la eliminación definitiva de la cuenta.

La moneda elegida cambia el formato del importe, **no convierte valores ni
consulta tasas de cambio**. La selección de idioma localiza los controles del
sistema y algunas pantallas principales; todavía quedan textos específicos en
español.

Las recomendaciones del inicio son reglas locales basadas en registros y
tendencias. No se envían datos a un modelo de IA generativa.

## Requisitos y ejecución

- Flutter/Dart compatible con la versión de SDK indicada en `pubspec.yaml`.
- Proyecto Supabase configurado para autenticación, base de datos y el bucket
  `avatars`.

```powershell
flutter pub get
flutter run
```

## Cambios de Supabase pendientes de aplicar

La aplicación no ejecuta migraciones ni despliega funciones automáticamente.
Antes de usar recurrencias de tareas, aportes programados, movimientos
recurrentes o eliminación segura de cuenta:

1. Revisa y aplica
   [`20261015000100_productivity_and_finance_extensions.sql`](./supabase/migrations/20261015000100_productivity_and_finance_extensions.sql)
   con el flujo habitual del proyecto (`supabase db push` después de enlazar el
   proyecto correcto). La migración amplía las tablas existentes `tareas` y
   `metas_ahorro`, crea `movimientos_recurrentes`, activa RLS para esa tabla y
   crea el RPC interno para borrar los datos de una cuenta.
2. Despliega `supabase/functions/delete-account` con Supabase Functions. La
   función valida el JWT del usuario y usa la clave `service_role` solo en el
   entorno seguro del servidor; nunca debe incluirse en Flutter ni en el
   repositorio.
3. Confirma en el entorno de Supabase que las tablas existentes (`perfiles`,
   `categorias`, `movimientos`, `presupuestos`, `tareas`, `metas_ahorro`,
   `aportes_ahorro` y `sugerencias_texto`) usan las columnas de usuario
   esperadas por la migración y que las políticas RLS están activas.

La eliminación es irreversible. La función borra primero los datos del usuario
y su avatar, y después elimina su usuario de Auth. Si el RPC no está desplegado,
la solicitud falla explícitamente y no muestra un falso éxito.

Los recordatorios son notificaciones locales del dispositivo; dependen de los
permisos del sistema. Las ocurrencias recurrentes no se contabilizan como
movimientos financieros automáticamente.

## Alcance no incluido

- Integración bancaria, pagos automáticos o ahorros compartidos.
- Conversión automática entre monedas.
- Pasarela para comprar o cambiar planes Premium.
- Copias de seguridad descargables automáticas; la exportación CSV/PDF es
  iniciada por el usuario.

## Contexto académico y equipo

MYD es un proyecto desarrollado dentro del programa de Análisis y Desarrollo de
Software del SENA.

- Johan Estiven Ríos Torres
- Samuel Mira García
- Estiven Garcés Abreo
- Juan José Piedrahíta Álvarez

---

**MYD — Manage Your Day**
*Organiza tu tiempo. Controla tu dinero. Mejora tu día.*
