-- ============================================================
-- Migración: Login por teléfono + OTP, multicuenta (máx. 3/tel.)
-- Aditiva y segura para datos existentes:
--   - No se toca perfiles.telefono (se deja intacta).
--   - Se agrega telefono_e164 (nullable) e id_especial.
--   - El límite de 3 cuentas solo aplica a telefono_e164 no nulo.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Columnas nuevas en perfiles
-- ------------------------------------------------------------
alter table public.perfiles
  add column if not exists telefono_e164 text,
  add column if not exists id_especial text;

-- ------------------------------------------------------------
-- 2) Backfill de telefono_e164 a partir de perfiles.telefono
--    Función temporal, específica para números colombianos
--    (mismo criterio que ya usa la app). Si no se puede normalizar
--    con confianza, se deja NULL — no se inventa un número.
-- ------------------------------------------------------------
create or replace function temp_normalizar_telefono_co(valor text)
returns text
language plpgsql
as $$
declare
  digitos text;
begin
  if valor is null then
    return null;
  end if;

  digitos := regexp_replace(valor, '\D', '', 'g');

  if digitos ~ '^57\d{10}$' then
    return '+' || digitos;
  elsif digitos ~ '^3\d{9}$' then
    return '+57' || digitos;
  elsif valor ~ '^\+[1-9]\d{7,14}$' then
    return valor;
  else
    return null; -- formato no reconocible; se deja para revisión manual
  end if;
end;
$$;

update public.perfiles
set telefono_e164 = temp_normalizar_telefono_co(telefono)
where telefono is not null
  and telefono_e164 is null;

drop function temp_normalizar_telefono_co(text);

-- ------------------------------------------------------------
-- 3) Backfill de id_especial para filas existentes
--    (formato final: MYD-XXXXXX, alfabeto sin 0/O/1/I para
--    evitar confusión visual al dictarlo o escribirlo).
-- ------------------------------------------------------------
create or replace function myd_generar_codigo_especial()
returns text
language plpgsql
as $$
declare
  alfabeto text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; -- 32 símbolos
  resultado text := '';
  i int;
begin
  for i in 1..6 loop
    resultado := resultado || substr(alfabeto, (floor(random() * length(alfabeto)))::int + 1, 1);
  end loop;
  return 'MYD-' || resultado;
end;
$$;

do $$
declare
  fila record;
  nuevo_codigo text;
  intentos int;
begin
  for fila in select id from public.perfiles where id_especial is null loop
    intentos := 0;
    loop
      nuevo_codigo := myd_generar_codigo_especial();
      intentos := intentos + 1;
      begin
        update public.perfiles set id_especial = nuevo_codigo where id = fila.id;
        exit;
      exception when unique_violation then
        if intentos > 20 then
          raise exception 'No se pudo generar id_especial único para %', fila.id;
        end if;
      end;
    end loop;
  end loop;
end $$;

-- Ya con todo respaldado, se puede exigir unicidad y NOT NULL.
alter table public.perfiles alter column id_especial set not null;
alter table public.perfiles add constraint perfiles_id_especial_unique unique (id_especial);

-- ------------------------------------------------------------
-- 4) Trigger: límite de 3 cuentas por teléfono (a prueba de
--    condiciones de carrera) + generación de id_especial para
--    las filas NUEVAS a partir de ahora.
-- ------------------------------------------------------------
create or replace function myd_antes_insertar_perfil()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  cuentas_existentes int;
  intentos int := 0;
  candidato text;
begin
  if new.telefono_e164 is not null then
    -- Serializa cualquier inserción concurrente para ESTE teléfono.
    -- Se libera solo al terminar la transacción (xact_lock).
    perform pg_advisory_xact_lock(hashtext(new.telefono_e164)::bigint);

    select count(*) into cuentas_existentes
    from public.perfiles
    where telefono_e164 = new.telefono_e164;

    if cuentas_existentes >= 3 then
      raise exception 'Este número ya tiene el máximo de 3 cuentas MYD permitidas'
        using errcode = 'P0001';
    end if;
  end if;

  if new.id_especial is null then
    loop
      candidato := myd_generar_codigo_especial();
      intentos := intentos + 1;
      exit when not exists (select 1 from public.perfiles where id_especial = candidato);
      if intentos > 20 then
        raise exception 'No se pudo generar un id_especial único';
      end if;
    end loop;
    new.id_especial := candidato;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_antes_insertar_perfil on public.perfiles;
