// Edge Function: whatsapp-webhook
// MYD (Manage Your Day) — WhatsApp + Supabase + Gemini + Resend
//
// Esta versión mantiene el flujo original y corrige:
// - URLs de WhatsApp, Resend y Gemini.
// - Interpolaciones y consultas Supabase que tenían sintaxis inválida.
// - Validación de variables de entorno.
// - Atajos determinísticos para saludos, opciones, códigos y cancelación.
// - Manejo de errores de Supabase/Gemini/Resend.
// - Confirmación de cancelación: "sí" y "no" ya no se confunden.
// - Conversaciones vencidas por inactividad.
// - Fechas de tareas interpretadas en la zona horaria America/Bogota.
// - Mensajes más consistentes y código más fácil de mantener.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { solicitarOtp, verificarOtp } from '../_shared/otp.ts';
// -----------------------------------------------------------------------------
// Configuración
// -----------------------------------------------------------------------------

const WHATSAPP_API_VERSION = Deno.env.get('WHATSAPP_API_VERSION') ?? 'v26.0';
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.5-flash-lite';

function requireEnv(nombre: string): string {
  const valor = Deno.env.get(nombre)?.trim();

  if (!valor) {
    throw new Error(`Falta la variable de entorno requerida: ${nombre}`);
  }

  return valor;
}

const WHATSAPP_VERIFY_TOKEN = requireEnv('WHATSAPP_VERIFY_TOKEN');
const WHATSAPP_ACCESS_TOKEN = requireEnv('WHATSAPP_ACCESS_TOKEN');
const WHATSAPP_PHONE_NUMBER_ID = requireEnv('WHATSAPP_PHONE_NUMBER_ID');
const RESEND_API_KEY = requireEnv('RESEND_API_KEY');
const GEMINI_API_KEY = requireEnv('GEMINI_API_KEY');

const SUPABASE_URL = requireEnv('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = requireEnv('SUPABASE_SERVICE_ROLE_KEY');

const MINUTOS_VENCIMIENTO_FLUJO = 15;

const supabaseAdmin = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
);

// Estados que representan un flujo de login en progreso.
const ESTADOS_DE_LOGIN = new Set([
  'esperando_identificador',
  'esperando_seleccion_cuenta',
  'esperando_codigo',
  'esperando_canal_reenvio',
  'esperando_confirmacion_cancelar',
]);

type Perfil = {
  id: string;
  nombre: string | null;
  correo: string | null;
  telefono?: string | null;
  id_especial?: string | null;
};

type ResultadoIntencion = {
  intencion?: string;
  identificador?: string | null;
  codigo?: string | null;
  opcion_numero?: number | null;
};

type ResultadoRegistro = {
  accion?: string;
  monto?: number | null;
  categoria?: string | null;
  descripcion?: string | null;
  titulo_tarea?: string | null;
  fecha_limite_tarea?: string | null;
  prioridad_tarea?: 'alta' | 'media' | 'baja' | null;
  mensaje_para_usuario: string;
};

// -----------------------------------------------------------------------------
// Utilidades
// -----------------------------------------------------------------------------

function responseOk(): Response {
  // Meta espera una respuesta 2xx. Mantenemos 200 incluso ante errores internos
  // para evitar reintentos innecesarios del webhook por un fallo de procesamiento.
  return new Response('ok', { status: 200 });
}

function textoNormalizado(texto: string): string {
  return texto
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

function soloDigitos(texto: string): string {
  return texto.replace(/\D/g, '');
}


function esSaludo(texto: string): boolean {
  const limpio = textoNormalizado(texto);

  const saludosExactos = new Set([
    'hola',
    'buenas',
    'buen dia',
    'buenas tardes',
    'buenas noches',
    'inicio',
    'iniciar',
    'entrar',
    'quiero entrar',
    'login',
    'connect',
    'myd',
  ]);

  if (saludosExactos.has(limpio)) return true;

  // Acepta variantes como "holaaa", "buenasss", etc.
  if (/^hol+a+$/i.test(limpio)) return true;
  if (/^buen+a+s*$/i.test(limpio)) return true;

  return false;
}

function esCancelacionDirecta(texto: string): boolean {
  const limpio = textoNormalizado(texto);

  return new Set([
    'cancelar',
    'cancela',
    'salir',
    'ya no',
    'chao',
    'adios',
    'dejar asi',
    'dejalo',
    'olvidalo',
  ]).has(limpio);
}

function esConfirmacionSi(texto: string): boolean {
  return new Set([
    'si',
    'sí',
    'ok',
    'okay',
    'acepto',
    'confirmo',
    'confirmar',
    'dale',
    'hazlo',
  ]).has(textoNormalizado(texto));
}

function esConfirmacionNo(texto: string): boolean {
  return new Set([
    'no',
    'nop',
    'cancelar',
    'mejor no',
    'no quiero',
  ]).has(textoNormalizado(texto));
}

function esPedidoReenvio(texto: string): boolean {
  const limpio = textoNormalizado(texto);

  return (
    limpio.includes('reenvia') ||
    limpio.includes('reenviar') ||
    limpio.includes('otra vez') ||
    limpio.includes('no me llego') ||
    limpio.includes('no llego')
  );
}

function esSolicitudCerrarSesion(texto: string): boolean {
  const limpio = textoNormalizado(texto);

  return (
    limpio === 'cerrar sesion' ||
    limpio === 'cerrar sesión' ||
    limpio === 'salir' ||
    limpio === 'desconectar' ||
    limpio === 'cambiar de cuenta'
  );
}

function esSolicitudVerCuenta(texto: string): boolean {
  const limpio = textoNormalizado(texto);

  return (
    limpio.includes('que cuenta tengo') ||
    limpio.includes('qué cuenta tengo') ||
    limpio.includes('cuenta conectada') ||
    limpio.includes('con que cuenta') ||
    limpio.includes('con qué cuenta')
  );
}

function enmascararCorreo(correo: string): string {
  const limpio = correo.trim();

  const [usuario, dominio] = limpio.split('@');

  if (!usuario || !dominio) {
    return limpio;
  }

  if (usuario.length <= 2) {
    return `${usuario[0] ?? '*'}***@${dominio}`;
  }

  return `${usuario.slice(0, 2)}***@${dominio}`;
}

function obtenerAhoraBogota(): string {
  return new Intl.DateTimeFormat('es-CO', {
    dateStyle: 'full',
    timeStyle: 'short',
    timeZone: 'America/Bogota',
  }).format(new Date());
}

function obtenerIsoSeguro(
  fecha: string | null | undefined,
  respaldoHoras = 24,
): string {
  if (fecha) {
    const fechaParseada = new Date(fecha);

    if (!Number.isNaN(fechaParseada.getTime())) {
      return fechaParseada.toISOString();
    }
  }

  return new Date(
    Date.now() + respaldoHoras * 60 * 60 * 1000,
  ).toISOString();
}

// -----------------------------------------------------------------------------
// WhatsApp
// -----------------------------------------------------------------------------

async function enviarWhatsApp(
  numeroDestino: string,
  mensaje: string,
): Promise<boolean> {
  try {
    const url =
      `https://graph.facebook.com/${WHATSAPP_API_VERSION}/${WHATSAPP_PHONE_NUMBER_ID}/messages`;

    const respuesta = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${WHATSAPP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to: numeroDestino,
        type: 'text',
        text: {
          body: mensaje,
        },
      }),
    });

    if (!respuesta.ok) {
      console.error(
        'Error al enviar WhatsApp:',
        respuesta.status,
        await respuesta.text(),
      );
      return false;
    }

    return true;
  } catch (error) {
    console.error('Fallo de red enviando WhatsApp:', error);
    return false;
  }
}

