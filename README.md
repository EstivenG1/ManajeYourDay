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
- Abrir el detalle de una tarea tocando su tarjeta, excepto los controles de acción.
- Elegir entre tareas sugeridas y recibir autocompletado ordenado por lo que
  más usas.

### Notas

- Organizar notas en Importantes, Información y Generales, o verlas todas.
- Fijar notas para mantenerlas arriba y cambiar su orden desde el menú.
- Elegir entre vistas de cuadrícula, compacta y lista.

### Finanzas

- Registrar ingresos y gastos por categoria y elegir importes rapidos.
- Guardar coordenadas solo cuando el usuario activa ubicacion para un movimiento.
- Ver un mapa interactivo de OpenStreetMap con direccion aproximada del dispositivo.
- Adjuntar un recibo privado y dictar la descripcion con reconocimiento local.
- Crear presupuestos por categoria y recibir alertas al llegar al 75%.
- Ver una proyeccion orientativa de balance al cierre de mes.
- Programar movimientos recurrentes; estos generan recordatorios, no movimientos automaticos.
- Consultar los movimientos y el balance calculado con el historial del usuario.
- Abrir el detalle de movimientos tocando su tarjeta, excepto los controles de acción.
### Metas y reportes

- En el inicio se ve una proyecciÃ³n orientativa del balance al cierre del mes y
  alertas cuando un presupuesto por categorÃ­a llega al 75%.
- El historial permite buscar texto en movimientos, tareas y aportes.

- Crear metas de ahorro, registrar aportes y consultar su progreso e historial.
- Definir un aporte y una frecuencia para recibir recordatorios.
- Recibir avisos al alcanzar hitos del 25%, 50%, 75% y 100%.
- Consultar reportes diarios, semanales y mensuales gratis.
- Reportes abre por defecto en Hoy e incluye una guia informativa sobre cada periodo.
- Consultar gráficos, presupuestos, metas y conclusiones calculadas localmente.
- Exportar movimientos y tareas de un rango de fechas a CSV en el plan Gratis,
  Excel (.xlsx) desde Estándar y PDF desde Premium. Excel y PDF incluyen el logo
  y una presentación con la paleta dorada de MYD.

### Cuenta y accesibilidad

- Iniciar sesión con correo/contraseña o Google.
- Ver una bienvenida de inicio la primera vez que se registra la cuenta.
- Editar datos desde **Datos de usuario** y personalizar la foto de perfil y portada.
- Consultar una guia general y los detalles de cada plan MYD.
- Elegir moneda e idioma (español/inglés), modo oscuro, alto contraste, tamaño
  del texto y activar/desactivar notificaciones. Estas empiezan desactivadas;
  al habilitarlas desde Perfil se solicita el permiso del dispositivo.
- Consultar historial y solicitar la eliminación definitiva de la cuenta.

El checkout de Mercado Pago está disponible en la web y en la APK distribuida
directamente fuera de Google Play. Ambos usan el mismo checkout seguro externo y
webhook de suscripciones; al volver a MYD, la app verifica el estado del plan.
El flujo aún no se ha validado de principio a fin ni está habilitado para cobrar
en producción. No publiques esta variante con checkout de Mercado Pago en
Google Play: para esa distribución se debe integrar Google Play Billing o
cumplir los requisitos vigentes del programa de facturación alternativa de
Google.
La moneda elegida cambia el formato del importe, **no convierte valores ni
consulta tasas de cambio**. La selección de idioma localiza los controles del
sistema y las pantallas principales; el cambio se aplica al cerrar y volver a
abrir la app. Aún pueden quedar textos secundarios sin traducir.

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

Para autenticación en producción, configura en Supabase **Authentication →
URL Configuration** con `https://estiveng1.github.io/ManajeYourDay/` como
`Site URL` y permite ese mismo URL, además de
`io.supabase.myd://reset-password` y
`io.supabase.myd://auth-callback`, en `Redirect URLs`. La recuperación y la
confirmación de registro desde la web vuelven al sitio actual; Android/iOS usan
sus deep links respectivos.
La plantilla HTML para **Confirm signup** está en
[`supabase/templates/confirm-signup.html`](./supabase/templates/confirm-signup.html);
usa el asunto `Confirma tu correo | MYD`.
La plantilla de restablecimiento está en
[`supabase/templates/reset-password.html`](./supabase/templates/reset-password.html);
usa el asunto `Restablece tu contraseña | MYD`.

