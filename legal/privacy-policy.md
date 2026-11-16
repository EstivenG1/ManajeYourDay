# Política de Privacidad - Manage Your Day

**Fecha de entrada en vigor:** 28 de octubre de 2026
**Versión:** 1.0
**Empresa:** Manage Your Day
**Contacto:** manage.your.day.oficial@gmail.com

## 1. Introducción

Manage Your Day ("la aplicación", "nosotros", "nuestro") es una aplicación de productividad y finanzas personales que te ayuda a gestionar tareas, movimientos financieros, presupuestos y metas de ahorro. Esta política de privacidad explica qué información recopilamos, cómo la usamos, compartimos y protegemos.

## 2. Información que recopilamos

### Datos que tú proporcionas
- Correo electrónico (para autenticación)
- Nombre de perfil (opcional)
- Foto de perfil (opcional)
- Tareas que creas (título, descripción, fecha límite, estado)
- Movimientos financieros (monto, tipo, categoría, fecha, ubicación opcional)
- Presupuestos y metas de ahorro
- Comprobantes de recibos (fotos subidas por ti)

### Datos recopilados automáticamente
- Identificador de usuario generado por Supabase Auth
- Preferencias de configuración (idioma, moneda, tema, tamaño de texto)
- Estado de notificaciones habilitadas/deshabilitadas

### Datos de ubicación
Solo se registran coordenadas (latitud/longitud) cuando tú las asocia explícitamente a un movimiento financiero. No rastreamos tu ubicación en segundo plano.

### Datos del dispositivo
- Tipo de dispositivo y versión del sistema operativo (para notificaciones push)
- Token de dispositivo para notificaciones locales (no se envía a servidores externos)

## 3. Cómo usamos tu información

Usamos los datos para:
- Autenticar tu cuenta y mantener tu sesión
- Almacenar y sincronizar tus tareas, finanzas y metas
- Enviarte notificaciones locales programadas por ti (recordatorios de tareas, presupuestos, metas)
- Mostrar mapas y ubicación asociada a tus movimientos
- Mejorar la experiencia de la aplicación

## 4. Proveedores externos

| Proveedor | Finalidad | Datos compartidos |
|-----------|-----------|-------------------|
| **Supabase** | Autenticación, base de datos, almacenamiento de archivos | Correo electrónico, ID de usuario, tareas, movimientos, presupuestos, metas, fotos de recibos y avatar |
| **Google Sign-In** | Autenticación con cuenta de Google | Correo electrónico y perfil de Google (solo si eliges esta opción) |
| **OpenStreetMap** | Tiles de mapas | Solicitudes de tiles de mapa (no se comparte tu ubicación personal) |
| **Sentry** (opcional) | Reporte de errores | Eventos de error sin datos personales sensibles (sanitizados) |

## 5. Almacenamiento y seguridad

- Tus datos se almacenan en Supabase (PostgreSQL y Storage).
- Todas las tablas de datos de usuario tienen Row Level Security (RLS) activado, lo que significa que solo tú puedes leer y modificar tus propios datos.
- Los buckets de almacenamiento (recibos y avatares) son privados y aislados por usuario.
- No almacenamos tu contraseña en texto plano.
- Las claves administrativas (service_role_key) nunca se incluyen en la aplicación cliente.

## 6. Tus derechos

Tienes derecho a:
- Acceder a tus datos
- Corregir datos inexactos
- Eliminar tu cuenta y todos tus datos asociados
- Exportar tus datos (CSV, Excel, PDF)
- Retirar el consentimiento para notificaciones

Para ejercer estos derechos, utiliza la función "Eliminar cuenta" dentro de la aplicación o contáctanos a manage.your.day.oficial@gmail.com.

## 7. Eliminación de cuenta

Al eliminar tu cuenta:
- Se eliminan todos tus datos personales de las tablas de Supabase
- Se eliminan tus fotos de recibos y avatar de Storage
- Se elimina tu cuenta de autenticación
- Algunos datos anonimizados en reportes agregados pueden conservarse con fines analíticos (sin identificar tu identidad)

## 8. Retención de datos

Mantenemos tus datos mientras tengas una cuenta activa. Tras eliminar tu cuenta, tus datos personales se eliminan de acuerdo con la política de eliminación descrita arriba.

## 9. Menores de edad

La aplicación está destinada a usuarios mayores de 13 años. No recopilamos intencionalmente datos de menores de 13 años.

## 10. Cambios a esta política

Podemos actualizar esta política de privacidad periódicamente. Los cambios se notificarán dentro de la aplicación y la versión actualizada se publicará en nuestro sitio web.

## 11. Contacto

Para preguntas sobre esta política o sobre tus datos, escríbenos a:
**manage.your.day.oficial@gmail.com**