// -----------------------------------------------------------------------------
// Resend
// -----------------------------------------------------------------------------

async function enviarCodigoPorCorreo(correo: string, codigo: string) {
  console.log(`📧 Intentando enviar código a: ${correo}`);

  if (!RESEND_API_KEY) {
    console.error('❌ RESEND_API_KEY no está configurada.');
    return false;
  }

  const respuesta = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'MYD <onboarding@resend.dev>',
      to: [correo],
      subject: 'Tu código de verificación de MYD',
      html: `
        <p>Tu código para conectar WhatsApp con MYD es:</p>
        <h2 style="letter-spacing:4px">${codigo}</h2>
        <p>Vence en 5 minutos.</p>
        <p>Si no fuiste tú, ignora este correo.</p>
      `,
    }),
  });

  const respuestaTexto = await respuesta.text();

  if (!respuesta.ok) {
    console.error('❌ Resend rechazó el correo');
    console.error('HTTP:', respuesta.status);
    console.error('Respuesta:', respuestaTexto);
    return false;
  }

  console.log('✅ Correo enviado correctamente:', respuestaTexto);
  return true;
}

// -----------------------------------------------------------------------------
// Supabase — sesiones
// -----------------------------------------------------------------------------

async function actualizarSesion(
  numero: string,
  cambios: Record<string, unknown>,
): Promise<boolean> {
  const { error } = await supabaseAdmin
    .from('whatsapp_sesiones')
    .update({
      ...cambios,
      actualizado_en: new Date().toISOString(),
    })
    .eq('numero_whatsapp', numero);

  if (error) {
    console.error('Error actualizando whatsapp_sesiones:', error);
    return false;
  }

  return true;
}

async function obtenerOCrearSesion(numero: string) {
  const { data: sesionExistente, error: errorConsulta } = await supabaseAdmin
    .from('whatsapp_sesiones')
    .select('*')
    .eq('numero_whatsapp', numero)
    .maybeSingle();

  if (errorConsulta) {
    console.error('Error consultando sesión de WhatsApp:', errorConsulta);
    return null;
  }

  if (sesionExistente) {
    return sesionExistente;
  }

  const { data: nuevaSesion, error: errorCreacion } = await supabaseAdmin
    .from('whatsapp_sesiones')
    .insert({
      numero_whatsapp: numero,
      estado_flujo: 'inactivo',
    })
    .select('*')
    .single();

  if (errorCreacion) {
    console.error('Error creando sesión de WhatsApp:', errorCreacion);
    return null;
  }

  return nuevaSesion;
}

async function limpiarFlujoLogin(numero: string): Promise<void> {
  await actualizarSesion(numero, {
    estado_flujo: 'inactivo',
    estado_flujo_anterior: null,
    codigo: null,
    codigo_expira_en: null,
    candidatos_ids: null,
    usuario_candidato_id: null,
    intentos: 0,
  });
}

// -----------------------------------------------------------------------------
// Buscar cuentas
// -----------------------------------------------------------------------------

async function buscarPerfilesPorIdentificador(
  identificador: string,
): Promise<Perfil[]> {
  const texto = identificador.trim().toLowerCase();

  if (!texto) {
    return [];
  }

  if (texto.includes('@')) {
    const { data, error } = await supabaseAdmin
      .from('perfiles')
      .select('id, nombre, correo, telefono')
      .ilike('correo', texto);

    if (error) {
      console.error('Error buscando por correo:', error);
      return [];
    }

    return data ?? [];
  }

  const digitos = soloDigitos(texto).slice(-10);

  if (digitos.length < 7) {
    return [];
  }

  // Se mantiene la búsqueda por todos los perfiles para que funcione aunque
  // la columna telefono no esté normalizada en la base de datos.
  const { data: perfiles, error } = await supabaseAdmin
    .from('perfiles')
    .select('id, nombre, correo, telefono');

  if (error) {
    console.error('Error buscando perfiles:', error);
    return [];
  }

  return (perfiles ?? []).filter(
    (perfil: { telefono: string | null }) =>
      Boolean(perfil.telefono) &&
      soloDigitos(perfil.telefono!).slice(-10) === digitos,
  );
}

// -----------------------------------------------------------------------------
// Gemini — clasificación
// -----------------------------------------------------------------------------