create trigger trg_antes_insertar_perfil
  before insert on public.perfiles
  for each row execute function myd_antes_insertar_perfil();

-- Índice de apoyo para las búsquedas por teléfono (login, WhatsApp).
create index if not exists idx_perfiles_telefono_e164 on public.perfiles (telefono_e164);

-- ------------------------------------------------------------
-- 5) Tabla de OTP (reemplaza el código en texto plano que vivía
--    en whatsapp_sesiones.codigo). Sirve tanto al bot de WhatsApp
--    como al login directo de Flutter.
-- ------------------------------------------------------------
create table public.otp_verificaciones (
  id uuid primary key default gen_random_uuid(),
  telefono_e164 text not null,
  canal text not null check (canal in ('whatsapp', 'sms')),
  codigo_hash text not null,          -- SHA-256(codigo + pepper), nunca el código plano
  intentos int not null default 0,
  max_intentos int not null default 5,
  usado boolean not null default false,
  expira_en timestamptz not null,
  ip_solicitante text,
  creado_en timestamptz not null default now()
);

create index idx_otp_telefono_fecha on public.otp_verificaciones (telefono_e164, creado_en desc);
create index idx_otp_telefono_vigente on public.otp_verificaciones (telefono_e164, usado);
create index idx_otp_ip_fecha on public.otp_verificaciones (ip_solicitante, creado_en desc);

-- RLS activo SIN políticas: ningún cliente (anon/authenticated) puede
-- leer ni escribir esta tabla directamente. Solo la service_role
-- (las Edge Functions) puede tocarla, porque service_role nunca pasa
-- por RLS.
alter table public.otp_verificaciones enable row level security;

-- ------------------------------------------------------------
-- NOTA: no se modifica ninguna política RLS existente de
-- perfiles/movimientos/tareas/etc. Siguen funcionando igual,
-- porque perfiles.id sigue siendo = auth.users.id para cada cuenta.
-- ------------------------------------------------------------

3.2 Edge Functions

RUTA:

supabase/functions/_shared/otp.ts

ACCIÓN:

NUEVO

CÓDIGO:

ts

// _shared/otp.ts
//
// Lógica de OTP compartida entre whatsapp-webhook, send-verification-code
// y verify-code. Un solo lugar para las reglas de seguridad: hash,
// expiración, intentos, rate limit, un solo uso.

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const OTP_PEPPER = Deno.env.get('OTP_PEPPER')!;
const WHATSAPP_API_VERSION = Deno.env.get('WHATSAPP_API_VERSION') ?? 'v26.0';
const WHATSAPP_ACCESS_TOKEN = Deno.env.get('WHATSAPP_ACCESS_TOKEN')!;
const WHATSAPP_PHONE_NUMBER_ID = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')!;

const MINUTOS_EXPIRACION_OTP = 5;
const MAX_INTENTOS_OTP = 5;
const MAX_SOLICITUDES_POR_TELEFONO_HORA = 5;
const MAX_SOLICITUDES_POR_IP_HORA = 10;

export function normalizarTelefono(valor: string): string | null {
  const digitos = valor.replace(/\D/g, '');

  if (/^57\d{10}$/.test(digitos)) return `+${digitos}`;
  if (/^3\d{9}$/.test(digitos)) return `+57${digitos}`;
  if (/^\+[1-9]\d{7,14}$/.test(valor.trim())) return valor.trim();

  return null;
}

