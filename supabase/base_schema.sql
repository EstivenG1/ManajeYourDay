--
-- PostgreSQL database dump
--

\restrict 3jLe581D3MbRognBAppNYqHZCAQwtFekNewJH403LmSGeuYRaBtdc3bm5tGsGY2

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: actualizar_monto_meta(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.actualizar_monto_meta() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  meta_afectada uuid;
begin
  meta_afectada := coalesce(new.meta_id, old.meta_id);

  update public.metas_ahorro
  set monto_actual = (
        select coalesce(sum(monto), 0) from public.aportes_ahorro where meta_id = meta_afectada
      ),
      estado = case
        when (select coalesce(sum(monto), 0) from public.aportes_ahorro where meta_id = meta_afectada)
             >= (select monto_objetivo from public.metas_ahorro where id = meta_afectada)
        then 'completada'
        else estado
      end
  where id = meta_afectada;

  return coalesce(new, old);
end;
$$;


--
-- Name: can_create_plan_resource(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_create_plan_resource(p_resource text) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  current_user_id uuid := (select auth.uid());
  current_plan text;
  resource_limit integer;
  current_usage bigint;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  current_plan := public.get_my_plan();
  resource_limit := public.get_plan_resource_limit(current_plan, p_resource);

  case p_resource
    when 'tasks_monthly' then
      select count(*) into current_usage
      from public.tareas
      where usuario_id = current_user_id
        and creado_en >= date_trunc('month', statement_timestamp());
    when 'transactions_monthly' then
      select count(*) into current_usage
      from public.movimientos
      where usuario_id = current_user_id
        and creado_en >= date_trunc('month', statement_timestamp());
    when 'active_budgets' then
      select count(*) into current_usage
      from public.presupuestos
      where usuario_id = current_user_id
        and fecha_fin >= current_date;
    when 'active_goals' then
      select count(*) into current_usage
      from public.metas_ahorro
      where usuario_id = current_user_id
        and estado = 'activa';
    when 'active_recurring' then
      select count(*) into current_usage
      from public.movimientos_recurrentes
      where usuario_id = current_user_id
        and activo;
    when 'receipts_monthly' then
      select count(*) into current_usage
      from storage.objects
      where bucket_id = 'receipts'
        and (storage.foldername(name))[1] = current_user_id::text
        and created_at >= date_trunc('month', statement_timestamp());
  end case;

  return resource_limit is null or current_usage < resource_limit;
end;
$$;


--
-- Name: delete_user_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_user_data(target_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
begin
  if auth.role() <> 'service_role' then
    raise exception 'service role required';
  end if;

  if to_regclass('public.notificaciones') is not null then
    execute 'delete from public.notificaciones where usuario_id = $1'
      using target_user_id;
  end if;
  if to_regclass('public.recomendaciones_ia') is not null then
    execute 'delete from public.recomendaciones_ia where usuario_id = $1'
      using target_user_id;
  end if;
  if to_regclass('public.reportes_semanales') is not null then
    execute 'delete from public.reportes_semanales where usuario_id = $1'
      using target_user_id;
  end if;
  if to_regclass('public.suscripciones') is not null then
    execute 'delete from public.suscripciones where usuario_id = $1'
      using target_user_id;
  end if;

  delete from public.aportes_ahorro where usuario_id = target_user_id;
  delete from public.movimientos_recurrentes where usuario_id = target_user_id;
  delete from public.movimientos where usuario_id = target_user_id;
  delete from public.presupuestos where usuario_id = target_user_id;
  delete from public.tareas where usuario_id = target_user_id;
  delete from public.sugerencias_texto where usuario_id = target_user_id;
  delete from public.metas_ahorro where usuario_id = target_user_id;
  delete from public.categorias where usuario_id = target_user_id;
  delete from public.perfiles where id = target_user_id;
end;
$_$;


--
-- Name: enforce_plan_resource_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_plan_resource_limit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
declare
  current_user_id uuid := (select auth.uid());
  resource_name text;
  resource_limit integer;
  current_usage bigint;
  excluded_id text;
begin
  if tg_op = 'UPDATE' then
    excluded_id := old.id::text;
  end if;

  if tg_table_schema = 'storage' then
    if new.bucket_id <> 'receipts' or current_user_id is null then
      return new;
    end if;
    if (storage.foldername(new.name))[1] <> current_user_id::text then
      return new;
    end if;
    resource_name := 'receipts_monthly';
    resource_limit := public.get_plan_resource_limit(
      public.get_my_plan(),
      resource_name
    );
    select count(*) into current_usage
    from storage.objects
    where bucket_id = 'receipts'
      and (storage.foldername(name))[1] = current_user_id::text
      and created_at >= date_trunc('month', statement_timestamp())
      and (excluded_id is null or id::text <> excluded_id);
  else
    if current_user_id is null or new.usuario_id <> current_user_id then
      return new;
    end if;

    case tg_table_name
      when 'tareas' then
        resource_name := 'tasks_monthly';
        select count(*) into current_usage
        from public.tareas
        where usuario_id = current_user_id
          and creado_en >= date_trunc('month', statement_timestamp());
      when 'movimientos' then
        resource_name := 'transactions_monthly';
        select count(*) into current_usage
        from public.movimientos
        where usuario_id = current_user_id
          and creado_en >= date_trunc('month', statement_timestamp());
      when 'presupuestos' then
        if new.fecha_fin < current_date then
          return new;
        end if;
        if tg_op = 'UPDATE' then
          if old.fecha_fin >= current_date then
            return new;
          end if;
        end if;
        resource_name := 'active_budgets';
        select count(*) into current_usage
        from public.presupuestos
        where usuario_id = current_user_id
          and fecha_fin >= current_date
          and (excluded_id is null or id::text <> excluded_id);
      when 'metas_ahorro' then
        if new.estado <> 'activa' then
          return new;
        end if;
        if tg_op = 'UPDATE' then
          if old.estado = 'activa' then
            return new;
          end if;
        end if;
        resource_name := 'active_goals';
        select count(*) into current_usage
        from public.metas_ahorro
        where usuario_id = current_user_id
          and estado = 'activa'
          and (excluded_id is null or id::text <> excluded_id);
      when 'movimientos_recurrentes' then
        if not new.activo then
          return new;
        end if;
        if tg_op = 'UPDATE' then
          if old.activo then
            return new;
          end if;
        end if;
        resource_name := 'active_recurring';
        select count(*) into current_usage
        from public.movimientos_recurrentes
        where usuario_id = current_user_id
          and activo
          and (excluded_id is null or id::text <> excluded_id);
      else
        raise exception 'Unsupported plan-limited table';
    end case;

    resource_limit := public.get_plan_resource_limit(
      public.get_my_plan(),
      resource_name
    );
  end if;

  if resource_limit is not null and current_usage >= resource_limit then
    raise exception 'PLAN_LIMIT_REACHED:%', resource_name
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;


--
-- Name: get_my_plan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_plan() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(
    (
      select override.plan
      from public.developer_plan_overrides as override
      where override.user_id = (select auth.uid())
        and (
          override.expires_at is null
          or override.expires_at > statement_timestamp()
        )
      limit 1
    ),
    (
      select subscription.plan
      from public.billing_subscriptions as subscription
      where subscription.user_id = (select auth.uid())
        and (
          subscription.status = 'authorized'
          or (
            subscription.status = 'cancelled'
            and subscription.current_period_end > statement_timestamp()
          )
        )
        and (
          subscription.current_period_end is null
          or subscription.current_period_end > statement_timestamp()
        )
      order by subscription.current_period_end desc nulls first
      limit 1
    ),
    'free'
  );
$$;


--
-- Name: get_plan_resource_limit(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_plan_resource_limit(p_plan text, p_resource text) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $$
begin
  if p_plan not in ('free', 'standard', 'premium') then
    raise exception 'Unknown plan';
  end if;

  case p_resource
    when 'tasks_monthly' then
      return case p_plan when 'free' then 50 when 'standard' then 500 else null end;
    when 'transactions_monthly' then
      return case p_plan when 'free' then 100 when 'standard' then 1000 else null end;
    when 'active_budgets' then
      return case p_plan when 'free' then 2 when 'standard' then 10 else null end;
    when 'active_goals' then
      return case p_plan when 'free' then 2 when 'standard' then 10 else null end;
    when 'active_recurring' then
      return case p_plan when 'free' then 3 when 'standard' then 25 else null end;
    when 'receipts_monthly' then
      return case p_plan when 'free' then 3 when 'standard' then 30 else 100 end;
    else
      raise exception 'Unknown plan resource';
  end case;
end;
$$;


--
-- Name: manejar_nuevo_usuario(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.manejar_nuevo_usuario() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  insert into public.perfiles (id, nombre, apellido, telefono, correo, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'nombre',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      'Usuario'
    ),
    new.raw_user_meta_data ->> 'apellido',
    new.raw_user_meta_data ->> 'telefono',
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  );
  return new;
end;
$$;


--
-- Name: myd_antes_insertar_perfil(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.myd_antes_insertar_perfil() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  cuentas_existentes int;
  intentos int := 0;
  candidato text;
begin

  -- ----------------------------------------------------------
  -- Límite máximo de 3 cuentas por teléfono
  -- ----------------------------------------------------------

  if new.telefono_e164 is not null then

    -- Bloquea inserciones simultáneas para ESTE teléfono
    -- durante la transacción.
    perform pg_advisory_xact_lock(
      hashtext(new.telefono_e164)::bigint
    );

    select count(*)
    into cuentas_existentes
    from public.perfiles
    where telefono_e164 = new.telefono_e164;

    if cuentas_existentes >= 3 then

      raise exception
        'Este número ya tiene el máximo de 3 cuentas MYD permitidas'
        using errcode = 'P0001';

    end if;

  end if;


  -- ----------------------------------------------------------
  -- Generación automática del ID especial
  -- ----------------------------------------------------------

  if new.id_especial is null then

    loop

      candidato := myd_generar_codigo_especial();
      intentos := intentos + 1;

      exit when not exists (
        select 1
        from public.perfiles
        where id_especial = candidato
      );

      if intentos > 20 then
        raise exception
          'No se pudo generar un id_especial único';
      end if;

    end loop;

    new.id_especial := candidato;

  end if;


  return new;

end;
$$;


--
-- Name: myd_generar_codigo_especial(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.myd_generar_codigo_especial() RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  alfabeto text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  resultado text := '';
  i int;
begin
  for i in 1..6 loop
    resultado := resultado ||
      substr(
        alfabeto,
        (floor(random() * length(alfabeto)))::int + 1,
        1
      );
  end loop;

  return 'MYD-' || resultado;
end;
$$;


--
-- Name: set_billing_subscription_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_billing_subscription_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aportes_ahorro; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aportes_ahorro (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    meta_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    monto numeric(12,2) NOT NULL,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    nota text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT aportes_ahorro_monto_check CHECK ((monto > (0)::numeric))
);


--
-- Name: billing_provider_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_provider_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    environment text NOT NULL,
    billing_period text NOT NULL,
    trial_days integer NOT NULL,
    provider_plan_id text NOT NULL,
    created_at timestamp with time zone DEFAULT statement_timestamp() NOT NULL,
    CONSTRAINT billing_provider_plans_billing_period_check CHECK ((billing_period = ANY (ARRAY['monthly'::text, 'annual'::text]))),
    CONSTRAINT billing_provider_plans_environment_check CHECK ((environment = ANY (ARRAY['test'::text, 'production'::text]))),
    CONSTRAINT billing_provider_plans_trial_days_check CHECK ((trial_days = 7))
);


--
-- Name: billing_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.billing_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    external_reference uuid NOT NULL,
    provider_subscription_id text,
    plan text NOT NULL,
    billing_period text NOT NULL,
    amount_cop integer NOT NULL,
    currency text DEFAULT 'COP'::text NOT NULL,
    status text NOT NULL,
    current_period_end timestamp with time zone,
    created_at timestamp with time zone DEFAULT statement_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT statement_timestamp() NOT NULL,
    upgrade_discount_pending boolean DEFAULT false NOT NULL,
    upgrade_in_progress boolean DEFAULT false NOT NULL,
    trial_days integer DEFAULT 0 NOT NULL,
    regular_amount_cop integer,
    provider_plan_id text,
    checkout_url text,
    trial_started_at timestamp with time zone,
    CONSTRAINT billing_subscriptions_billing_period_check CHECK ((billing_period = ANY (ARRAY['monthly'::text, 'annual'::text]))),
    CONSTRAINT billing_subscriptions_catalog_price CHECK ((((plan = 'standard'::text) AND (upgrade_discount_pending = false) AND (regular_amount_cop IS NULL) AND (((billing_period = 'monthly'::text) AND (amount_cop = 12900)) OR ((billing_period = 'annual'::text) AND (amount_cop = 129000)))) OR ((plan = 'premium'::text) AND (upgrade_in_progress = false) AND (billing_period = 'monthly'::text) AND (((upgrade_discount_pending = false) AND (regular_amount_cop IS NULL) AND (amount_cop = 24900)) OR ((upgrade_discount_pending = true) AND (regular_amount_cop = 24900) AND (amount_cop = 12450)))) OR ((plan = 'premium'::text) AND (upgrade_in_progress = false) AND (billing_period = 'annual'::text) AND (((upgrade_discount_pending = false) AND (regular_amount_cop IS NULL) AND (amount_cop = 249900)) OR ((upgrade_discount_pending = true) AND (regular_amount_cop = 249900) AND (amount_cop = 124950)))))),
    CONSTRAINT billing_subscriptions_currency_check CHECK ((currency = 'COP'::text)),
    CONSTRAINT billing_subscriptions_plan_check CHECK ((plan = ANY (ARRAY['standard'::text, 'premium'::text]))),
    CONSTRAINT billing_subscriptions_status_check CHECK ((status = ANY (ARRAY['checkout_pending'::text, 'pending'::text, 'authorized'::text, 'paused'::text, 'cancelled'::text, 'rejected'::text, 'expired'::text, 'checkout_failed'::text]))),
    CONSTRAINT billing_subscriptions_trial_days CHECK (((trial_days = 0) OR ((plan = 'premium'::text) AND (billing_period = 'monthly'::text) AND (trial_days = 7))))
);


--
-- Name: TABLE billing_subscriptions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.billing_subscriptions IS 'Mercado Pago web subscription records; only trusted server functions may write.';


--
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorias (
    id integer NOT NULL,
    usuario_id uuid,
    nombre text NOT NULL,
    tipo text NOT NULL,
    icono text,
    color text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT categorias_tipo_check CHECK ((tipo = ANY (ARRAY['ingreso'::text, 'gasto'::text])))
);


--
-- Name: categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categorias ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categorias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: developer_plan_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.developer_plan_overrides (
    user_id uuid NOT NULL,
    plan text NOT NULL,
    expires_at timestamp with time zone,
    note text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT developer_plan_overrides_plan_check CHECK ((plan = ANY (ARRAY['free'::text, 'standard'::text, 'premium'::text])))
);


--
-- Name: TABLE developer_plan_overrides; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.developer_plan_overrides IS 'Admin-managed plan overrides for developer testing. Never writable by app users.';


--
-- Name: metas_ahorro; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metas_ahorro (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    nombre text NOT NULL,
    monto_objetivo numeric(12,2) NOT NULL,
    monto_actual numeric(12,2) DEFAULT 0 NOT NULL,
    fecha_limite date,
    icono text,
    estado text DEFAULT 'activa'::text NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    aporte_programado numeric DEFAULT 0 NOT NULL,
    frecuencia_aporte text DEFAULT 'mensual'::text NOT NULL,
    proximo_aporte date,
    CONSTRAINT metas_ahorro_estado_check CHECK ((estado = ANY (ARRAY['activa'::text, 'completada'::text, 'cancelada'::text]))),
    CONSTRAINT metas_ahorro_frecuencia_aporte_check CHECK ((frecuencia_aporte = ANY (ARRAY['semanal'::text, 'quincenal'::text, 'mensual'::text]))),
    CONSTRAINT metas_ahorro_monto_objetivo_check CHECK ((monto_objetivo > (0)::numeric))
);


--
-- Name: movimientos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.movimientos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    categoria_id integer NOT NULL,
    tipo text NOT NULL,
    monto numeric(12,2) NOT NULL,
    descripcion text,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    ubicacion_latitud double precision,
    ubicacion_longitud double precision,
    comprobante_path text,
    CONSTRAINT movimientos_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT movimientos_tipo_check CHECK ((tipo = ANY (ARRAY['ingreso'::text, 'gasto'::text]))),
    CONSTRAINT movimientos_ubicacion_coordenadas_check CHECK ((((ubicacion_latitud IS NULL) AND (ubicacion_longitud IS NULL)) OR ((ubicacion_latitud IS NOT NULL) AND (ubicacion_longitud IS NOT NULL) AND ((ubicacion_latitud >= ('-90'::integer)::double precision) AND (ubicacion_latitud <= (90)::double precision)) AND ((ubicacion_longitud >= ('-180'::integer)::double precision) AND (ubicacion_longitud <= (180)::double precision)))))
);


--
-- Name: movimientos_recurrentes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.movimientos_recurrentes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    tipo text NOT NULL,
    monto numeric NOT NULL,
    categoria_id integer NOT NULL,
    descripcion text,
    frecuencia text NOT NULL,
    proxima_fecha date NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT movimientos_recurrentes_frecuencia_check CHECK ((frecuencia = ANY (ARRAY['semanal'::text, 'quincenal'::text, 'mensual'::text]))),
    CONSTRAINT movimientos_recurrentes_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT movimientos_recurrentes_tipo_check CHECK ((tipo = ANY (ARRAY['ingreso'::text, 'gasto'::text])))
);


--
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notificaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    tarea_id uuid,
    tipo text NOT NULL,
    titulo text NOT NULL,
    mensaje text NOT NULL,
    programada_para timestamp with time zone NOT NULL,
    enviada boolean DEFAULT false NOT NULL,
    leida boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notificaciones_tipo_check CHECK ((tipo = ANY (ARRAY['tarea'::text, 'gasto'::text, 'presupuesto'::text, 'sistema'::text, 'ia'::text])))
);


--
-- Name: otp_verificaciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_verificaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    telefono_e164 text NOT NULL,
    canal text NOT NULL,
    codigo_hash text NOT NULL,
    intentos integer DEFAULT 0 NOT NULL,
    max_intentos integer DEFAULT 5 NOT NULL,
    usado boolean DEFAULT false NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    ip_solicitante text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT otp_verificaciones_canal_check CHECK ((canal = ANY (ARRAY['whatsapp'::text, 'sms'::text])))
);


