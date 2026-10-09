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