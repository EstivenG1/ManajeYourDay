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