--
-- Name: perfiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.perfiles (
    id uuid NOT NULL,
    nombre text NOT NULL,
    apellido text,
    telefono text,
    correo text NOT NULL,
    avatar_url text,
    plan_id smallint DEFAULT 1 NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    ciudad text,
    pais text,
    moneda text DEFAULT 'COP'::text NOT NULL,
    idioma text DEFAULT 'es'::text NOT NULL,
    telefono_e164 text,
    id_especial text NOT NULL
);


--
-- Name: planes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planes (
    id smallint NOT NULL,
    nombre text NOT NULL,
    precio numeric(10,2) DEFAULT 0 NOT NULL,
    limite_tareas integer,
    tiene_publicidad boolean DEFAULT false NOT NULL,
    descripcion text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: planes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.planes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.planes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: presupuestos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.presupuestos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    categoria_id integer,
    monto_limite numeric(12,2) NOT NULL,
    periodo text DEFAULT 'mensual'::text NOT NULL,
    fecha_inicio date DEFAULT CURRENT_DATE NOT NULL,
    fecha_fin date NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT presupuestos_monto_limite_check CHECK ((monto_limite > (0)::numeric)),
    CONSTRAINT presupuestos_periodo_check CHECK ((periodo = ANY (ARRAY['semanal'::text, 'mensual'::text])))
);