const ESQUEMA_INTENCION = {
  type: 'OBJECT',
  properties: {
    intencion: {
      type: 'STRING',
      enum: [
        'iniciar_sesion',
        'cancelar',
        'confirma_si',
        'confirma_no',
        'da_identificador',
        'da_codigo',
        'elige_opcion_numerada',
        'pide_reenvio_codigo',
        'elige_canal_correo',
        'elige_canal_whatsapp',
        'cerrar_sesion',
        'ver_cuenta_actual',
        'otro',
      ],
    },
    identificador: {
      type: 'STRING',
      nullable: true,
      description:
        'Correo o teléfono si el mensaje trae uno.',
    },
    codigo: {
      type: 'STRING',
      nullable: true,
      description:
        'Secuencia de dígitos si parece un código de verificación.',
    },
    opcion_numero: {
      type: 'NUMBER',
      nullable: true,
      description:
        'Número de opción elegido de una lista numerada.',
    },
  },
  required: ['intencion'],
};

async function clasificarIntencion(
  texto: string,
  estadoActual: string,
  opciones?: string[],
): Promise<ResultadoIntencion> {
  const contextoOpciones = opciones?.length
    ? `

Opciones numeradas disponibles ahora mismo:
${opciones.map((opcion, indice) => `${indice + 1}. ${opcion}`).join('\n')}`
    : '';

  const systemPrompt = `Eres el clasificador de intenciones del asistente de WhatsApp de MYD.
Estado actual: "${estadoActual}".${contextoOpciones}

Clasifica mensajes en español con lenguaje natural, sin ser literal.
Reglas:
- Saludo o deseo de entrar: iniciar_sesion.
- Quiere cancelar, salir del proceso o detenerse: cancelar.
- Si contiene correo o teléfono: da_identificador y extrae identificador.
- Si contiene un código de 6 dígitos: da_codigo y extrae codigo.
- Si elige una opción de una lista: elige_opcion_numerada y extrae opcion_numero.
- Si pide reenviar el código: pide_reenvio_codigo.
- Si elige correo: elige_canal_correo.
- Si elige WhatsApp/SMS: elige_canal_whatsapp.
- Si quiere cerrar sesión o cambiar de cuenta: cerrar_sesion.
- Si pregunta por la cuenta conectada: ver_cuenta_actual.
- Confirmación positiva: confirma_si.
- Confirmación negativa: confirma_no.
- En cualquier otro caso: otro.`;

  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

    const respuesta = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify({
        system_instruction: {
          parts: [{ text: systemPrompt }],
        },
        contents: [
          {
            role: 'user',
            parts: [{ text: texto }],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: ESQUEMA_INTENCION,
        },
      }),
    });

    if (!respuesta.ok) {
      console.error(
        'Error de Gemini (clasificarIntencion):',
        respuesta.status,
        await respuesta.text(),
      );
      return { intencion: 'otro' };
    }

    const json = await respuesta.json();
    const textoRespuesta =
      json?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!textoRespuesta) {
      console.error('Gemini no devolvió contenido para clasificar.');
      return { intencion: 'otro' };
    }

    const resultado = JSON.parse(textoRespuesta) as ResultadoIntencion;

    return resultado;
  } catch (error) {
    console.error('Fallo en clasificarIntencion:', error);
    return { intencion: 'otro' };
  }
}

// -----------------------------------------------------------------------------
// Gemini — finanzas y tareas
// -----------------------------------------------------------------------------

const ESQUEMA_REGISTRO = {
  type: 'OBJECT',
  properties: {
    accion: {
      type: 'STRING',
      enum: [
        'registrar_gasto',
        'registrar_ingreso',
        'registrar_tarea',
        'cerrar_sesion',
        'ver_cuenta',
        'otro',
      ],
    },
    monto: {
      type: 'NUMBER',
      nullable: true,
      description:
        'Monto numérico. Convierte expresiones como "20 mil" a 20000.',
    },
    categoria: {
      type: 'STRING',
      nullable: true,
      description:
        'Categoría breve y clara. Usa una categoría existente si aplica.',
    },
    descripcion: {
      type: 'STRING',
      nullable: true,
    },
    titulo_tarea: {
      type: 'STRING',
      nullable: true,
    },
    fecha_limite_tarea: {
      type: 'STRING',
      nullable: true,
      description:
        'Fecha y hora en ISO 8601. Usa la zona horaria America/Bogota.',
    },
    prioridad_tarea: {
      type: 'STRING',
      enum: ['alta', 'media', 'baja'],
      nullable: true,
    },
    mensaje_para_usuario: {
      type: 'STRING',
    },
  },
  required: ['accion', 'mensaje_para_usuario'],
};