## Supabase y migraciones

`supabase/migrations/20261014000000_initial_schema.sql` incorpora el esquema
público exportado de Supabase como base para una instalación limpia; las
migraciones posteriores aplican las evoluciones y políticas que siguen. Es un
dump solo de estructura: no incluye usuarios, otros datos ni objetos internos
de los esquemas gestionados `auth` y `storage`. `supabase/seed.sql` carga de
forma idempotente los planes heredados y las categorías compartidas, y la
migración `20261014000100_auth_user_profile_trigger.sql` crea el trigger que
genera el perfil al registrarse una cuenta.

Esta migración inicial no debe ejecutarse en el proyecto remoto existente: sus
tablas ya están creadas. Antes de desplegar allí, compara el esquema remoto con
el baseline y registra esa versión como aplicada en el historial de migraciones
sin ejecutar su SQL. Revisa siempre `supabase migration list` y todas las
migraciones pendientes antes de `supabase db push`; el push aplica todas las
migraciones locales pendientes, no solo una.

Para validar la reconstrucción local se necesita Docker Desktop o Podman para
`supabase start` y `supabase db reset`. Esa comprobación aún no se ha ejecutado
en este equipo. No habilites los despliegues backend de GitHub Actions hasta
probar el reset completo en un entorno local/staging y preparar el historial del
proyecto remoto existente.

El proyecto enlazado tiene aplicadas las migraciones de recurrencias, avatares y recibos privados, ubicaciones y limpieza de cuenta. Para desplegar cambios, confirma primero el proyecto enlazado y revisa todas las migraciones pendientes con `supabase migration list`. `supabase db push` aplica todas las migraciones locales que aún no estén en ese proyecto, no solo una.

La migración `20261103000200_remove_duplicate_owner_policies.sql` quita
políticas RLS antiguas que duplicaban las políticas de propietario, manteniendo
la política de lectura de categorías compartidas.

La pantalla de finanzas trae únicamente los 50 movimientos recientes. Los
totales se calculan en Postgres mediante `get_my_finance_totals`, filtrado por
el usuario autenticado, para evitar descargar todo el historial al dispositivo.
El uso de presupuestos también se agrega en Postgres y se reutiliza en inicio,
reportes, notificaciones y la pantalla de presupuestos.

La migración `20261019000100_private_transaction_receipts.sql` crea la columna y el bucket privado para fotos de recibos. La migración `20261022000100_tighten_storage_and_account_cleanup.sql` elimina políticas heredadas de avatares y amplía la limpieza de cuenta. Despliega `supabase/functions/delete-account` para que el borrado elimine archivos y datos de usuario.

El dictado solo intenta reconocimiento en el dispositivo. Si el sistema no tiene el modelo de voz disponible, MYD no envía el audio a un servicio remoto como alternativa.

## Planes de prueba para desarrolladores

Las migraciones `20261029000100_developer_plan_overrides.sql` y
`20261030000100_plan_feature_limits.sql` permiten consultar el nivel actual y
aplicar límites por plan. La migración `20261030000200_web_subscriptions.sql`
también está aplicada en el proyecto remoto enlazado. Las excepciones de
desarrollador se administran desde Supabase y no generan cobros. La migración
de suscripciones y las funciones de Mercado Pago están desplegadas en el
proyecto remoto enlazado. Sus credenciales están configuradas para sandbox; el
checkout de prueba no equivale a habilitar cobros reales.

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
no se habilitaron cobros en producción, esta restricción diferencia funciones
en la app pero las pruebas deben realizarse exclusivamente con sandbox.