--
-- Name: recomendaciones_ia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recomendaciones_ia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    tipo text NOT NULL,
    contenido text NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    vista boolean DEFAULT false NOT NULL,
    CONSTRAINT recomendaciones_ia_tipo_check CHECK ((tipo = ANY (ARRAY['consejo'::text, 'alerta_gasto'::text, 'sugerencia_tarea'::text])))
);


--
-- Name: reportes_semanales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reportes_semanales (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    semana_inicio date NOT NULL,
    semana_fin date NOT NULL,
    indice_productividad numeric(5,2) DEFAULT 0 NOT NULL,
    total_ingresos numeric(12,2) DEFAULT 0 NOT NULL,
    total_gastos numeric(12,2) DEFAULT 0 NOT NULL,
    balance numeric(12,2) DEFAULT 0 NOT NULL,
    tareas_completadas integer DEFAULT 0 NOT NULL,
    tareas_totales integer DEFAULT 0 NOT NULL,
    generado_en timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sugerencias_texto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sugerencias_texto (
    id integer NOT NULL,
    usuario_id uuid NOT NULL,
    contexto text NOT NULL,
    valor text NOT NULL,
    veces_usado integer DEFAULT 1 NOT NULL,
    ultima_vez timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sugerencias_texto_contexto_check CHECK ((contexto = ANY (ARRAY['tarea_titulo'::text, 'tarea_hora'::text, 'gasto_descripcion'::text, 'gasto_categoria'::text])))
);


--
-- Name: sugerencias_texto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.sugerencias_texto ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sugerencias_texto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: suscripciones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suscripciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    plan_id smallint NOT NULL,
    fecha_inicio date DEFAULT CURRENT_DATE NOT NULL,
    fecha_fin date,
    estado text DEFAULT 'activa'::text NOT NULL,
    metodo_pago text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT suscripciones_estado_check CHECK ((estado = ANY (ARRAY['activa'::text, 'cancelada'::text, 'vencida'::text])))
);


