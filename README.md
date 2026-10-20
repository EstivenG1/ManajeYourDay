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
- Elegir entre tareas sugeridas y recibir autocompletado ordenado por lo que
  más usas.

### Finanzas

- Registrar ingresos y gastos por categoria y elegir importes rapidos.
- Guardar coordenadas solo cuando el usuario activa ubicacion para un movimiento.
- Ver un mapa interactivo de OpenStreetMap con direccion aproximada del dispositivo.
- Adjuntar un recibo privado y dictar la descripcion con reconocimiento local.
- Crear presupuestos por categoria y recibir alertas al llegar al 75%.
- Ver una proyeccion orientativa de balance al cierre de mes.
- Programar movimientos recurrentes; estos generan recordatorios, no movimientos automaticos.
- Consultar los movimientos y el balance calculado con el historial del usuario.
### Metas y reportes

- En el inicio se ve una proyecciÃ³n orientativa del balance al cierre del mes y
  alertas cuando un presupuesto por categorÃ­a llega al 75%.
- El historial permite buscar texto en movimientos, tareas y aportes.

- Crear metas de ahorro, registrar aportes y consultar su progreso e historial.
- Definir un aporte y una frecuencia para recibir recordatorios.
- Recibir avisos al alcanzar hitos del 25%, 50%, 75% y 100%.
- Consultar reportes de hoy y semana; el reporte mensual depende del plan
  asignado en Supabase.
- Consultar gráficos, presupuestos, metas y conclusiones calculadas localmente.
- Exportar movimientos y tareas de un rango de fechas a CSV, Excel (.xlsx) o PDF.
  Excel y PDF incluyen el logo y una presentación con la paleta dorada de MYD.

### Cuenta y accesibilidad

- Iniciar sesión con correo/contraseña o Google.
- Ver una bienvenida de inicio la primera vez que se registra la cuenta.
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
- Permisos de ubicación “mientras se usa” para capturar coordenadas a petición.

```powershell
flutter pub get
flutter run
```

## Supabase y migraciones

El proyecto enlazado ya tiene aplicadas las migraciones de recurrencias, avatares privados y ubicaciones. Para una copia nueva, revisa las migraciones de `supabase/migrations` y aplícalas en orden con `supabase db push` tras ejecutar `supabase login` y `supabase link`.

La migración nueva `20261019000100_private_transaction_receipts.sql` crea la columna y el bucket privado para fotos de recibos. Aplícala antes de usar esa función. Después, despliega `supabase/functions/delete-account` para que la eliminación de cuenta también elimine los recibos privados.

El dictado solo intenta reconocimiento en el dispositivo. Si el sistema no tiene el modelo de voz disponible, MYD no envía el audio a un servicio remoto como alternativa.
## Protección de fotos de perfil

La migración [`20261018000100_private_avatars.sql`](./supabase/migrations/20261018000100_private_avatars.sql)
configura `avatars` como bucket privado y limita el acceso a objetos dentro de
la carpeta del usuario autenticado. Debe aplicarse en Supabase antes de publicar
la versión que usa URLs firmadas. Verifica en el proyecto las políticas efectivas
de `storage.objects` y prueba lectura, carga y eliminación con dos cuentas
distintas; la política restrictiva de la migración bloquea acceso cruzado aunque
existan políticas permisivas anteriores.

## Alcance no incluido

- Integración bancaria, pagos automáticos o ahorros compartidos.
- Conversión automática entre monedas.
- Pasarela para comprar o cambiar planes Premium.
- Copias de seguridad descargables automáticas; la exportación CSV/Excel/PDF es
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