| Recurso | Gratis | Estándar | Premium |
|---|---:|---:|---:|
| Tareas nuevas por mes | 50 | 500 | Sin límite del plan |
| Movimientos nuevos por mes | 100 | 1.000 | Sin límite del plan |
| Presupuestos vigentes | 2 | 10 | Sin límite del plan |
| Metas activas | 2 | 10 | Sin límite del plan |
| Recordatorios financieros activos | 3 | 25 | Sin límite del plan |
| Recibos nuevos por mes | 3 | 30 | 100 |

Los límites mensuales se cuentan según la fecha de creación o carga; los de
presupuestos, metas y recordatorios cuentan elementos activos/vigentes.
Los cambios de plan no eliminan datos. Las compras están disponibles en
Flutter Web y Android; el checkout de Android se abre en Mercado Pago fuera de
la app. Desde el menú de la foto de perfil, **Planes MYD** abre una pantalla
propia para comparar y administrar
planes. Allí se puede reanudar o cancelar un proceso de pago pendiente, o
cancelar un plan activo/prueba gratis; las acciones y confirmaciones distinguen
claramente entre ambos casos.
El equipo puede asignar planes de prueba desde Supabase Studio siguiendo las
instrucciones anteriores. El servidor valida pagos y cambios de suscripción;
nunca permitas que el cliente cambie su propio nivel.

## Suscripciones con Mercado Pago (sandbox)

El checkout se inicia desde Flutter Web o Android y se crea en una Edge Function
autenticada; el cliente solo recibe la URL HTTPS hospedada por Mercado Pago.
`mercadopago-webhook` verifica la firma, consulta la suscripción
directamente a Mercado Pago y actualiza `billing_subscriptions`; el regreso del
navegador no confirma ni activa el pago. `get_my_plan()` mantiene prioridad para
los overrides del equipo y solo considera suscripciones confirmadas. La tabla
no permite escrituras desde la aplicación.

El catálogo está fijado en el servidor: Estándar cuesta 12.900 COP al mes o
129.000 COP al año; Premium cuesta 24.900 COP al mes o 249.900 COP al año. La
oferta de prueba es Premium gratis durante 7 días y requiere autorizar un medio
de pago; después se cobra la tarifa mensual Premium. Se permite una prueba por
cuenta. Un checkout que se cierra antes de autorizarse no consume la prueba.
No se acepta el monto enviado por el cliente. El nivel es por cuenta, de modo
que una suscripción puede afectar los límites que se consultan también desde
otros clientes de esa misma cuenta.

Planes MYD muestra una guía de funciones y límites con el botón de información
de cada plan. La confirmación para ir a Mercado Pago aparece antes de crear o
reanudar el checkout; cancelarla no inicia una compra. Si se sale de Mercado
Pago sin terminar, se puede reabrir el mismo checkout desde Planes MYD.

**Estado: desplegado en sandbox; prueba inicial verificada.** La
migración `20261101000100_premium_trial.sql` y las funciones
`start-subscription`, `mercadopago-webhook`, `sync-subscription` y
`cancel-subscription` están desplegadas en Supabase. El origen local
`http://localhost:7357` está permitido para CORS. En una cuenta sandbox se
confirmó la autorización, la activación Premium sin cobro inmediato, el precio
recurrente de 24.900 COP con cobro programado para el 10/nov y la cancelación
desde MYD, que devolvió la cuenta a Gratis y quitó el próximo cobro. Aún falta
verificar el cobro real después del periodo de prueba y probar los demás
estados de pago. La web pública no se ha actualizado con estos cambios.

No conectes credenciales LIVE al backend ni vendas planes hasta completar las
pruebas de estados pendientes, autorizados, rechazados y cancelados, el cobro tras los
7 días, el uso único de la prueba y la cancelación durante el periodo gratuito.
Revisa también comisiones, obligaciones locales y soporte. Antes de ofrecer
compras a usuarios de apps nativas, revisa las políticas de sus tiendas.