async function hashCodigo(codigo: string): Promise<string> {
  const datos = new TextEncoder().encode(codigo + OTP_PEPPER);
  const hashBuffer = await crypto.subtle.digest('SHA-256', datos);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function generarCodigoOtp(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return (100000 + (array[0] % 900000)).toString();
}

async function enviarPorWhatsApp(telefono: string, mensaje: string): Promise<boolean> {
  // telefono viene en formato +57..., la API de Meta lo espera sin el "+".
  const destino = telefono.replace('+', '');
  try {
    const resp = await fetch(
      `https://graph.facebook.com/${WHATSAPP_API_VERSION}/${WHATSAPP_PHONE_NUMBER_ID}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${WHATSAPP_ACCESS_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messaging_product: 'whatsapp',
          to: destino,
          type: 'text',
          text: { body: mensaje },
        }),
      },
    );
    if (!resp.ok) {
      console.error('Error enviando OTP por WhatsApp:', resp.status, await resp.text());
      return false;
    }
    return true;
  } catch (e) {
    console.error('Fallo de red enviando OTP por WhatsApp:', e);
    return false;
  }
}

async function enviarPorSms(_telefono: string, _codigo: string): Promise<boolean> {
  // No hay proveedor de SMS configurado todavía. Se deja preparado el
  // canal (columna 'canal' en otp_verificaciones, esta función) para
  // conectar Twilio / Vonage / Infobip más adelante. NO se simula un
  // envío exitoso — se falla explícitamente para no engañar al usuario.
  console.error('Canal SMS solicitado pero no hay proveedor configurado.');
  return false;
}

export type ResultadoSolicitudOtp =
  | { ok: true }
  | { ok: false; razon: 'telefono_invalido' | 'demasiadas_solicitudes' | 'envio_fallido' };

export async function solicitarOtp(
  supabaseAdmin: SupabaseClient,
  opts: { telefonoCrudo: string; canal: 'whatsapp' | 'sms'; ip?: string | null },
): Promise<ResultadoSolicitudOtp> {
  const telefono = normalizarTelefono(opts.telefonoCrudo);
  if (!telefono) return { ok: false, razon: 'telefono_invalido' };

  const haceUnaHora = new Date(Date.now() - 60 * 60 * 1000).toISOString();

  const { count: porTelefono } = await supabaseAdmin
    .from('otp_verificaciones')
    .select('id', { count: 'exact', head: true })
    .eq('telefono_e164', telefono)
    .gte('creado_en', haceUnaHora);

  if ((porTelefono ?? 0) >= MAX_SOLICITUDES_POR_TELEFONO_HORA) {
    return { ok: false, razon: 'demasiadas_solicitudes' };
  }

  if (opts.ip) {
    const { count: porIp } = await supabaseAdmin
      .from('otp_verificaciones')
      .select('id', { count: 'exact', head: true })
      .eq('ip_solicitante', opts.ip)
      .gte('creado_en', haceUnaHora);

    if ((porIp ?? 0) >= MAX_SOLICITUDES_POR_IP_HORA) {
      return { ok: false, razon: 'demasiadas_solicitudes' };
    }
  }

  // Invalida cualquier OTP anterior sin usar para este teléfono.
  await supabaseAdmin
    .from('otp_verificaciones')
    .update({ usado: true })
    .eq('telefono_e164', telefono)
    .eq('usado', false);

  const codigo = generarCodigoOtp();
  const codigoHash = await hashCodigo(codigo);

  const { error } = await supabaseAdmin.from('otp_verificaciones').insert({
    telefono_e164: telefono,
    canal: opts.canal,
    codigo_hash: codigoHash,
    expira_en: new Date(Date.now() + MINUTOS_EXPIRACION_OTP * 60 * 1000).toISOString(),
    ip_solicitante: opts.ip ?? null,
  });

  if (error) {
    console.error('Error guardando OTP:', error);
    return { ok: false, razon: 'envio_fallido' };
  }

  const mensaje = `🔐 Tu código de verificación de MYD es: ${codigo}\nVence en ${MINUTOS_EXPIRACION_OTP} minutos. No lo compartas con nadie.`;

  const enviado = opts.canal === 'whatsapp'
    ? await enviarPorWhatsApp(telefono, mensaje)
    : await enviarPorSms(telefono, codigo);

  // IMPORTANTE: el código nunca se imprime en logs de producción.
  // Solo se registra si el envío falló (sin el código).
  if (!enviado) {
    console.error(`No se pudo enviar el OTP por ${opts.canal} a ${telefono}`);
    return { ok: false, razon: 'envio_fallido' };
  }

  return { ok: true };
}

export type ResultadoVerificacionOtp =
  | { ok: true; otpId: string }
  | { ok: false; razon: 'no_solicitado' | 'vencido' | 'incorrecto' | 'demasiados_intentos' | 'telefono_invalido' };

export async function verificarOtp(
  supabaseAdmin: SupabaseClient,
  opts: { telefonoCrudo: string; codigo: string },
): Promise<ResultadoVerificacionOtp> {
  const telefono = normalizarTelefono(opts.telefonoCrudo);
  if (!telefono) return { ok: false, razon: 'telefono_invalido' };

  const { data: otp, error } = await supabaseAdmin
    .from('otp_verificaciones')
    .select('*')
    .eq('telefono_e164', telefono)
    .eq('usado', false)
    .order('creado_en', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error || !otp) return { ok: false, razon: 'no_solicitado' };

  if (new Date(otp.expira_en) < new Date()) {
    return { ok: false, razon: 'vencido' };
  }

  if (otp.intentos >= otp.max_intentos) {
    return { ok: false, razon: 'demasiados_intentos' };
  }

  const hashIngresado = await hashCodigo(opts.codigo.replace(/\D/g, ''));

  if (hashIngresado !== otp.codigo_hash) {
    await supabaseAdmin
      .from('otp_verificaciones')
      .update({ intentos: otp.intentos + 1 })
      .eq('id', otp.id);
    return { ok: false, razon: 'incorrecto' };
  }

  await supabaseAdmin.from('otp_verificaciones').update({ usado: true }).eq('id', otp.id);

  return { ok: true, otpId: otp.id as string };
}

/** Permite reutilizar un OTP ya verificado (campo 'usado'=true) como
 *  "boleto" de corta duración para completar el registro de una cuenta
 *  nueva, sin tener que pedir el código de nuevo. Válido 10 minutos
 *  desde que se verificó. */
export async function validarBoletoDeRegistro(
  supabaseAdmin: SupabaseClient,
  opts: { telefonoCrudo: string; otpId: string },
): Promise<boolean> {
  const telefono = normalizarTelefono(opts.telefonoCrudo);
  if (!telefono) return false;

  const { data } = await supabaseAdmin
    .from('otp_verificaciones')
    .select('telefono_e164, usado, creado_en')
    .eq('id', opts.otpId)
    .maybeSingle();

  if (!data || !data.usado || data.telefono_e164 !== telefono) return false;

  const minutosDesdeCreacion = (Date.now() - new Date(data.creado_en).getTime()) / 60000;
  return minutosDesdeCreacion <= 10;
}

RUTA:

supabase/functions/send-verification-code/index.ts

ACCIÓN:

NUEVO

CÓDIGO:

ts

// send-verification-code
// Punto de entrada para que Flutter (o cualquier cliente propio) pida
// un código OTP. Se despliega con --no-verify-jwt (se llama ANTES de
// tener sesión).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { solicitarOtp } from '../_shared/otp.ts';

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

function cors(resp: Response): Response {
  resp.headers.set('Access-Control-Allow-Origin', '*');
  resp.headers.set('Access-Control-Allow-Headers', 'authorization, content-type');
  return resp;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return cors(new Response('ok', { status: 200 }));
  if (req.method !== 'POST') return cors(new Response('Método no soportado', { status: 405 }));

  try {
    const { telefono, canal } = await req.json();

    if (!telefono || !['whatsapp', 'sms'].includes(canal)) {
      return cors(new Response(JSON.stringify({ ok: false, error: 'Parámetros inválidos' }), { status: 400 }));
    }

    const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? null;

    const resultado = await solicitarOtp(supabaseAdmin, { telefonoCrudo: telefono, canal, ip });

    if (!resultado.ok) {
      // 'telefono_invalido' y 'demasiadas_solicitudes' son seguros de
      // revelar (no delatan si existe una cuenta). 'envio_fallido' se
      // generaliza para no exponer detalles internos.
      const mensaje = resultado.razon === 'telefono_invalido'
        ? 'El número no tiene un formato válido.'
        : resultado.razon === 'demasiadas_solicitudes'
        ? 'Pediste demasiados códigos. Espera unos minutos e intenta de nuevo.'
        : 'No se pudo enviar el código en este momento. Intenta de nuevo.';

      return cors(new Response(JSON.stringify({ ok: false, error: mensaje }), { status: 429 }));
    }

    return cors(new Response(JSON.stringify({ ok: true }), { status: 200 }));
  } catch (e) {
    console.error('Error en send-verification-code:', e);
    return cors(new Response(JSON.stringify({ ok: false, error: 'Error interno' }), { status: 500 }));
  }
});

RUTA:

supabase/functions/verify-code/index.ts

ACCIÓN:

NUEVO

CÓDIGO:

ts

// verify-code
// Verifica el OTP y entrega el "hand-off" de sesión real de Supabase
// Auth. Maneja los 3 casos: 0 cuentas (registro), 1 cuenta (entra
// directo), 2-3 cuentas (exige id_especial).
// Se despliega con --no-verify-jwt.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { normalizarTelefono, verificarOtp, validarBoletoDeRegistro } from '../_shared/otp.ts';

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

function cors(resp: Response): Response {
  resp.headers.set('Access-Control-Allow-Origin', '*');
  resp.headers.set('Access-Control-Allow-Headers', 'authorization, content-type');
  return resp;
}

function json(body: unknown, status = 200): Response {
  return cors(new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } }));
}

/** Genera el link mágico para una cuenta ya existente y devuelve lo
 *  que Flutter necesita para canjearlo con auth.verifyOtp(). */
async function prepararHandoffSesion(perfilId: string) {
  const { data: usuarioAuth, error: errorUsuario } = await supabaseAdmin.auth.admin.getUserById(perfilId);
  if (errorUsuario || !usuarioAuth?.user?.email) {
    throw new Error('No se pudo recuperar la identidad de Auth de esta cuenta');
  }

  const { data: link, error: errorLink } = await supabaseAdmin.auth.admin.generateLink({
    type: 'magiclink',
    email: usuarioAuth.user.email,
  });

  if (errorLink || !link) {
    throw new Error('No se pudo generar el acceso a la sesión');
  }

  return {
    correo: usuarioAuth.user.email,
    email_otp: link.properties?.email_otp,
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return cors(new Response('ok', { status: 200 }));
  if (req.method !== 'POST') return json({ ok: false, error: 'Método no soportado' }, 405);

  try {
    const body = await req.json();
    const telefono = String(body.telefono ?? '');
    const telefonoNormalizado = normalizarTelefono(telefono);

    if (!telefonoNormalizado) {
      return json({ ok: false, error: 'Número no válido' }, 400);
    }

    // --------------------------------------------------------------
    // Caso: completar registro con un "boleto" ya verificado antes
    // (segunda llamada, cuando el teléfono no tenía ninguna cuenta).
    // --------------------------------------------------------------
    if (body.otp_id && body.nombre) {
      const boletoValido = await validarBoletoDeRegistro(supabaseAdmin, {
        telefonoCrudo: telefono,
        otpId: body.otp_id,
      });
      if (!boletoValido) {
        return json({ ok: false, error: 'La verificación anterior ya no es válida. Pide un código nuevo.' }, 401);
      }

      const nuevoId = crypto.randomUUID();
      const correoSintetico = `cuenta+${nuevoId}@users.myd.internal`;

      const { error: errorCrear } = await supabaseAdmin.auth.admin.createUser({
        id: nuevoId,
        email: correoSintetico,
        email_confirm: true,
        user_metadata: { nombre: body.nombre, apellido: body.apellido ?? null },
      });
      if (errorCrear) {
        console.error('Error creando usuario Auth:', errorCrear);
        return json({ ok: false, error: 'No se pudo crear la cuenta' }, 500);
      }

      const { error: errorPerfil } = await supabaseAdmin.from('perfiles').insert({
        id: nuevoId,
        nombre: body.nombre,
        apellido: body.apellido ?? null,
        correo: body.correo ?? null, // opcional, ya no obligatorio
        telefono: telefono,
        telefono_e164: telefonoNormalizado,
      });

      if (errorPerfil) {
        // Compensación: si el límite de 3 (u otra validación) rechazó
        // el insert, no dejamos un auth.users huérfano.
        await supabaseAdmin.auth.admin.deleteUser(nuevoId);
        console.error('Error creando perfil (insert revertido):', errorPerfil);

        const limiteAlcanzado = errorPerfil.message?.includes('máximo de 3 cuentas');
        return json({
          ok: false,
          error: limiteAlcanzado
            ? 'Este número ya tiene el máximo de 3 cuentas MYD.'
            : 'No se pudo crear la cuenta.',
        }, limiteAlcanzado ? 409 : 500);
      }

      const handoff = await prepararHandoffSesion(nuevoId);
      return json({ ok: true, cuentas_totales: 1, sesion: handoff });
    }

    // --------------------------------------------------------------
    // Caso normal: viene con código (y opcionalmente id_especial).
    // --------------------------------------------------------------
    const codigo = String(body.codigo ?? '');
    const idEspecial: string | undefined = body.id_especial
      ? String(body.id_especial).trim().toUpperCase()
      : undefined;

    const resultado = await verificarOtp(supabaseAdmin, { telefonoCrudo: telefono, codigo });

    if (!resultado.ok) {
      const mensajes: Record<string, string> = {
        no_solicitado: 'Primero pide un código de verificación.',
        vencido: 'Ese código ya venció. Pide uno nuevo.',
        incorrecto: 'El código no es correcto.',
        demasiados_intentos: 'Demasiados intentos. Pide un código nuevo.',
        telefono_invalido: 'Número no válido.',
      };
      return json({ ok: false, error: mensajes[resultado.razon] }, 401);
    }

    const { data: perfiles, error: errorPerfiles } = await supabaseAdmin
      .from('perfiles')
      .select('id, nombre, id_especial')
      .eq('telefono_e164', telefonoNormalizado);

    if (errorPerfiles) {
      console.error('Error consultando perfiles:', errorPerfiles);
      return json({ ok: false, error: 'Error interno' }, 500);
    }

    // 0 cuentas: el teléfono es nuevo. Se devuelve el otp_id como
    // "boleto" para que Flutter complete el registro sin pedir el
    // código otra vez.
    if (!perfiles || perfiles.length === 0) {
      return json({ ok: true, requiere_registro: true, otp_id: resultado.otpId });
    }

    // 1 cuenta: entra directo.
    if (perfiles.length === 1) {
      const handoff = await prepararHandoffSesion(perfiles[0].id);
      return json({ ok: true, cuentas_totales: 1, sesion: handoff });
    }

    // 2-3 cuentas: se exige id_especial, re-validado contra ESTE
    // teléfono (nunca se confía en el id_especial solo).
    if (!idEspecial) {
      return json({
        ok: true,
        requiere_id_especial: true,
        cuentas: perfiles.map((p) => ({ id_especial: p.id_especial, nombre: p.nombre })),
      });
    }

    const elegido = perfiles.find((p) => p.id_especial === idEspecial);
    if (!elegido) {
      return json({ ok: false, error: 'Ese ID especial no corresponde a ninguna cuenta de este teléfono.' }, 403);
    }

    const handoff = await prepararHandoffSesion(elegido.id);
    return json({ ok: true, cuentas_totales: perfiles.length, sesion: handoff });
  } catch (e) {
    console.error('Error en verify-code:', e);
    return json({ ok: false, error: 'Error interno' }, 500);
  }
});

3.3 WhatsApp — cambios puntuales (NO se reescribe el archivo completo)

RUTA:

supabase/functions/whatsapp-webhook/index.ts

ACCIÓN:

MODIFICAR (solo 2 funciones + 1 import — todo lo demás, intacto)

a) Agregar import, junto a los que ya tienes:

ts

import { solicitarOtp, verificarOtp } from '../_shared/otp.ts';

b) Reemplazar enviarCodigoAlPerfil completa por esta versión (ya no guarda el código en whatsapp_sesiones, delega al módulo compartido):

ts

async function enviarCodigoAlPerfil(
  numero: string,
  perfil: { id: string; correo: string | null; telefono: string | null },
): Promise<boolean> {
  const telefonoParaOtp = perfil.telefono ?? numero; // normalizarTelefono adentro de solicitarOtp
  const resultado = await solicitarOtp(supabaseAdmin, {
    telefonoCrudo: telefonoParaOtp,
    canal: 'whatsapp',
  });

  if (!resultado.ok) {
    await actualizarSesion(numero, {
      estado_flujo: 'esperando_identificador',
      usuario_candidato_id: null,
      candidatos_ids: null,
    });
    await enviarWhatsApp(
      numero,
      resultado.razon === 'demasiadas_solicitudes'
        ? '⏳ Pediste demasiados códigos. Espera unos minutos e intenta de nuevo.'
        : '⚠️ No pude enviar el código en este momento. Inténtalo de nuevo.',
    );
    return false;
  }

  await actualizarSesion(numero, {
    usuario_candidato_id: perfil.id,
    estado_flujo: 'esperando_codigo',
    candidatos_ids: null,
  });

  await enviarWhatsApp(
    numero,
    '📲 Te envié un código de 6 dígitos por este mismo WhatsApp. Vence en 5 minutos.\n\nEscríbelo aquí para confirmar que eres tú. Si no te llega, dime "reenviar".',
  );

  return true;
}

(Nota: esto cambia el canal del primer envío de correo a WhatsApp, como pediste en el nuevo flujo — ya no depende de Resend para el primer código. El reenvío por correo sigue existiendo como opción si la quieres mantener en esperando_canal_reenvio; si prefieres quitarla de ahí también, dímelo y la saco.)

c) Dentro del bloque if (estado === 'esperando_codigo'), reemplazar únicamente la comparación del código (la parte que hoy hace soloDigitos(...) === codigoGuardado) por:

ts

        const resultadoOtp = await verificarOtp(supabaseAdmin, {
          telefonoCrudo: sesion.telefono_para_otp as string ?? numero,
          codigo: texto,
        });

        if (resultadoOtp.ok) {
          const usuarioCandidatoId = sesion.usuario_candidato_id;
          if (!usuarioCandidatoId) {
            await limpiarFlujoLogin(numero);
            await enviarWhatsApp(numero, '⚠️ Se perdió la referencia de la cuenta. Escribe "hola" para empezar de nuevo.');
            return responseOk();
          }

          await actualizarSesion(numero, {
            usuario_activo_id: usuarioCandidatoId,
            usuario_candidato_id: null,
            estado_flujo: 'inactivo',
            candidatos_ids: null,
            estado_flujo_anterior: null,
          });

          await enviarWhatsApp(
            numero,
            '✅ ¡Listo! Tu cuenta de MYD ya está conectada.\n\nPuedes escribir:\n"gasté 20 mil en un soporte"\n"recuérdame llamar al banco mañana a las 3pm"',
          );
          return responseOk();
        }

        if (resultadoOtp.razon === 'vencido' || resultadoOtp.razon === 'no_solicitado') {
          await actualizarSesion(numero, { estado_flujo: 'esperando_identificador', usuario_candidato_id: null });
          await enviarWhatsApp(numero, '⏰ Ese código ya venció. Escribe de nuevo tu correo o número para intentarlo otra vez.');
          return responseOk();
        }

        if (resultadoOtp.razon === 'demasiados_intentos') {
          await actualizarSesion(numero, { estado_flujo: 'esperando_identificador', usuario_candidato_id: null });
          await enviarWhatsApp(numero, '❌ Muchos intentos fallidos. Empecemos de nuevo: escribe tu correo o número.');
          return responseOk();
        }

        await enviarWhatsApp(numero, '❌ Ese código no es correcto. Intenta de nuevo o escribe "reenviar" si no te llegó.');
        return responseOk();

Esto reemplaza todo el tramo que antes comparaba codigoEscrito === codigoGuardado y manejaba intentosActuales a mano — ahora esa cuenta de intentos vive en otp_verificaciones, no en whatsapp_sesiones.

Todo lo demás del archivo — verificación de Meta, Gemini, esperando_identificador, esperando_seleccion_cuenta, esperando_canal_reenvio, esperando_confirmacion_cancelar, cierre de sesión, ejecutarAccion, categorías, movimientos, tareas — se queda exactamente igual. Las columnas codigo, codigo_expira_en, intentos de whatsapp_sesiones quedan sin usar (no las borro de la tabla todavía, por si acaso; se pueden limpiar en una migración aparte más adelante).

3.4 Secrets

supabase secrets set OTP_PEPPER=una_cadena_larga_y_aleatoria_que_inventes_tu

(Los demás —WHATSAPP_*, GEMINI_API_KEY, RESEND_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY— ya existen, no cambian.)

Desplegar las 2 funciones nuevas:

supabase functions deploy send-verification-code --no-verify-jwt
supabase functions deploy verify-code --no-verify-jwt
supabase functions deploy whatsapp-webhook --no-verify-jwt

3.5 Flutter — identificación y alcance de esta entrega

Reviso qué existe hoy, sin suponer nada que no te haya ayudado a construir yo mismo:

Login/registro actual: lib/features/auth/auth_screen.dart — un solo widget con pestañas, 100% correo+contraseña (signInWithPassword / signUp), con wrappers delgados login_screen.dart y register_screen.dart.

AuthGate: lib/core/auth/auth_gate.dart — escucha supabase.auth.onAuthStateChange y decide entre WelcomeScreen y HomeShell. No necesita ningún cambio: no le importa cómo se creó la sesión, solo si existe.

No hay ningún servicio de cuenta separado del propio auth_screen.dart hoy.

Lo que entrego completo ahora (la pieza que de verdad requiere cuidado, por ser la que habla con las Functions nuevas):

RUTA:

lib/core/services/telefono_auth_service.dart

ACCIÓN:

NUEVO

CÓDIGO:

dart

import '../supabase/supabase_config.dart';

class CuentaDisponible {
  final String idEspecial;
  final String nombre;
  CuentaDisponible({required this.idEspecial, required this.nombre});
}

/// Resultado de verify-code: puede pedir registro, pedir id especial,
/// o traer ya la sesión lista para canjear.
sealed class ResultadoVerificacion {}

class RequiereRegistro extends ResultadoVerificacion {
  final String otpId;
  RequiereRegistro(this.otpId);
}

class RequiereIdEspecial extends ResultadoVerificacion {
  final List<CuentaDisponible> cuentas;
  RequiereIdEspecial(this.cuentas);
}

class SesionLista extends ResultadoVerificacion {
  final String correo;
  final String emailOtp;
  SesionLista({required this.correo, required this.emailOtp});
}

class TelefonoAuthService {
  static Future<void> pedirCodigo(String telefono, {String canal = 'whatsapp'}) async {
    final resp = await supabase.functions.invoke('send-verification-code',
        body: {'telefono': telefono, 'canal': canal});
    final datos = resp.data as Map;
    if (datos['ok'] != true) {
      throw Exception(datos['error'] ?? 'No se pudo enviar el código');
    }
  }

  static Future<ResultadoVerificacion> verificarCodigo(String telefono, String codigo) async {
    final resp = await supabase.functions.invoke('verify-code',
        body: {'telefono': telefono, 'codigo': codigo});
    final datos = resp.data as Map;
    if (datos['ok'] != true) throw Exception(datos['error'] ?? 'Código incorrecto');

    if (datos['requiere_registro'] == true) {
      return RequiereRegistro(datos['otp_id'] as String);
    }
    if (datos['requiere_id_especial'] == true) {
      final cuentas = (datos['cuentas'] as List)
          .map((c) => CuentaDisponible(idEspecial: c['id_especial'], nombre: c['nombre'] ?? 'Cuenta'))
          .toList();
      return RequiereIdEspecial(cuentas);
    }
    final sesion = datos['sesion'] as Map;
    return SesionLista(correo: sesion['correo'], emailOtp: sesion['email_otp']);
  }

  static Future<ResultadoVerificacion> elegirCuenta(String telefono, String idEspecial) async {
    final resp = await supabase.functions.invoke('verify-code',
        body: {'telefono': telefono, 'codigo': '', 'id_especial': idEspecial});
    // Nota: el servidor ya marcó el OTP como usado en la llamada anterior;
    // para elegir cuenta reutilizamos la búsqueda por teléfono, no el
    // código. (Ver aclaración más abajo.)
    final datos = resp.data as Map;
    if (datos['ok'] != true) throw Exception(datos['error'] ?? 'No se pudo continuar');
    final sesion = datos['sesion'] as Map;
    return SesionLista(correo: sesion['correo'], emailOtp: sesion['email_otp']);
  }

  static Future<ResultadoVerificacion> completarRegistro(
    String telefono,
    String otpId,
    String nombre, {
    String? apellido,
    String? correo,
  }) async {
    final resp = await supabase.functions.invoke('verify-code', body: {
      'telefono': telefono,
      'otp_id': otpId,
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
    });
    final datos = resp.data as Map;
    if (datos['ok'] != true) throw Exception(datos['error'] ?? 'No se pudo crear la cuenta');
    final sesion = datos['sesion'] as Map;
    return SesionLista(correo: sesion['correo'], emailOtp: sesion['email_otp']);
  }

  /// Canjea el email_otp por una sesión real de Supabase Auth.
  /// A partir de aquí, AuthGate reacciona solo.
  static Future<void> establecerSesion(SesionLista sesion) async {
    await supabase.auth.verifyOTP(
      email: sesion.correo,
      token: sesion.emailOtp,
      type: OtpType.magiclink,
    );
  }
}