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
- Consultar reportes diarios, semanales y mensuales gratis.
- Consultar gráficos, presupuestos, metas y conclusiones calculadas localmente.
- Exportar movimientos y tareas de un rango de fechas a CSV en el plan Gratis,
  Excel (.xlsx) desde Estándar y PDF desde Premium. Excel y PDF incluyen el logo
  y una presentación con la paleta dorada de MYD.

### Cuenta y accesibilidad

- Iniciar sesión con correo/contraseña o Google.
- Ver una bienvenida de inicio la primera vez que se registra la cuenta.
- Editar el perfil y la foto de usuario.
- Elegir moneda e idioma (español/inglés), modo oscuro, alto contraste, tamaño
  del texto y activar/desactivar notificaciones.
- Consultar historial y solicitar la eliminación definitiva de la cuenta.

MYD todavía no procesa pagos ni activa suscripciones; el lanzamiento de ese
flujo depende de publicar la web y configurar Mercado Pago. La moneda elegida
cambia el formato del importe, **no convierte valores ni consulta tasas de
cambio**. La selección de idioma localiza los controles del sistema y las
pantallas principales; aún pueden quedar textos secundarios sin traducir.

Las recomendaciones del inicio son reglas locales basadas en registros y
tendencias. No se envían datos a un modelo de IA generativa.

## Requisitos y ejecución

- Flutter/Dart compatible con la versión de SDK indicada en `pubspec.yaml`.
- Proyecto Supabase configurado para autenticación, base de datos y los buckets
  privados `avatars` y `receipts`.
- Permisos de ubicación “mientras se usa” para capturar coordenadas a petición.

```powershell
flutter pub get
flutter run
```

## Publicación web gratuita