--
-- Name: tareas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tareas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    titulo text NOT NULL,
    descripcion text,
    fecha_limite timestamp with time zone NOT NULL,
    prioridad text DEFAULT 'media'::text NOT NULL,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    completado_en timestamp with time zone,
    recurrencia text DEFAULT 'ninguna'::text NOT NULL,
    serie_id uuid,
    recurrencia_padre_id uuid,
    CONSTRAINT tareas_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'completada'::text, 'incumplida'::text]))),
    CONSTRAINT tareas_prioridad_check CHECK ((prioridad = ANY (ARRAY['alta'::text, 'media'::text, 'baja'::text]))),
    CONSTRAINT tareas_recurrencia_check CHECK ((recurrencia = ANY (ARRAY['ninguna'::text, 'diaria'::text, 'semanal'::text, 'mensual'::text])))
);


--
-- Name: whatsapp_sesiones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_sesiones (
    numero_whatsapp text NOT NULL,
    usuario_activo_id uuid,
    usuario_candidato_id uuid,
    estado_flujo text DEFAULT 'inactivo'::text NOT NULL,
    codigo text,
    codigo_expira_en timestamp with time zone,
    intentos integer DEFAULT 0 NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    estado_previo text,
    candidatos_json jsonb,
    candidatos_ids uuid[],
    estado_flujo_anterior text,
    CONSTRAINT whatsapp_sesiones_estado_flujo_check CHECK ((estado_flujo = ANY (ARRAY['inactivo'::text, 'esperando_identificador'::text, 'esperando_seleccion_cuenta'::text, 'esperando_codigo'::text, 'esperando_canal_reenvio'::text, 'esperando_confirmacion_cancelar'::text])))
);