async function llamarGemini(opts: {
  textoUsuario: string;
  nombreUsuario: string;
  categorias: { nombre: string; tipo: string }[];
}): Promise<ResultadoRegistro> {
  const ahoraBogota = obtenerAhoraBogota();

  const nombresCategorias = opts.categorias
    .map((categoria) => `${categoria.nombre} (${categoria.tipo})`)
    .join(', ');

  const systemPrompt = `Eres el asistente de WhatsApp de MYD (Manage Your Day), una app de finanzas personales y tareas.

Usuario: ${opts.nombreUsuario}
Fecha y hora actual en Colombia (America/Bogota): ${ahoraBogota}
Categorías existentes: ${nombresCategorias || 'ninguna todavía'}

Decide qué acción representa el mensaje:
- registrar_gasto: dinero gastado.
- registrar_ingreso: dinero recibido.
- registrar_tarea: algo que debe hacer, recordar o programar.
- cerrar_sesion: quiere desconectarse o cambiar de cuenta.
- ver_cuenta: pregunta por la cuenta conectada.
- otro: saludo, pregunta general o falta un dato esencial.

Reglas importantes:
1. Nunca inventes un monto.
2. "20 mil", "20k" y expresiones equivalentes deben convertirse a 20000.
3. Usa una categoría existente cuando haya una coincidencia razonable.
4. Si no existe una categoría adecuada, devuelve una categoría corta y clara para que el sistema pueda crearla.
5. Para fecha_limite_tarea devuelve SIEMPRE una fecha ISO 8601 válida.
6. Si el usuario dice "mañana", "hoy", etc., calcula la fecha usando America/Bogota.
7. mensaje_para_usuario debe ser natural, breve y en español, máximo 2 o 3 líneas.`;

  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

    const respuesta = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': GEMINI_API_KEY,
      },
      body: JSON.stringify({
        system_instruction: {
          parts: [{ text: systemPrompt }],
        },
        contents: [
          {
            role: 'user',
            parts: [{ text: opts.textoUsuario }],
          },
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: ESQUEMA_REGISTRO,
        },
      }),
    });

    if (!respuesta.ok) {
      console.error(
        'Error de Gemini (llamarGemini):',
        respuesta.status,
        await respuesta.text(),
      );

      return {
        accion: 'otro',
        mensaje_para_usuario:
          'Tuve un problema entendiendo tu mensaje 😅. Intenta de nuevo en un momento.',
      };
    }

    const json = await respuesta.json();
    const textoRespuesta =
      json?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!textoRespuesta) {
      return {
        accion: 'otro',
        mensaje_para_usuario:
          'No pude interpretar tu mensaje 😅. Intenta escribirlo de otra forma.',
      };
    }

    return JSON.parse(textoRespuesta) as ResultadoRegistro;
  } catch (error) {
    console.error('Fallo en llamarGemini:', error);

    return {
      accion: 'otro',
      mensaje_para_usuario:
        'Lo siento, ocurrió un error procesando tu solicitud en este momento.',
    };
  }
}

// -----------------------------------------------------------------------------
// Categorías y movimientos
// -----------------------------------------------------------------------------

async function obtenerOCrearCategoria(
  usuarioId: string,
  nombre: string,
  tipo: 'ingreso' | 'gasto',
): Promise<string | null> {
  const nombreLimpio = nombre.trim();

  if (!nombreLimpio) {
    return null;
  }

  const filtroUsuario =
    `usuario_id.is.null,usuario_id.eq.${usuarioId}`;

  const { data: existente, error: errorBusqueda } = await supabaseAdmin
    .from('categorias')
    .select('id')
    .eq('tipo', tipo)
    .ilike('nombre', nombreLimpio)
    .or(filtroUsuario)
    .limit(1)
    .maybeSingle();

  if (errorBusqueda) {
    console.error('Error buscando categoría:', errorBusqueda);
    return null;
  }

  if (existente?.id) {
    return existente.id as string;
  }

  const { data: nueva, error: errorCreacion } = await supabaseAdmin
    .from('categorias')
    .insert({
      usuario_id: usuarioId,
      nombre: nombreLimpio,
      tipo,
    })
    .select('id')
    .single();

  if (errorCreacion) {
    console.error('Error creando categoría:', errorCreacion);
    return null;
  }

  return (nueva?.id as string | undefined) ?? null;
}

async function ejecutarAccion(
  usuarioId: string,
  resultado: ResultadoRegistro,
): Promise<boolean> {
  const accion = resultado.accion;

  if (accion === 'registrar_gasto' || accion === 'registrar_ingreso') {
    const tipo = accion === 'registrar_gasto' ? 'gasto' : 'ingreso';
    const monto = Number(resultado.monto);

    if (!Number.isFinite(monto) || monto <= 0) {
      console.warn('Movimiento rechazado: monto inválido.', resultado);
      return false;
    }

    const categoriaId = await obtenerOCrearCategoria(
      usuarioId,
      resultado.categoria ??
        (tipo === 'gasto' ? 'Otros gastos' : 'Otros ingresos'),
      tipo,
    );

    if (!categoriaId) {
      return false;
    }

    const { error } = await supabaseAdmin
      .from('movimientos')
      .insert({
        usuario_id: usuarioId,
        categoria_id: categoriaId,
        tipo,
        monto,
        descripcion: resultado.descripcion?.trim() || null,
        fecha: new Date().toISOString().slice(0, 10),
      });

    if (error) {
      console.error('Error registrando movimiento:', error);
      return false;
    }

    return true;
  }

  if (accion === 'registrar_tarea') {
    const titulo = resultado.titulo_tarea?.trim() || 'Tarea desde WhatsApp';
    const fechaLimite = obtenerIsoSeguro(resultado.fecha_limite_tarea, 24);
    const prioridad = resultado.prioridad_tarea ?? 'media';

    const { error } = await supabaseAdmin
      .from('tareas')
      .insert({
        usuario_id: usuarioId,
        titulo,
        fecha_limite: fechaLimite,
        prioridad,
        estado: 'pendiente',
      });

    if (error) {
      console.error('Error registrando tarea:', error);
      return false;
    }

    return true;
  }

  return true;
}

// -----------------------------------------------------------------------------
// Login — código de verificación
// -----------------------------------------------------------------------------

async function enviarCodigoAlPerfil(
  numero: string,
  perfil: {
    id: string;
    correo: string | null;
    telefono: string | null;
  },
): Promise<boolean> {
  // El OTP ahora se gestiona desde el módulo compartido.
  // No usamos correo, codigo, codigo_expira_en ni intentos de whatsapp_sesiones.
  const telefonoParaOtp = perfil.telefono ?? numero;

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

  // Conservamos estos datos porque siguen perteneciendo
  // a la máquina de estados del webhook.
  await actualizarSesion(numero, {
    usuario_candidato_id: perfil.id,
    estado_flujo: 'esperando_codigo',
    candidatos_ids: null,
  });

  await enviarWhatsApp(
    numero,
    '📲 Te envié un código de 6 dígitos por este mismo WhatsApp. ' +
      'Vence en 5 minutos.\n\n' +
      'Escríbelo aquí para confirmar que eres tú. ' +
      'Si no te llega, dime "reenviar".',
  );

  return true;
}