La aplicación web está publicada gratis en GitHub Pages, sin comprar dominio:
[`https://estiveng1.github.io/ManajeYourDay/`](https://estiveng1.github.io/ManajeYourDay/).
El repositorio debe seguir siendo público para usar Pages sin costo. El workflow
`.github/workflows/deploy-pages.yml` compila Flutter con la subruta correcta y
despliega automáticamente cada cambio que llegue a `main`.

GitHub Pages ya está habilitado con **GitHub Actions** como fuente. La URL del
sitio y su origen ya están guardados en los secretos `MYD_WEB_URL` y
`APP_ALLOWED_ORIGINS` de las Edge Functions. No hace falta registrar una tarjeta
ni comprar un dominio.

## Supabase y migraciones

El proyecto enlazado tiene aplicadas las migraciones de recurrencias, avatares y recibos privados, ubicaciones y limpieza de cuenta. Para una copia nueva, revisa las migraciones de `supabase/migrations` y aplícalas en orden con `supabase db push` tras ejecutar `supabase login` y `supabase link`.

La migración `20261019000100_private_transaction_receipts.sql` crea la columna y el bucket privado para fotos de recibos. La migración `20261022000100_tighten_storage_and_account_cleanup.sql` elimina políticas heredadas de avatares y amplía la limpieza de cuenta. Despliega `supabase/functions/delete-account` para que el borrado elimine archivos y datos de usuario.

El dictado solo intenta reconocimiento en el dispositivo. Si el sistema no tiene el modelo de voz disponible, MYD no envía el audio a un servicio remoto como alternativa.

## Planes de prueba para desarrolladores

Las migraciones `20261029000100_developer_plan_overrides.sql` y
`20261030000100_plan_feature_limits.sql` permiten consultar el nivel actual y
aplicar límites por plan. La migración `20261030000200_web_subscriptions.sql`
también está aplicada en el proyecto remoto enlazado. Las excepciones de
desarrollador se administran desde Supabase y no generan cobros. Las funciones
de Mercado Pago están desplegadas, pero todavía no tienen sus credenciales ni
la URL pública confirmada de la web; por eso el checkout no puede procesar pagos.

Antes de aplicar migraciones en otro proyecto, confirma el proyecto enlazado y
revisa todas las migraciones pendientes: `supabase db push` aplica todas las
migraciones locales que aún no estén en ese proyecto, no solo una. Prueba
primero en un proyecto de desarrollo. Para asignar un nivel de prueba:

1. Crea la cuenta de prueba desde el registro normal de MYD.
2. En Supabase Studio, abre **SQL Editor** y busca el UUID de esa cuenta:

   ```sql
   select id, email
   from auth.users
   where email = 'correo-del-desarrollador@example.com';
   ```

3. En el siguiente ejemplo, reemplaza el marcador por el UUID obtenido y el
   nivel por `free`, `standard` o `premium`. Ejecuta el SQL únicamente con una
   cuenta autorizada para administrar el proyecto:

   ```sql
   insert into public.developer_plan_overrides (user_id, plan, note)
   values (
     'REEMPLAZAR-POR-EL-UUID'::uuid,
     'premium',
     'Prueba manual del equipo'
   )
   on conflict (user_id) do update
   set plan = excluded.plan,
       expires_at = null,
       note = excluded.note,
       updated_at = now();
   ```

Para retirar la excepción de prueba, reemplaza el UUID y ejecuta:

```sql
delete from public.developer_plan_overrides
where user_id = 'REEMPLAZAR-POR-EL-UUID'::uuid;
```

La tabla no concede permisos de lectura ni escritura a los usuarios de la app.
La función `get_my_plan()` solo devuelve el nivel de la cuenta autenticada; si
no hay una excepción vigente, responde `free`. La clave administrativa nunca
debe incluirse en Flutter. Protege Supabase Studio con autenticación
multifactor y limita el acceso a los miembros autorizados del equipo.

Con la migración de límites aplicada, Perfil muestra el nivel de la cuenta y sus
topes. La app verifica el cupo para dar mensajes claros y Postgres vuelve a
validarlo al insertar para que no se pueda eludir modificando el cliente. Si se
excede el límite, se conservan los datos existentes y se rechazan nuevas altas
del recurso correspondiente.

Los reportes diarios, semanales y mensuales siguen disponibles para todos. La
exportación CSV también es gratuita; Excel requiere Estándar o Premium y PDF
requiere Premium. Estas exportaciones se generan en el dispositivo y la app
consulta el nivel de Supabase antes de permitir formatos de pago. Como todavía
no hay pagos configurados ni activos, esta restricción diferencia funciones
en la app pero no representa una compra ni un cobro.

| Recurso | Gratis | Estándar | Premium |
|---|---:|---:|---:|
| Tareas nuevas por mes | 50 | 500 | Sin límite del plan |
| Movimientos nuevos por mes | 100 | 1.000 | Sin límite del plan |
| Presupuestos vigentes | 2 | 10 | Sin límite del plan |
| Metas activas | 2 | 10 | Sin límite del plan |
| Recordatorios financieros activos | 3 | 25 | Sin límite del plan |
| Recibos nuevos por mes | 3 | 30 | 100 |

Los límites mensuales se cuentan según la fecha de creación o carga; los de
presupuestos, metas y recordatorios cuentan elementos activos/vigentes. Los
Los cambios de plan no eliminan datos. No hay compras dentro de las apps nativas
ni una pantalla para cancelar o administrar una suscripción. El equipo puede
asignar planes de prueba desde Supabase Studio siguiendo las instrucciones
anteriores. Antes de vender planes, valida el pago desde un servidor confiable;
nunca permitas que el cliente cambie su propio nivel.

## Suscripciones web con Mercado Pago (despliegue incompleto)

El primer canal de venta previsto es la web. El checkout se crea en una Edge
Function autenticada y el navegador solo recibe la URL HTTPS hospedada por
Mercado Pago. `mercadopago-webhook` verifica la firma, consulta la suscripción
directamente a Mercado Pago y actualiza `billing_subscriptions`; el regreso del
navegador no confirma ni activa el pago. `get_my_plan()` mantiene prioridad para
los overrides del equipo y solo considera suscripciones confirmadas. La tabla
no permite escrituras desde la aplicación.

El catálogo está fijado en el servidor: Estándar cuesta 12.900 COP al mes o
129.000 COP al año; Premium cuesta 24.900 COP al mes o 249.900 COP al año. No
se acepta el monto enviado por el cliente. La pantalla de Perfil inicia el
checkout únicamente en Flutter Web; antes de ofrecer compras a usuarios de apps
nativas, revisa las políticas de sus tiendas. El nivel es por cuenta, de modo
que una suscripción puede afectar los límites que se consultan también desde
otros clientes de esa misma cuenta.

**Este flujo no está listo para vender ni para probar pagos.** La migración y
las funciones `start-subscription` y `mercadopago-webhook` ya están desplegadas
en Supabase. `MYD_WEB_URL` y `APP_ALLOWED_ORIGINS` ya apuntan al sitio gratuito
publicado en GitHub Pages; todavía faltan `MERCADOPAGO_ACCESS_TOKEN` y
`MERCADOPAGO_WEBHOOK_SECRET` como secretos de Edge Functions. El webhook
responde `503` hasta que estén configurados; no se ha procesado ningún pago.
Para el sitio actual, `MYD_WEB_URL` incluye `/ManajeYourDay/` y
`APP_ALLOWED_ORIGINS` es `https://estiveng1.github.io`. También falta probar
todos los estados con credenciales de prueba, confirmar comisiones y
obligaciones locales, y definir la gestión de cancelación y soporte. MYD aún no
tiene un botón de cancelación o administración de pagos.

Para una prueba local:

1. Configura las funciones con las variables de entorno locales en
   `supabase/functions/.env` (ese archivo está ignorado por Git):

   ```dotenv
   MERCADOPAGO_ACCESS_TOKEN=TOKEN_DE_PRUEBA
   MERCADOPAGO_WEBHOOK_SECRET=SECRETO_DE_WEBHOOK_DE_PRUEBA
   MYD_WEB_URL=http://localhost:5000
   APP_ALLOWED_ORIGINS=http://localhost:5000,http://127.0.0.1:5000
   ```

2. Inicia Supabase local y Flutter Web en la dirección configurada. Para probar
   en una base local vacía, aplica sus migraciones localmente; la migración de
   suscripciones ya está aplicada en el proyecto remoto enlazado.
3. Sirve las funciones `start-subscription` y `mercadopago-webhook` localmente.
   Configura el webhook de prueba en Mercado Pago para la URL local alcanzable
   por el proveedor (por ejemplo, con un túnel HTTPS temporal) y sus eventos de
   suscripción. No publiques el secreto del túnel ni credenciales de Mercado
   Pago.
4. Completa pagos aprobados, pendientes, pausados y cancelados, y confirma que
   los webhooks actualizan Supabase y que `get_my_plan()` conserva el acceso o
   vuelve a Gratis según corresponda.

Para completar la configuración desplegada, guarda
`MERCADOPAGO_ACCESS_TOKEN` (primero el de prueba),
`MERCADOPAGO_WEBHOOK_SECRET`, `MYD_WEB_URL` y `APP_ALLOWED_ORIGINS` como
secretos de Edge Functions en Supabase. Configura en Mercado Pago la URL
`https://lciwjsrheewewgtasrmt.supabase.co/functions/v1/mercadopago-webhook`
y los eventos de suscripción. Nunca incluyas estas credenciales en Flutter, en
`web/` o en Git. Antes de vender, prueba el ciclo completo con credenciales de
prueba y revisa las políticas de pago aplicables.

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