--
-- Name: aportes_ahorro aportes_ahorro_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aportes_ahorro
    ADD CONSTRAINT aportes_ahorro_pkey PRIMARY KEY (id);


--
-- Name: billing_provider_plans billing_provider_plans_environment_billing_period_trial_day_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_provider_plans
    ADD CONSTRAINT billing_provider_plans_environment_billing_period_trial_day_key UNIQUE (environment, billing_period, trial_days);


--
-- Name: billing_provider_plans billing_provider_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_provider_plans
    ADD CONSTRAINT billing_provider_plans_pkey PRIMARY KEY (id);


--
-- Name: billing_provider_plans billing_provider_plans_provider_plan_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_provider_plans
    ADD CONSTRAINT billing_provider_plans_provider_plan_id_key UNIQUE (provider_plan_id);


--
-- Name: billing_subscriptions billing_subscriptions_external_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscriptions
    ADD CONSTRAINT billing_subscriptions_external_reference_key UNIQUE (external_reference);


--
-- Name: billing_subscriptions billing_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscriptions
    ADD CONSTRAINT billing_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: billing_subscriptions billing_subscriptions_provider_plan_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscriptions
    ADD CONSTRAINT billing_subscriptions_provider_plan_id_key UNIQUE (provider_plan_id);


--
-- Name: billing_subscriptions billing_subscriptions_provider_subscription_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscriptions
    ADD CONSTRAINT billing_subscriptions_provider_subscription_id_key UNIQUE (provider_subscription_id);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: categorias categorias_usuario_id_nombre_tipo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_usuario_id_nombre_tipo_key UNIQUE (usuario_id, nombre, tipo);


--
-- Name: developer_plan_overrides developer_plan_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.developer_plan_overrides
    ADD CONSTRAINT developer_plan_overrides_pkey PRIMARY KEY (user_id);


--
-- Name: metas_ahorro metas_ahorro_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metas_ahorro
    ADD CONSTRAINT metas_ahorro_pkey PRIMARY KEY (id);


--
-- Name: movimientos movimientos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos
    ADD CONSTRAINT movimientos_pkey PRIMARY KEY (id);


--
-- Name: movimientos_recurrentes movimientos_recurrentes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_recurrentes
    ADD CONSTRAINT movimientos_recurrentes_pkey PRIMARY KEY (id);


--
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id);


--
-- Name: otp_verificaciones otp_verificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_verificaciones
    ADD CONSTRAINT otp_verificaciones_pkey PRIMARY KEY (id);


--
-- Name: perfiles perfiles_correo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_correo_key UNIQUE (correo);


--
-- Name: perfiles perfiles_id_especial_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_id_especial_unique UNIQUE (id_especial);


--
-- Name: perfiles perfiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_pkey PRIMARY KEY (id);


