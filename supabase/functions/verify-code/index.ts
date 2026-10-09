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



    // -----------------------------------------------------------------------------
// Selección de cuenta después de haber validado el OTP
// -----------------------------------------------------------------------------

if (body.otp_id && body.id_especial) {
  const otpValido = await consumirBoletoVerificado(
    telefono,
    String(body.otp_id),
  );

  if (!otpValido) {
    return json(
      {
        ok: false,
        error: 'La verificación expiró o ya fue utilizada.',
      },
      400,
    );
  }

  const idEspecial = String(body.id_especial)
    .trim()
    .toUpperCase();

  const { data: perfil, error: perfilError } =
    await supabaseAdmin
      .from('perfiles')
      .select('id, nombre, correo, telefono, id_especial')
      .eq('telefono', telefono)
      .eq('id_especial', idEspecial)
      .maybeSingle();

  if (perfilError || !perfil) {
    return json(
      {
        ok: false,
        error: 'La cuenta seleccionada no es válida.',
      },
      400,
    );
  }

  const sesion = await prepararHandoffSesion(perfil.id);

  return json({
    ok: true,
    sesion,
  });
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
