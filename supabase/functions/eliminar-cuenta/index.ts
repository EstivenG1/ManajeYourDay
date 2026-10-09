import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    // Solo permitimos POST
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Método no permitido' }),
        {
          status: 405,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const encabezadoAuth = req.headers.get('Authorization');

    if (!encabezadoAuth) {
      return new Response(
        JSON.stringify({ error: 'No autorizado' }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey =
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Cliente usando la sesión del usuario
    const clienteUsuario = createClient(
      supabaseUrl,
      anonKey,
      {
        global: {
          headers: {
            Authorization: encabezadoAuth,
          },
        },
      },
    );

    // Verificar quién está autenticado
    const {
      data: { user },
      error: errorUsuario,
    } = await clienteUsuario.auth.getUser();

    if (errorUsuario || !user) {
      return new Response(
        JSON.stringify({
          error: 'Token inválido o vencido',
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    // Cliente administrador
    const clienteAdmin = createClient(
      supabaseUrl,
      serviceRoleKey,
    );

    // Eliminar SOLO al usuario autenticado
    const { error: errorBorrado } =
        await clienteAdmin.auth.admin.deleteUser(user.id);

    if (errorBorrado) {
      return new Response(
        JSON.stringify({
          error: errorBorrado.message,
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    return new Response(
      JSON.stringify({
        ok: true,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        error: String(e),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  }
});