--
-- Name: planes planes_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes
    ADD CONSTRAINT planes_nombre_key UNIQUE (nombre);


--
-- Name: planes planes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planes
    ADD CONSTRAINT planes_pkey PRIMARY KEY (id);


--
-- Name: presupuestos presupuestos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presupuestos
    ADD CONSTRAINT presupuestos_pkey PRIMARY KEY (id);


--
-- Name: recomendaciones_ia recomendaciones_ia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recomendaciones_ia
    ADD CONSTRAINT recomendaciones_ia_pkey PRIMARY KEY (id);


--
-- Name: reportes_semanales reportes_semanales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reportes_semanales
    ADD CONSTRAINT reportes_semanales_pkey PRIMARY KEY (id);


--
-- Name: reportes_semanales reportes_semanales_usuario_id_semana_inicio_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reportes_semanales
    ADD CONSTRAINT reportes_semanales_usuario_id_semana_inicio_key UNIQUE (usuario_id, semana_inicio);


--
-- Name: sugerencias_texto sugerencias_texto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sugerencias_texto
    ADD CONSTRAINT sugerencias_texto_pkey PRIMARY KEY (id);


--
-- Name: sugerencias_texto sugerencias_texto_usuario_id_contexto_valor_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sugerencias_texto
    ADD CONSTRAINT sugerencias_texto_usuario_id_contexto_valor_key UNIQUE (usuario_id, contexto, valor);


--
-- Name: suscripciones suscripciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suscripciones
    ADD CONSTRAINT suscripciones_pkey PRIMARY KEY (id);


--
-- Name: tareas tareas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT tareas_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_sesiones whatsapp_sesiones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_sesiones
    ADD CONSTRAINT whatsapp_sesiones_pkey PRIMARY KEY (numero_whatsapp);


--
-- Name: billing_subscriptions_one_open_per_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX billing_subscriptions_one_open_per_user ON public.billing_subscriptions USING btree (user_id) WHERE (status = ANY (ARRAY['checkout_pending'::text, 'pending'::text, 'authorized'::text, 'paused'::text]));


--
-- Name: billing_subscriptions_one_premium_trial_per_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX billing_subscriptions_one_premium_trial_per_user ON public.billing_subscriptions USING btree (user_id) WHERE ((trial_days = 7) AND (status = ANY (ARRAY['pending'::text, 'authorized'::text, 'paused'::text, 'cancelled'::text])));


--
-- Name: billing_subscriptions_plan_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX billing_subscriptions_plan_lookup ON public.billing_subscriptions USING btree (user_id, status, current_period_end DESC);


--
-- Name: idx_aportes_meta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_aportes_meta ON public.aportes_ahorro USING btree (meta_id);


--
-- Name: idx_categorias_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_categorias_usuario ON public.categorias USING btree (usuario_id);


--
-- Name: idx_metas_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_metas_usuario ON public.metas_ahorro USING btree (usuario_id, estado);


--
-- Name: idx_movimientos_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_categoria ON public.movimientos USING btree (categoria_id);


--
-- Name: idx_movimientos_usuario_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_movimientos_usuario_fecha ON public.movimientos USING btree (usuario_id, fecha DESC);


--
-- Name: idx_notificaciones_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notificaciones_usuario ON public.notificaciones USING btree (usuario_id, leida);


--
-- Name: idx_otp_ip_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_ip_fecha ON public.otp_verificaciones USING btree (ip_solicitante, creado_en DESC);


--
-- Name: idx_otp_telefono_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_telefono_fecha ON public.otp_verificaciones USING btree (telefono_e164, creado_en DESC);


--
-- Name: idx_otp_telefono_vigente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_telefono_vigente ON public.otp_verificaciones USING btree (telefono_e164, usado);


--
-- Name: idx_perfiles_telefono_e164; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_perfiles_telefono_e164 ON public.perfiles USING btree (telefono_e164);


--
-- Name: idx_presupuestos_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_presupuestos_usuario ON public.presupuestos USING btree (usuario_id);


--
-- Name: idx_recomendaciones_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recomendaciones_usuario ON public.recomendaciones_ia USING btree (usuario_id, vista);


--
-- Name: idx_reportes_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reportes_usuario ON public.reportes_semanales USING btree (usuario_id, semana_inicio DESC);


--
-- Name: idx_sugerencias_usuario_contexto; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sugerencias_usuario_contexto ON public.sugerencias_texto USING btree (usuario_id, contexto);


--
-- Name: idx_suscripciones_usuario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_suscripciones_usuario ON public.suscripciones USING btree (usuario_id);


--
-- Name: idx_tareas_fecha_limite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tareas_fecha_limite ON public.tareas USING btree (fecha_limite);


--
-- Name: idx_tareas_serie; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tareas_serie ON public.tareas USING btree (serie_id);


--
-- Name: idx_tareas_usuario_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tareas_usuario_estado ON public.tareas USING btree (usuario_id, estado);


--
-- Name: movimientos_recurrentes_usuario_fecha_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX movimientos_recurrentes_usuario_fecha_idx ON public.movimientos_recurrentes USING btree (usuario_id, proxima_fecha) WHERE activo;


--
-- Name: tareas_recurrencia_padre_unico; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tareas_recurrencia_padre_unico ON public.tareas USING btree (recurrencia_padre_id) WHERE (recurrencia_padre_id IS NOT NULL);