async function manejarResultadoBusqueda(
  numero: string,
  perfiles: Perfil[],
): Promise<void> {
  // No revelamos si existe o no una cuenta.
  if (perfiles.length === 0) {
    await actualizarSesion(numero, {
      estado_flujo: 'esperando_codigo',
      usuario_candidato_id: null,
      candidatos_ids: null,
    });

    await enviarWhatsApp(
      numero,
      '📲 Si existe una cuenta asociada a ese dato, recibirás un código de verificación. ' +
        'Escríbelo aquí cuando lo recibas.',
    );

    return;
  }

  // Una sola cuenta encontrada.
  if (perfiles.length === 1) {
    await enviarCodigoAlPerfil(numero, perfiles[0]);
    return;
  }

  // Varias cuentas: verificamos primero que el WhatsApp pertenece al teléfono.
  const perfilesLimitados = perfiles.slice(0, 3);

  await actualizarSesion(numero, {
    estado_flujo: 'esperando_codigo',
    usuario_candidato_id: null,
    candidatos_ids: perfilesLimitados.map((perfil) => perfil.id),
  });

  const resultado = await solicitarOtp(supabaseAdmin, {
    telefonoCrudo: numero,
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
    return;
  }

  await enviarWhatsApp(
    numero,
    '📲 Te envié un código de 6 dígitos por este mismo WhatsApp. Vence en 5 minutos.\n\nEscríbelo aquí para confirmar que eres tú.',
  );
}

// -----------------------------------------------------------------------------
// Atajos determinísticos durante el login
// -----------------------------------------------------------------------------

function obtenerOpcionNumerada(texto: string): number | null {
  const limpio = textoNormalizado(texto);

  if (/^\d+$/.test(limpio)) {
    const numero = Number.parseInt(limpio, 10);
    return Number.isFinite(numero) ? numero : null;
  }

  return null;
}

function contieneIdentificadorObvio(texto: string): boolean {
  if (texto.includes('@')) {
    return true;
  }

  return soloDigitos(texto).length >= 7;
}

function contieneCodigoObvio(texto: string): boolean {
  return soloDigitos(texto).length === 6 && !texto.includes('+');
}

// -----------------------------------------------------------------------------
// Handler principal
// -----------------------------------------------------------------------------

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // ---------------------------------------------------------------------------
  // Verificación de Meta
  // ---------------------------------------------------------------------------

  if (req.method === 'GET') {
    const modo = url.searchParams.get('hub.mode');
    const token = url.searchParams.get('hub.verify_token');
    const desafio = url.searchParams.get('hub.challenge');

    if (
      modo === 'subscribe' &&
      token === WHATSAPP_VERIFY_TOKEN
    ) {
      return new Response(desafio ?? '', { status: 200 });
    }

    return new Response('Token inválido', { status: 403 });
  }

  if (req.method !== 'POST') {
    return new Response('Método no soportado', { status: 405 });
  }

  try {
    const body = await req.json();

    // Ignora eventos que no contengan un mensaje de texto.
    const mensaje = body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];

    if (!mensaje || mensaje.type !== 'text') {
      return responseOk();
    }

    const numero = String(mensaje.from ?? '').trim();
    const texto = String(mensaje.text?.body ?? '').trim();

    if (!numero || !texto) {
      return responseOk();
    }

    console.log(
      `[WHATSAPP] ${numero}: ${texto}`,
    );

    let sesion = await obtenerOCrearSesion(numero);

    if (!sesion) {
      await enviarWhatsApp(
        numero,
        '⚠️ No pude preparar tu sesión en este momento. Inténtalo nuevamente.',
      );
      return responseOk();
    }

    // -------------------------------------------------------------------------
    // Vencimiento de flujo de login
    // -------------------------------------------------------------------------

    const estadoActual = String(sesion.estado_flujo ?? 'inactivo');

    if (ESTADOS_DE_LOGIN.has(estadoActual)) {
      const actualizadoEn = sesion.actualizado_en
        ? new Date(String(sesion.actualizado_en)).getTime()
        : Date.now();

      const minutosInactivo =
        (Date.now() - actualizadoEn) / 60000;

      if (
        Number.isFinite(minutosInactivo) &&
        minutosInactivo > MINUTOS_VENCIMIENTO_FLUJO
      ) {
        await limpiarFlujoLogin(numero);

        await enviarWhatsApp(
          numero,
          '⏰ Se agotó el tiempo de esta conversación por inactividad. Escríbeme "hola" cuando quieras comenzar de nuevo.',
        );

        return responseOk();
      }
    }

    const estado = String(sesion.estado_flujo ?? 'inactivo');

    // -------------------------------------------------------------------------
    // Confirmación de cancelación
    // -------------------------------------------------------------------------

    if (estado === 'esperando_confirmacion_cancelar') {
      let intencion: ResultadoIntencion;

      if (esConfirmacionSi(texto)) {
        intencion = { intencion: 'confirma_si' };
      } else if (esConfirmacionNo(texto)) {
        intencion = { intencion: 'confirma_no' };
      } else {
        intencion = await clasificarIntencion(texto, estado);
      }

      if (intencion.intencion === 'confirma_si') {
        await limpiarFlujoLogin(numero);

        await enviarWhatsApp(
          numero,
          '👋 Listo, cancelé el proceso. Escríbeme cuando quieras volver a intentarlo.',
        );
      } else if (intencion.intencion === 'confirma_no') {
        const estadoAnterior =
          String(sesion.estado_flujo_anterior ?? 'inactivo');

        await actualizarSesion(numero, {
          estado_flujo: estadoAnterior,
          estado_flujo_anterior: null,
        });

        await enviarWhatsApp(
          numero,
          'Perfecto 👍. Seguimos donde estábamos.',
        );
      } else {
        await enviarWhatsApp(
          numero,
          '¿Quieres cancelar el proceso? Responde "sí" o "no".',
        );
      }

      return responseOk();
    }

    // -------------------------------------------------------------------------
    // Selección de cuenta por número
    // -------------------------------------------------------------------------

    if (estado === 'esperando_seleccion_cuenta') {
      const candidatos =
        (sesion.candidatos_ids as string[] | null) ?? [];

      let indice = obtenerOpcionNumerada(texto);

      if (!indice) {
        const intencion = await clasificarIntencion(
          texto,
          estado,
          candidatos.map((_, indiceCuenta) => `Cuenta ${indiceCuenta + 1}`),
        );

        indice = intencion.opcion_numero
          ? Number(intencion.opcion_numero)
          : null;

        if (intencion.intencion === 'cancelar') {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_confirmacion_cancelar',
            estado_flujo_anterior: estado,
          });

          await enviarWhatsApp(
            numero,
            '¿Deseas cancelar el proceso de verificación actual? (Sí / No)',
          );

          return responseOk();
        }
      }

      if (
        !indice ||
        !Number.isInteger(indice) ||
        indice < 1 ||
        indice > candidatos.length
      ) {
        await enviarWhatsApp(
          numero,
          `No logré identificar cuál elegiste 🤔. Responde con un número entre 1 y ${candidatos.length}.`,
        );

        return responseOk();
      }

      const { data: perfilElegido, error } = await supabaseAdmin
        .from('perfiles')
        .select('id, nombre, correo, telefono, id_especial')
        .eq('id', candidatos[indice - 1])
        .single();

      if (error || !perfilElegido) {
        console.error(
          'Error obteniendo perfil seleccionado:',
          error,
        );

        await enviarWhatsApp(
          numero,
          '⚠️ No pude cargar esa cuenta. Empecemos de nuevo; escribe tu correo o número registrado.',
        );

        await limpiarFlujoLogin(numero);
        return responseOk();
      }

      await actualizarSesion(numero, {
        usuario_activo_id: perfilElegido.id,
        usuario_candidato_id: null,
        estado_flujo: 'inactivo',
        estado_flujo_anterior: null,
        candidatos_ids: null,
        codigo: null,
        codigo_expira_en: null,
        intentos: 0,
      });

      await enviarWhatsApp(
        numero,
        `✅ ¡Listo! Conecté la cuenta ${perfilElegido.id_especial ? `*${perfilElegido.id_especial}*` : 'seleccionada'} de MYD.\n\nPuedes escribir:\n"gasté 20 mil en un soporte"\n"recuérdame llamar al banco mañana a las 3pm"`,
      );

      return responseOk();
    }

    // -------------------------------------------------------------------------
    // Estados de login
    // -------------------------------------------------------------------------

    if (ESTADOS_DE_LOGIN.has(estado)) {
      // Cancelación directa no necesita Gemini.
      if (esCancelacionDirecta(texto)) {
        await actualizarSesion(numero, {
          estado_flujo: 'esperando_confirmacion_cancelar',
          estado_flujo_anterior: estado,
        });

        await enviarWhatsApp(
          numero,
          '¿Deseas cancelar el proceso de verificación actual? (Sí / No)',
        );

        return responseOk();
      }

      // ---------------------------------------------------------------
      // Esperando identificador
      // ---------------------------------------------------------------

      if (estado === 'esperando_identificador') {
        // Correo/teléfono obvio: buscar directamente.
        if (contieneIdentificadorObvio(texto)) {
          const perfiles = await buscarPerfilesPorIdentificador(texto);

          await manejarResultadoBusqueda(numero, perfiles);
          return responseOk();
        }

        const intencion = await clasificarIntencion(
          texto,
          estado,
        );

        if (intencion.intencion === 'cancelar') {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_confirmacion_cancelar',
            estado_flujo_anterior: estado,
          });

          await enviarWhatsApp(
            numero,
            '¿Deseas cancelar el proceso de verificación actual? (Sí / No)',
          );

          return responseOk();
        }

        const identificador =
          intencion.identificador?.trim() || '';

        if (identificador) {
          const perfiles =
            await buscarPerfilesPorIdentificador(
              identificador,
            );

          await manejarResultadoBusqueda(numero, perfiles);
          return responseOk();
        }

        await enviarWhatsApp(
          numero,
          '📱 Necesito tu correo electrónico o el número de teléfono registrado en MYD.',
        );

        return responseOk();
      }

      // ---------------------------------------------------------------
      // Esperando código
      // ---------------------------------------------------------------

      if (estado === 'esperando_codigo') {
        if (esPedidoReenvio(texto)) {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_canal_reenvio',
          });

          await enviarWhatsApp(
            numero,
            '¿Por dónde prefieres que te reenvíe el código?\n1. Correo electrónico\n2. WhatsApp',
          );

          return responseOk();
        }

        // No usamos Gemini para un código puro de 6 dígitos.
        const codigoEscritoDirecto = contieneCodigoObvio(texto)
          ? soloDigitos(texto)
          : null;

        const intencion = codigoEscritoDirecto
          ? {
              intencion: 'da_codigo',
              codigo: codigoEscritoDirecto,
            }
          : await clasificarIntencion(texto, estado);

        if (intencion.intencion === 'cancelar') {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_confirmacion_cancelar',
            estado_flujo_anterior: estado,
          });

          await enviarWhatsApp(
            numero,
            '¿Deseas cancelar el proceso de verificación actual? (Sí / No)',
          );

          return responseOk();
        }

        if (intencion.intencion === 'pide_reenvio_codigo') {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_canal_reenvio',
          });

          await enviarWhatsApp(
            numero,
            '¿Por dónde prefieres que te reenvíe el código?\n1. Correo electrónico\n2. WhatsApp',
          );

          return responseOk();
        }

        const codigoEscrito = soloDigitos(
          String(intencion.codigo ?? texto),
        );

        if (codigoEscrito.length !== 6) {
          await enviarWhatsApp(
            numero,
            '🔢 El código debe tener 6 dígitos. Intenta nuevamente.',
          );
          return responseOk();
        }

        const resultadoOtp = await verificarOtp(supabaseAdmin, {
          telefonoCrudo: numero,
          codigo: codigoEscrito,
        });

        if (resultadoOtp.ok) {
          const candidatos =
            (sesion.candidatos_ids as string[] | null) ?? [];
          const usuarioCandidatoId = sesion.usuario_candidato_id as string | null;

          // Una sola cuenta: se conecta directamente después de verificar el OTP.
          if (usuarioCandidatoId) {
            await actualizarSesion(numero, {
              usuario_activo_id: usuarioCandidatoId,
              usuario_candidato_id: null,
              estado_flujo: 'inactivo',
              codigo: null,
              codigo_expira_en: null,
              intentos: 0,
              candidatos_ids: null,
              estado_flujo_anterior: null,
            });

            await enviarWhatsApp(
              numero,
              '✅ ¡Listo! Tu cuenta de MYD ya está conectada.\n\nPuedes escribir:\n"gasté 20 mil en un soporte"\n"recuérdame llamar al banco mañana a las 3pm"',
            );
            return responseOk();
          }

          // Varias cuentas: el OTP verifica el teléfono y luego se elige la cuenta.
          if (candidatos.length > 0) {
            const { data: perfiles, error } = await supabaseAdmin
              .from('perfiles')
              .select('id, nombre, correo, telefono, id_especial')
              .in('id', candidatos);

            if (error || !perfiles?.length) {
              console.error('Error obteniendo cuentas después del OTP:', error);
              await limpiarFlujoLogin(numero);
              await enviarWhatsApp(
                numero,
                '⚠️ No pude cargar tus cuentas. Escribe "hola" para comenzar de nuevo.',
              );
              return responseOk();
            }

            await actualizarSesion(numero, {
              estado_flujo: 'esperando_seleccion_cuenta',
              codigo: null,
              codigo_expira_en: null,
              intentos: 0,
            });

            const opciones = perfiles
              .slice(0, 3)
              .map((perfil, indice) =>
                `${indice + 1}. ${perfil.nombre ?? 'Usuario'}${
                  perfil.id_especial ? ` (${perfil.id_especial})` : ''
                }`,
              )
              .join('\n');

            await enviarWhatsApp(
              numero,
              `🔐 Verificación correcta. Tienes varias cuentas asociadas a este número.\n\n${opciones}\n\nResponde con el número de la cuenta que quieres conectar.`,
            );
            return responseOk();
          }

          await limpiarFlujoLogin(numero);
          await enviarWhatsApp(
            numero,
            '⚠️ Se perdió la referencia de la cuenta. Escribe "hola" para comenzar de nuevo.',
          );
          return responseOk();
        }

        if (resultadoOtp.razon === 'vencido' || resultadoOtp.razon === 'no_solicitado') {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_identificador',
            usuario_candidato_id: null,
            candidatos_ids: null,
            codigo: null,
            codigo_expira_en: null,
            intentos: 0,
          });
          await enviarWhatsApp(
            numero,
            '⏰ Ese código ya venció. Escribe de nuevo tu correo o número para intentarlo otra vez.',
          );
          return responseOk();
        }

        if (resultadoOtp.razon === 'demasiados_intentos') {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_identificador',
            usuario_candidato_id: null,
            candidatos_ids: null,
            codigo: null,
            codigo_expira_en: null,
            intentos: 0,
          });
          await enviarWhatsApp(
            numero,
            '❌ Muchos intentos fallidos. Empecemos de nuevo: escribe tu correo o número.',
          );
          return responseOk();
        }

        await enviarWhatsApp(
          numero,
          '❌ Ese código no es correcto. Intenta de nuevo o escribe "reenviar" si no te llegó.',
        );
        return responseOk();
      }

      // ---------------------------------------------------------------
      // Esperando canal de reenvío
      // ---------------------------------------------------------------

      if (estado === 'esperando_canal_reenvio') {
        const candidatoId =
          sesion.usuario_candidato_id as string | null;

        if (!candidatoId) {
          await actualizarSesion(numero, {
            estado_flujo: 'esperando_identificador',
          });

          await enviarWhatsApp(
            numero,
            'Se me perdió el hilo 😅. Escribe de nuevo tu correo o número para empezar otra vez.',
          );

          return responseOk();
        }

        let canal: 'correo' | 'whatsapp' | null = null;
        const opcion = obtenerOpcionNumerada(texto);

        if (opcion === 1) canal = 'correo';
        if (opcion === 2) canal = 'whatsapp';

        if (!canal) {
          const intencion = await clasificarIntencion(
            texto,
            estado,
            ['Correo electrónico', 'WhatsApp'],
          );

          if (intencion.intencion === 'cancelar') {
            await actualizarSesion(numero, {
              estado_flujo: 'esperando_confirmacion_cancelar',
              estado_flujo_anterior: estado,
            });

            await enviarWhatsApp(
              numero,
              '¿Deseas cancelar el proceso de verificación actual? (Sí / No)',
            );

            return responseOk();
          }

          if (intencion.intencion === 'elige_canal_correo') {
            canal = 'correo';
          }

          if (intencion.intencion === 'elige_canal_whatsapp') {
            canal = 'whatsapp';
          }
        }

        if (canal === 'correo') {
          const { data: perfil, error } = await supabaseAdmin
            .from('perfiles')
            .select('id, nombre, correo, telefono')
            .eq('id', candidatoId)
            .single();

          if (error || !perfil) {
            console.error(
              'Error obteniendo perfil para reenvío:',
              error,
            );

            await limpiarFlujoLogin(numero);

            await enviarWhatsApp(
              numero,
              '⚠️ No pude recuperar tu cuenta. Escribe "hola" para comenzar de nuevo.',
            );

            return responseOk();
          }

          await enviarCodigoAlPerfil(
            numero,
            perfil as Perfil,
          );

          return responseOk();
        }

        if (canal === 'whatsapp') {
          const resultadoOtp = await solicitarOtp(supabaseAdmin, {
            telefonoCrudo: numero,
            canal: 'whatsapp',
          });

          if (!resultadoOtp.ok) {
            await enviarWhatsApp(
              numero,
              resultadoOtp.razon === 'demasiadas_solicitudes'
                ? '⏳ Pediste demasiados códigos. Espera unos minutos e intenta de nuevo.'
                : '⚠️ No pude enviar el código en este momento. Inténtalo de nuevo.',
            );
            return responseOk();
          }

          await actualizarSesion(numero, {
            estado_flujo: 'esperando_codigo',
            codigo: null,
            codigo_expira_en: null,
            intentos: 0,
          });

          await enviarWhatsApp(
            numero,
            '📲 Te envié un nuevo código de 6 dígitos por este mismo WhatsApp. Vence en 5 minutos.',
          );

          return responseOk();
        }

        await enviarWhatsApp(
          numero,
          'No entendí cuál prefieres. Responde "1" para correo o "2" para WhatsApp.',
        );

        return responseOk();
      }
    }

    // -------------------------------------------------------------------------
    // Usuario sin sesión activa
    // -------------------------------------------------------------------------

    if (!sesion.usuario_activo_id) {
      if (esSaludo(texto) || estado === 'inactivo' || !estado) {
        await actualizarSesion(numero, {
          estado_flujo: 'esperando_identificador',
          estado_flujo_anterior: null,
        });

        await enviarWhatsApp(
          numero,
          '👋 ¡Hola! Soy el asistente de MYD.\n\nPara conectar tu cuenta, escríbeme tu correo electrónico o tu número registrado en la app.',
        );

        return responseOk();
      }

      // Si el usuario manda directamente el correo/teléfono,
      // no necesitamos llamar a Gemini.
      if (contieneIdentificadorObvio(texto)) {
        await actualizarSesion(numero, {
          estado_flujo: 'esperando_identificador',
        });

        const perfiles =
          await buscarPerfilesPorIdentificador(texto);

        await manejarResultadoBusqueda(numero, perfiles);
        return responseOk();
      }

      const intencion = await clasificarIntencion(
        texto,
        'inactivo_sin_sesion',
      );

      if (
        intencion.intencion === 'iniciar_sesion' ||
        intencion.identificador
      ) {
        await actualizarSesion(numero, {
          estado_flujo: 'esperando_identificador',
        });

        if (intencion.identificador) {
          const perfiles =
            await buscarPerfilesPorIdentificador(
              intencion.identificador,
            );

          await manejarResultadoBusqueda(
            numero,
            perfiles,
          );
        } else {
          await enviarWhatsApp(
            numero,
            '👋 ¡Hola! Para conectar tu cuenta, escríbeme tu correo electrónico o tu número registrado en la app.',
          );
        }
      } else {
        await enviarWhatsApp(
          numero,
          '🔒 Para ayudarte necesito conectar tu cuenta primero. Escríbeme "hola" o "quiero entrar" para comenzar.',
        );
      }

      return responseOk();
    }

    // -------------------------------------------------------------------------
    // Sesión activa
    // -------------------------------------------------------------------------

    const usuarioId = String(sesion.usuario_activo_id);

    if (esSolicitudCerrarSesion(texto)) {
      await actualizarSesion(numero, {
        usuario_activo_id: null,
        estado_flujo: 'inactivo',
        estado_flujo_anterior: null,
        codigo: null,
        codigo_expira_en: null,
        candidatos_ids: null,
        usuario_candidato_id: null,
        intentos: 0,
      });

      await enviarWhatsApp(
        numero,
        '👋 Cerré tu sesión. Escribe "hola" cuando quieras conectar otra cuenta.',
      );

      return responseOk();
    }

    if (esSolicitudVerCuenta(texto)) {
      const { data: perfil, error } = await supabaseAdmin
        .from('perfiles')
        .select('nombre, correo')
        .eq('id', usuarioId)
        .single();

      if (error || !perfil) {
        await enviarWhatsApp(
          numero,
          '⚠️ No pude consultar la cuenta conectada en este momento.',
        );

        return responseOk();
      }

      await enviarWhatsApp(
        numero,
        `🔗 Conectado como *${perfil.nombre ?? 'usuario'}* (${perfil.correo ?? 'sin correo'}).`,
      );

      return responseOk();
    }

    const { data: perfil, error: errorPerfil } =
      await supabaseAdmin
        .from('perfiles')
        .select('nombre, correo')
        .eq('id', usuarioId)
        .single();

    if (errorPerfil) {
      console.error(
        'Error consultando perfil activo:',
        errorPerfil,
      );
    }

    const { data: categorias, error: errorCategorias } =
      await supabaseAdmin
        .from('categorias')
        .select('nombre, tipo')
        .or(`usuario_id.is.null,usuario_id.eq.${usuarioId}`);

    if (errorCategorias) {
      console.error(
        'Error consultando categorías:',
        errorCategorias,
      );
    }

    const resultado = await llamarGemini({
      textoUsuario: texto,
      nombreUsuario: perfil?.nombre ?? 'usuario',
      categorias: categorias ?? [],
    });

    if (resultado.accion === 'cerrar_sesion') {
      await actualizarSesion(numero, {
        usuario_activo_id: null,
        estado_flujo: 'inactivo',
        estado_flujo_anterior: null,
      });

      await enviarWhatsApp(
        numero,
        '👋 Cerré tu sesión. Escríbeme "hola" cuando quieras conectar otra cuenta.',
      );

      return responseOk();
    }

    if (resultado.accion === 'ver_cuenta') {
      await enviarWhatsApp(
        numero,
        `🔗 Conectado como *${perfil?.nombre ?? 'usuario'}* (${perfil?.correo ?? 'sin correo'}).`,
      );

      return responseOk();
    }

    const accionEjecutada =
      await ejecutarAccion(usuarioId, resultado);

    if (!accionEjecutada) {
      await enviarWhatsApp(
        numero,
        '⚠️ Entendí tu solicitud, pero no pude guardarla correctamente. Intenta nuevamente.',
      );

      return responseOk();
    }

    await enviarWhatsApp(
      numero,
      resultado.mensaje_para_usuario,
    );

    return responseOk();
  } catch (error) {
    console.error(
      'Error crítico global en Webhook:',
      error,
    );

    // Incluso en errores inesperados respondemos 200 a Meta.
    return responseOk();
  }
});