`MERCADOPAGO_ENVIRONMENT` debe configurarse explícitamente como `test` o
`production`; el checkout no asume un entorno si falta esa variable. La mejora
de Estándar a Premium con 50% de descuento está limitada a sandbox: solo se
cambia si `MERCADOPAGO_TEST_UPGRADE_PROMOTION_ENABLED=true` está configurado
junto con el entorno `test`. Mantén esa bandera sin configurar en producción.
No se ofrece en producción hasta validar por separado el
cambio de tarifa y la restauración del precio normal después del primer cobro.

Los despliegues del backend en GitHub Actions están desactivados hasta definir
la variable de repositorio `SUPABASE_STAGING_ENABLED` o
`SUPABASE_PRODUCTION_ENABLED` como `true`. Staging se despliega al actualizar
`develop`; producción solo se despliega manualmente desde `main` mediante
**Deploy backend to production**. Configura los entornos GitHub
`staging` y `production` con sus propios secretos `SUPABASE_PROJECT_REF`,
`SUPABASE_DB_PASSWORD` y `SUPABASE_ACCESS_TOKEN`; protege `production` con
aprobación requerida y limita sus ramas/etiquetas permitidas. Las pruebas deben
desplegarse y validarse primero en staging. No habilites producción hasta que
staging use una base inicial equivalente y verificada.

Para una prueba local:

1. Configura las funciones con las variables de entorno locales en
   `supabase/functions/.env` (ese archivo está ignorado por Git):

   ```dotenv
   MERCADOPAGO_ACCESS_TOKEN=TOKEN_DE_PRUEBA
   MERCADOPAGO_WEBHOOK_SECRET=SECRETO_DE_WEBHOOK_DE_PRUEBA
   MERCADOPAGO_ENVIRONMENT=test
   MERCADOPAGO_TEST_PAYER_EMAIL=CORREO_DEL_COMPRADOR_DE_PRUEBA
   MYD_WEB_URL=http://localhost:7357
   APP_ALLOWED_ORIGINS=http://localhost:7357,http://127.0.0.1:7357
   ```

2. Inicia Flutter Web en la dirección configurada y usa una cuenta de prueba.
   El backend usa siempre `MERCADOPAGO_TEST_PAYER_EMAIL` como comprador en
   sandbox, aunque el cliente envíe otro correo. Autoriza el checkout con esa
   misma cuenta compradora de prueba; puede ser distinta del correo de MYD. La
   migración de suscripciones ya está aplicada en el proyecto remoto enlazado.
3. Si pruebas con Supabase local, sirve las funciones
   `start-subscription`, `mercadopago-webhook`, `sync-subscription` y
   `cancel-subscription` localmente.
   Configura el webhook de prueba en Mercado Pago para la URL local alcanzable
   por el proveedor (por ejemplo, con un túnel HTTPS temporal) y sus eventos de
   suscripción. No publiques el secreto del túnel ni credenciales de Mercado
   Pago.
4. Completa pagos pendientes, autorizados, rechazados y cancelados; prueba
   reanudar un checkout, cancelar la prueba y confirmar que no se permita usarla
   una segunda vez. Verifica los webhooks, `get_my_plan()` y el próximo cobro.

Para configurar otro entorno, guarda `MERCADOPAGO_ACCESS_TOKEN`,
`MERCADOPAGO_WEBHOOK_SECRET`, `MERCADOPAGO_ENVIRONMENT`,
`MERCADOPAGO_TEST_PAYER_EMAIL`, `MYD_WEB_URL` y `APP_ALLOWED_ORIGINS` como
secretos de Edge Functions en Supabase. Mantén
`MERCADOPAGO_TEST_UPGRADE_PROMOTION_ENABLED` sin configurar salvo que habilites
la promoción para pruebas en sandbox. Configura en Mercado Pago la URL
`https://lciwjsrheewewgtasrmt.supabase.co/functions/v1/mercadopago-webhook`
y los eventos de suscripción. Nunca incluyas estas credenciales en Flutter, en
`web/` o en Git. No conectes credenciales LIVE hasta que el ciclo completo de
sandbox haya sido verificado y revisa las políticas de pago aplicables antes de
vender.

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