--
-- Name: aportes_ahorro al_cambiar_aporte; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER al_cambiar_aporte AFTER INSERT OR DELETE OR UPDATE ON public.aportes_ahorro FOR EACH ROW EXECUTE FUNCTION public.actualizar_monto_meta();


--
-- Name: presupuestos enforce_plan_limit_budgets; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_plan_limit_budgets BEFORE INSERT OR UPDATE ON public.presupuestos FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_resource_limit();


--
-- Name: metas_ahorro enforce_plan_limit_goals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_plan_limit_goals BEFORE INSERT OR UPDATE ON public.metas_ahorro FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_resource_limit();


--
-- Name: movimientos_recurrentes enforce_plan_limit_recurring; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_plan_limit_recurring BEFORE INSERT OR UPDATE ON public.movimientos_recurrentes FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_resource_limit();


--
-- Name: tareas enforce_plan_limit_tasks; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_plan_limit_tasks BEFORE INSERT ON public.tareas FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_resource_limit();


--
-- Name: movimientos enforce_plan_limit_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER enforce_plan_limit_transactions BEFORE INSERT ON public.movimientos FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_resource_limit();


--
-- Name: billing_subscriptions set_billing_subscription_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_billing_subscription_updated_at BEFORE UPDATE ON public.billing_subscriptions FOR EACH ROW EXECUTE FUNCTION public.set_billing_subscription_updated_at();


--
-- Name: perfiles trg_antes_insertar_perfil; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_antes_insertar_perfil BEFORE INSERT ON public.perfiles FOR EACH ROW EXECUTE FUNCTION public.myd_antes_insertar_perfil();


--
-- Name: aportes_ahorro aportes_ahorro_meta_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aportes_ahorro
    ADD CONSTRAINT aportes_ahorro_meta_id_fkey FOREIGN KEY (meta_id) REFERENCES public.metas_ahorro(id) ON DELETE CASCADE;


--
-- Name: aportes_ahorro aportes_ahorro_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aportes_ahorro
    ADD CONSTRAINT aportes_ahorro_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: billing_subscriptions billing_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.billing_subscriptions
    ADD CONSTRAINT billing_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: categorias categorias_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: developer_plan_overrides developer_plan_overrides_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.developer_plan_overrides
    ADD CONSTRAINT developer_plan_overrides_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: metas_ahorro metas_ahorro_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metas_ahorro
    ADD CONSTRAINT metas_ahorro_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: movimientos movimientos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos
    ADD CONSTRAINT movimientos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: movimientos_recurrentes movimientos_recurrentes_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_recurrentes
    ADD CONSTRAINT movimientos_recurrentes_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: movimientos_recurrentes movimientos_recurrentes_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos_recurrentes
    ADD CONSTRAINT movimientos_recurrentes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: movimientos movimientos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.movimientos
    ADD CONSTRAINT movimientos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: notificaciones notificaciones_tarea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_tarea_id_fkey FOREIGN KEY (tarea_id) REFERENCES public.tareas(id) ON DELETE CASCADE;


--
-- Name: notificaciones notificaciones_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: perfiles perfiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: perfiles perfiles_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.perfiles
    ADD CONSTRAINT perfiles_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.planes(id);


--
-- Name: presupuestos presupuestos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presupuestos
    ADD CONSTRAINT presupuestos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id);


--
-- Name: presupuestos presupuestos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presupuestos
    ADD CONSTRAINT presupuestos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: recomendaciones_ia recomendaciones_ia_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recomendaciones_ia
    ADD CONSTRAINT recomendaciones_ia_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: reportes_semanales reportes_semanales_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reportes_semanales
    ADD CONSTRAINT reportes_semanales_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: sugerencias_texto sugerencias_texto_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sugerencias_texto
    ADD CONSTRAINT sugerencias_texto_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: suscripciones suscripciones_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suscripciones
    ADD CONSTRAINT suscripciones_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.planes(id);


--
-- Name: suscripciones suscripciones_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suscripciones
    ADD CONSTRAINT suscripciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: tareas tareas_recurrencia_padre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT tareas_recurrencia_padre_id_fkey FOREIGN KEY (recurrencia_padre_id) REFERENCES public.tareas(id) ON DELETE SET NULL;


--
-- Name: tareas tareas_serie_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT tareas_serie_id_fkey FOREIGN KEY (serie_id) REFERENCES public.tareas(id) ON DELETE SET NULL;


--
-- Name: tareas tareas_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tareas
    ADD CONSTRAINT tareas_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfiles(id) ON DELETE CASCADE;


--
-- Name: whatsapp_sesiones whatsapp_sesiones_usuario_activo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_sesiones
    ADD CONSTRAINT whatsapp_sesiones_usuario_activo_id_fkey FOREIGN KEY (usuario_activo_id) REFERENCES public.perfiles(id) ON DELETE SET NULL;


--
-- Name: whatsapp_sesiones whatsapp_sesiones_usuario_candidato_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_sesiones
    ADD CONSTRAINT whatsapp_sesiones_usuario_candidato_id_fkey FOREIGN KEY (usuario_candidato_id) REFERENCES public.perfiles(id) ON DELETE SET NULL;


--
-- Name: billing_subscriptions Users can read their own billing subscriptions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read their own billing subscriptions" ON public.billing_subscriptions FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: aportes_ahorro; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.aportes_ahorro ENABLE ROW LEVEL SECURITY;

--
-- Name: aportes_ahorro aportes_ahorro owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "aportes_ahorro owner access" ON public.aportes_ahorro USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: aportes_ahorro aportes_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY aportes_propio ON public.aportes_ahorro USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: billing_provider_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.billing_provider_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: billing_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.billing_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;

--
-- Name: categorias categorias owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "categorias owner access" ON public.categorias USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: categorias categorias_propio_actualiza; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_propio_actualiza ON public.categorias FOR UPDATE USING ((auth.uid() = usuario_id));


--
-- Name: categorias categorias_propio_elimina; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_propio_elimina ON public.categorias FOR DELETE USING ((auth.uid() = usuario_id));


--
-- Name: categorias categorias_propio_modifica; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_propio_modifica ON public.categorias FOR INSERT WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: categorias categorias_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY categorias_select ON public.categorias FOR SELECT USING (((usuario_id IS NULL) OR (auth.uid() = usuario_id)));


--
-- Name: developer_plan_overrides; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.developer_plan_overrides ENABLE ROW LEVEL SECURITY;

--
-- Name: metas_ahorro; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.metas_ahorro ENABLE ROW LEVEL SECURITY;

--
-- Name: metas_ahorro metas_ahorro owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "metas_ahorro owner access" ON public.metas_ahorro USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: metas_ahorro metas_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY metas_propio ON public.metas_ahorro USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: movimientos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.movimientos ENABLE ROW LEVEL SECURITY;

--
-- Name: movimientos movimientos owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "movimientos owner access" ON public.movimientos USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: movimientos movimientos_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY movimientos_propio ON public.movimientos USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: movimientos_recurrentes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.movimientos_recurrentes ENABLE ROW LEVEL SECURITY;

--
-- Name: movimientos_recurrentes movimientos_recurrentes owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "movimientos_recurrentes owner access" ON public.movimientos_recurrentes USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: notificaciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: notificaciones notificaciones owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "notificaciones owner access" ON public.notificaciones USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: notificaciones notificaciones_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notificaciones_propio ON public.notificaciones USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: otp_verificaciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_verificaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: perfiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;

--
-- Name: perfiles perfiles owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "perfiles owner access" ON public.perfiles USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: perfiles perfiles_propio_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY perfiles_propio_select ON public.perfiles FOR SELECT USING ((auth.uid() = id));


--
-- Name: perfiles perfiles_propio_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY perfiles_propio_update ON public.perfiles FOR UPDATE USING ((auth.uid() = id));


--
-- Name: planes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.planes ENABLE ROW LEVEL SECURITY;

--
-- Name: planes planes_lectura_publica; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY planes_lectura_publica ON public.planes FOR SELECT USING (true);


--
-- Name: presupuestos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.presupuestos ENABLE ROW LEVEL SECURITY;

--
-- Name: presupuestos presupuestos owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "presupuestos owner access" ON public.presupuestos USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: presupuestos presupuestos_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY presupuestos_propio ON public.presupuestos USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: recomendaciones_ia; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recomendaciones_ia ENABLE ROW LEVEL SECURITY;

--
-- Name: recomendaciones_ia recomendaciones_ia owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "recomendaciones_ia owner access" ON public.recomendaciones_ia USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: recomendaciones_ia recomendaciones_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recomendaciones_propio ON public.recomendaciones_ia USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: reportes_semanales reportes_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reportes_propio ON public.reportes_semanales USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: reportes_semanales; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reportes_semanales ENABLE ROW LEVEL SECURITY;

--
-- Name: reportes_semanales reportes_semanales owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "reportes_semanales owner access" ON public.reportes_semanales USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: sugerencias_texto sugerencias_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sugerencias_propio ON public.sugerencias_texto USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: sugerencias_texto; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sugerencias_texto ENABLE ROW LEVEL SECURITY;

--
-- Name: sugerencias_texto sugerencias_texto owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "sugerencias_texto owner access" ON public.sugerencias_texto USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: suscripciones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.suscripciones ENABLE ROW LEVEL SECURITY;

--
-- Name: suscripciones suscripciones owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "suscripciones owner access" ON public.suscripciones USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: suscripciones suscripciones_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY suscripciones_propio ON public.suscripciones USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: tareas; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tareas ENABLE ROW LEVEL SECURITY;

--
-- Name: tareas tareas owner access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "tareas owner access" ON public.tareas USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: tareas tareas_propio; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tareas_propio ON public.tareas USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: movimientos_recurrentes usuarios gestionan sus movimientos recurrentes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "usuarios gestionan sus movimientos recurrentes" ON public.movimientos_recurrentes USING ((auth.uid() = usuario_id)) WITH CHECK ((auth.uid() = usuario_id));


--
-- Name: whatsapp_sesiones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.whatsapp_sesiones ENABLE ROW LEVEL SECURITY;

--
-- Name: whatsapp_sesiones whatsapp_sesiones_propio_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY whatsapp_sesiones_propio_select ON public.whatsapp_sesiones FOR SELECT USING ((auth.uid() = usuario_activo_id));


--
-- PostgreSQL database dump complete
--

\unrestrict 3jLe581D3MbRognBAppNYqHZCAQwtFekNewJH403LmSGeuYRaBtdc3bm5tGsGY2
