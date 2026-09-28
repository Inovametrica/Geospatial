--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Debian 16.4-1.pgdg110+2)
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg110+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: admin
--

CREATE SCHEMA topology;


ALTER SCHEMA topology OWNER TO admin;

--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: admin
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: type_latest_status_ble; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_latest_status_ble AS (
	mac_address character varying(17),
	data bytea
);


ALTER TYPE public.type_latest_status_ble OWNER TO admin;

--
-- Name: type_raw_io_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_raw_io_batch AS (
	io_id integer,
	io_value bytea
);


ALTER TYPE public.type_raw_io_batch OWNER TO admin;

--
-- Name: type_sensor_data_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_sensor_data_batch AS (
	temp_id integer,
	id_sensor integer,
	valor character varying(50)
);


ALTER TYPE public.type_sensor_data_batch OWNER TO admin;

--
-- Name: usp_sync_latest_status(bigint, numeric, numeric, numeric, numeric, numeric, boolean, timestamp with time zone, timestamp with time zone, numeric, numeric, bigint, integer, timestamp with time zone, public.type_sensor_data_batch[], public.type_raw_io_batch[], public.type_latest_status_ble[]); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.usp_sync_latest_status(p_id_equipo bigint, p_latitud numeric, p_longitud numeric, p_altitud numeric, p_velocidad numeric, p_orientacion numeric, p_ignicion boolean, p_fecha_ultima_ignicion_utc timestamp with time zone, p_fecha_ulitmo_paquete_utc timestamp with time zone, p_odometro_acumulado numeric, p_segundos_motor_acumulado numeric, p_trafico_gprs_acumulado bigint, p_tipo_ultimo_paquete integer, p_fecha_ultimo_ping timestamp with time zone, p_sensores public.type_sensor_data_batch[], p_io_raw public.type_raw_io_batch[], p_ble public.type_latest_status_ble[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- PASO 1: Sincronizar la tabla de estado principal (Upsert con control de concurrencia optimista)
    INSERT INTO dat_estado_actual_equipos (
        id_equipo, latitud, longitud, altitud, velocidad, orientacion, 
        ignicion, fecha_ultima_ignicion_utc, fecha_ulitmo_paquete_utc, ubicacion, 
        odometro_acumulado, segundos_motor_acumulado, trafico_gprs_acumulado, 
        tipo_ultimo_paquete, fecha_ultimo_ping, claves_geocerca
    ) VALUES (
        p_id_equipo, p_latitud, p_longitud, p_altitud, p_velocidad, p_orientacion, 
        p_ignicion, p_fecha_ultima_ignicion_utc, p_fecha_ulitmo_paquete_utc, '', 
        p_odometro_acumulado, p_segundos_motor_acumulado, p_trafico_gprs_acumulado, 
        p_tipo_ultimo_paquete, p_fecha_ultimo_ping, ''
    )
    ON CONFLICT (id_equipo) DO UPDATE SET
        latitud = EXCLUDED.latitud,
        longitud = EXCLUDED.longitud,
        altitud = EXCLUDED.altitud,
        velocidad = EXCLUDED.velocidad,
        orientacion = EXCLUDED.orientacion,
        ignicion = EXCLUDED.ignicion,
        fecha_ultima_ignicion_utc = EXCLUDED.fecha_ultima_ignicion_utc,
        fecha_ulitmo_paquete_utc = EXCLUDED.fecha_ulitmo_paquete_utc,
        odometro_acumulado = EXCLUDED.odometro_acumulado,
        segundos_motor_acumulado = EXCLUDED.segundos_motor_acumulado,
        trafico_gprs_acumulado = EXCLUDED.trafico_gprs_acumulado,
        tipo_ultimo_paquete = EXCLUDED.tipo_ultimo_paquete,
        fecha_ultimo_ping = EXCLUDED.fecha_ultimo_ping
    WHERE dat_estado_actual_equipos.fecha_ulitmo_paquete_utc <= EXCLUDED.fecha_ulitmo_paquete_utc;

    -- PASO 2: Sincronizar Sensores
    IF array_length(p_sensores, 1) > 0 THEN
        INSERT INTO dat_estado_actual_sensores (id_equipo, id_sensor, valor, fechahora_utc_actualizacion)
        SELECT p_id_equipo, s.id_sensor, s.valor, p_fecha_ulitmo_paquete_utc
        FROM unnest(p_sensores) AS s
        ON CONFLICT (id_equipo, id_sensor) DO UPDATE SET
            valor = EXCLUDED.valor,
            fechahora_utc_actualizacion = EXCLUDED.fechahora_utc_actualizacion;
    END IF;

    -- PASO 3: Sincronizar Datos Crudos IO
    IF array_length(p_io_raw, 1) > 0 THEN
        INSERT INTO dat_estado_actual_io_raw (id_equipo, io_id, io_value)
        SELECT p_id_equipo, i.io_id, i.io_value
        FROM unnest(p_io_raw) AS i
        ON CONFLICT (id_equipo, io_id) DO UPDATE SET
            io_value = EXCLUDED.io_value;
    END IF;

    -- PASO 4: Sincronizar Datos Crudos BLE
    IF array_length(p_ble, 1) > 0 THEN
        INSERT INTO dat_estado_actual_ble (id_equipo, mac_address, data)
        SELECT p_id_equipo, b.mac_address, b.data
        FROM unnest(p_ble) AS b
        ON CONFLICT (id_equipo, mac_address) DO UPDATE SET
            data = EXCLUDED.data;
    END IF;
END;
$$;


ALTER FUNCTION public.usp_sync_latest_status(p_id_equipo bigint, p_latitud numeric, p_longitud numeric, p_altitud numeric, p_velocidad numeric, p_orientacion numeric, p_ignicion boolean, p_fecha_ultima_ignicion_utc timestamp with time zone, p_fecha_ulitmo_paquete_utc timestamp with time zone, p_odometro_acumulado numeric, p_segundos_motor_acumulado numeric, p_trafico_gprs_acumulado bigint, p_tipo_ultimo_paquete integer, p_fecha_ultimo_ping timestamp with time zone, p_sensores public.type_sensor_data_batch[], p_io_raw public.type_raw_io_batch[], p_ble public.type_latest_status_ble[]) OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cat_acciones_auditoria; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_acciones_auditoria (
    id_accion integer NOT NULL,
    nombre_accion character varying(50) NOT NULL,
    descripcion character varying(150)
);


ALTER TABLE public.cat_acciones_auditoria OWNER TO admin;

--
-- Name: cat_colores; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_colores (
    id_color integer NOT NULL,
    nombre character varying(50) NOT NULL
);


ALTER TABLE public.cat_colores OWNER TO admin;

--
-- Name: cat_colores_id_color_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_colores ALTER COLUMN id_color ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_colores_id_color_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_comandos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_comandos (
    id_comando integer NOT NULL,
    codigo_comando character varying(50) NOT NULL,
    nombre_comando character varying(100) NOT NULL,
    descripcion character varying(255),
    requiere_parametros boolean DEFAULT false NOT NULL,
    es_predeterminado boolean DEFAULT false NOT NULL
);


ALTER TABLE public.cat_comandos OWNER TO admin;

--
-- Name: cat_comandos_id_comando_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_comandos ALTER COLUMN id_comando ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_comandos_id_comando_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_cuentas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_cuentas (
    id_cuenta integer NOT NULL,
    id_cuenta_padre integer,
    nombre_cuenta character varying(150) NOT NULL,
    fecha_alta_utc timestamp(3) without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    estado smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.cat_cuentas OWNER TO admin;

--
-- Name: cat_cuentas_id_cuenta_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_cuentas ALTER COLUMN id_cuenta ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_cuentas_id_cuenta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_equipos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_equipos (
    id_equipo bigint NOT NULL,
    id_equipo_cliente character varying(100) NOT NULL,
    tag character varying(100) NOT NULL,
    id_cuenta integer NOT NULL,
    id_tipo_unidad integer NOT NULL,
    id_modelo_dispositivo integer NOT NULL,
    celular character varying(50),
    contrasena character varying(50),
    id_usuario_creador integer NOT NULL,
    id_icono integer,
    id_equipo_cliente_historico character varying(100),
    tag_historico character varying(100),
    fecha_alta_utc timestamp(3) without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    estado smallint DEFAULT 1 NOT NULL,
    es_confidencial boolean DEFAULT false NOT NULL
);


ALTER TABLE public.cat_equipos OWNER TO admin;

--
-- Name: cat_equipos_id_equipo_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_equipos ALTER COLUMN id_equipo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_equipos_id_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_fabricantes_dispositivos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_fabricantes_dispositivos (
    id_fabricante integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255)
);


ALTER TABLE public.cat_fabricantes_dispositivos OWNER TO admin;

--
-- Name: cat_fabricantes_dispositivos_id_fabricante_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_fabricantes_dispositivos ALTER COLUMN id_fabricante ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_fabricantes_dispositivos_id_fabricante_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_fuentes_contador; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_fuentes_contador (
    id_fuente_contador integer NOT NULL,
    id_tipo_contador integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.cat_fuentes_contador OWNER TO admin;

--
-- Name: cat_fuentes_contador_id_fuente_contador_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_fuentes_contador ALTER COLUMN id_fuente_contador ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_fuentes_contador_id_fuente_contador_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_geocercas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_geocercas (
    id_geocerca bigint NOT NULL,
    id_cuenta integer NOT NULL,
    id_usuario_creador integer NOT NULL,
    id_icono integer,
    nombre character varying(150) NOT NULL,
    descripcion character varying(500),
    color_hex character varying(10),
    tipo_geocerca character varying(20) NOT NULL,
    latitud_centro numeric(18,6),
    longitud_centro numeric(18,6),
    radio_metros integer,
    geometria public.geography(Geometry,4326),
    fecha_alta_utc timestamp(3) without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    fecha_caducidad_utc timestamp with time zone,
    estado smallint DEFAULT 1 NOT NULL,
    es_confidencial boolean DEFAULT false NOT NULL,
    CONSTRAINT ck_cat_geocercas_tipo CHECK (((tipo_geocerca)::text = ANY ((ARRAY['CIRCULO'::character varying, 'POLIGONO'::character varying])::text[])))
);


ALTER TABLE public.cat_geocercas OWNER TO admin;

--
-- Name: cat_geocercas_id_geocerca_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_geocercas ALTER COLUMN id_geocerca ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_geocercas_id_geocerca_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_grupos_geocercas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_grupos_geocercas (
    id_grupo_geocerca integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_usuario_creador integer NOT NULL,
    id_icono integer,
    nombre_grupo character varying(100) NOT NULL,
    descripcion character varying(255),
    estado smallint DEFAULT 1 NOT NULL,
    fecha_alta_utc timestamp(3) without time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    es_confidencial boolean DEFAULT false NOT NULL
);


ALTER TABLE public.cat_grupos_geocercas OWNER TO admin;

--
-- Name: cat_grupos_geocercas_id_grupo_geocerca_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_grupos_geocercas ALTER COLUMN id_grupo_geocerca ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_grupos_geocercas_id_grupo_geocerca_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_iconos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_iconos (
    id_icono integer NOT NULL,
    id_cuenta integer,
    id_usuario_creador integer,
    nombre character varying(100) NOT NULL,
    url_icono character varying(255) NOT NULL,
    es_sistema boolean DEFAULT false NOT NULL,
    estado smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.cat_iconos OWNER TO admin;

--
-- Name: cat_iconos_id_icono_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_iconos ALTER COLUMN id_icono ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_iconos_id_icono_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_marcas_vehiculos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_marcas_vehiculos (
    id_marca_vehiculo integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.cat_marcas_vehiculos OWNER TO admin;

--
-- Name: cat_marcas_vehiculos_id_marca_vehiculo_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_marcas_vehiculos ALTER COLUMN id_marca_vehiculo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_marcas_vehiculos_id_marca_vehiculo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_modelos_dispositivo; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_modelos_dispositivo (
    id_modelo_dispositivo integer NOT NULL,
    id_fabricante integer NOT NULL,
    nombre_modelo character varying(100) NOT NULL,
    descripcion character varying(255),
    entradas_digitales smallint DEFAULT 4 NOT NULL,
    salidas_digitales smallint DEFAULT 4 NOT NULL
);


ALTER TABLE public.cat_modelos_dispositivo OWNER TO admin;

--
-- Name: cat_modelos_dispositivo_id_modelo_dispositivo_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_modelos_dispositivo ALTER COLUMN id_modelo_dispositivo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_modelos_dispositivo_id_modelo_dispositivo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_modelos_vehiculos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_modelos_vehiculos (
    id_modelo_vehiculo integer NOT NULL,
    id_marca_vehiculo integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.cat_modelos_vehiculos OWNER TO admin;

--
-- Name: cat_modelos_vehiculos_id_modelo_vehiculo_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_modelos_vehiculos ALTER COLUMN id_modelo_vehiculo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_modelos_vehiculos_id_modelo_vehiculo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_perfil_modelos_motor; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_perfil_modelos_motor (
    id_modelo_motor integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_usuario_creador integer NOT NULL,
    nombre character varying(100) NOT NULL,
    estado smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.cat_perfil_modelos_motor OWNER TO admin;

--
-- Name: cat_perfil_modelos_motor_id_modelo_motor_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_perfil_modelos_motor ALTER COLUMN id_modelo_motor ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_perfil_modelos_motor_id_modelo_motor_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_perfil_tipos_carga; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_perfil_tipos_carga (
    id_tipo_carga integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_usuario_creador integer NOT NULL,
    nombre character varying(100) NOT NULL,
    estado smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.cat_perfil_tipos_carga OWNER TO admin;

--
-- Name: cat_perfil_tipos_carga_id_tipo_carga_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_perfil_tipos_carga ALTER COLUMN id_tipo_carga ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_perfil_tipos_carga_id_tipo_carga_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_permisos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_permisos (
    id_permiso integer NOT NULL,
    codigo_permiso character varying(50) NOT NULL,
    nombre_permiso character varying(150) NOT NULL,
    categoria character varying(50) NOT NULL,
    grupo character varying(50) NOT NULL
);


ALTER TABLE public.cat_permisos OWNER TO admin;

--
-- Name: cat_permisos_id_permiso_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_permisos ALTER COLUMN id_permiso ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_permisos_id_permiso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_roles; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_roles (
    id_role integer NOT NULL,
    id_cuenta integer DEFAULT 0 NOT NULL,
    nombre_role character varying(100) NOT NULL,
    descripcion character varying(255),
    es_sistema boolean DEFAULT false NOT NULL,
    estado smallint DEFAULT 1 NOT NULL,
    fecha_alta_utc timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    id_usuario_creador integer
);


ALTER TABLE public.cat_roles OWNER TO admin;

--
-- Name: cat_roles_id_role_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_roles ALTER COLUMN id_role ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_roles_id_role_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_sensores; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_sensores (
    id_sensor integer NOT NULL,
    codigo_sensor character varying(50) NOT NULL,
    nombre_sensor character varying(100) NOT NULL,
    descripcion character varying(255),
    unidad_medida character varying(20),
    es_predeterminado boolean DEFAULT false NOT NULL
);


ALTER TABLE public.cat_sensores OWNER TO admin;

--
-- Name: cat_sensores_id_sensor_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_sensores ALTER COLUMN id_sensor ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_sensores_id_sensor_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_teltonika_ios; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_teltonika_ios (
    io_id integer NOT NULL,
    nombre_humano character varying(100) NOT NULL,
    descripcion character varying(255),
    unidad_medida character varying(20)
);


ALTER TABLE public.cat_teltonika_ios OWNER TO admin;

--
-- Name: cat_tipos_combustible; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_tipos_combustible (
    id_tipo_combustible integer NOT NULL,
    nombre character varying(50) NOT NULL
);


ALTER TABLE public.cat_tipos_combustible OWNER TO admin;

--
-- Name: cat_tipos_combustible_id_tipo_combustible_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_tipos_combustible ALTER COLUMN id_tipo_combustible ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_tipos_combustible_id_tipo_combustible_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_tipos_contador; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_tipos_contador (
    id_tipo_contador integer NOT NULL,
    nombre character varying(100) NOT NULL,
    unidad_medida character varying(10) NOT NULL
);


ALTER TABLE public.cat_tipos_contador OWNER TO admin;

--
-- Name: cat_tipos_contador_id_tipo_contador_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_tipos_contador ALTER COLUMN id_tipo_contador ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_tipos_contador_id_tipo_contador_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_tipos_objeto; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_tipos_objeto (
    id_tipo_objeto integer NOT NULL,
    nombre_objeto character varying(100) NOT NULL
);


ALTER TABLE public.cat_tipos_objeto OWNER TO admin;

--
-- Name: cat_tipos_objeto_id_tipo_objeto_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_tipos_objeto ALTER COLUMN id_tipo_objeto ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_tipos_objeto_id_tipo_objeto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_tipos_unidad; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_tipos_unidad (
    id_tipo_unidad integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255)
);


ALTER TABLE public.cat_tipos_unidad OWNER TO admin;

--
-- Name: cat_tipos_unidad_id_tipo_unidad_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_tipos_unidad ALTER COLUMN id_tipo_unidad ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_tipos_unidad_id_tipo_unidad_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_usuarios; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.cat_usuarios (
    id_usuario integer NOT NULL,
    id_cuenta integer NOT NULL,
    nombre_completo character varying(200) NOT NULL,
    correo_electronico character varying(50) NOT NULL,
    clave text NOT NULL,
    nombre_corto character varying(50) NOT NULL,
    id_usuario_padre integer,
    id_usuario_creador integer,
    fecha_alta_utc timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    estado smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.cat_usuarios OWNER TO admin;

--
-- Name: cat_usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.cat_usuarios ALTER COLUMN id_usuario ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cat_usuarios_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: config_perfil_vehiculo; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.config_perfil_vehiculo (
    id_equipo bigint NOT NULL,
    vin character varying(50),
    placas character varying(10),
    economico character varying(100),
    id_marca_vehiculo integer,
    id_modelo_vehiculo integer,
    anio smallint,
    id_color integer,
    id_tipo_combustible integer,
    consumo_urbano_l_100km numeric(9,2),
    consumo_extraurbano_l_100km numeric(9,2),
    consumo_mixto_l_100km numeric(9,2),
    emision_co2_g_km numeric(9,2),
    id_modelo_motor integer,
    potencia_motor_hp numeric(9,2),
    potencia_motor_kw numeric(9,2),
    capacidad_motor_cc numeric(9,2),
    id_tipo_carga integer,
    carga_util_kg numeric(9,2),
    peso_bruto_kg numeric(9,2),
    volumen_util_m3 numeric(9,2),
    cantidad_ejes integer,
    dimension_largo_mm integer,
    dimension_ancho_mm integer,
    dimension_alto_mm integer,
    comentarios character varying(1000)
);


ALTER TABLE public.config_perfil_vehiculo OWNER TO admin;

--
-- Name: dat_cache_geocodificacion; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_cache_geocodificacion (
    latitud_truncada numeric(9,4) NOT NULL,
    longitud_truncada numeric(9,4) NOT NULL,
    calle character varying(255),
    numero_exterior character varying(30),
    colonia character varying(200),
    municipio character varying(200),
    ciudad character varying(200),
    estado character varying(200),
    pais character varying(100),
    codigo_postal character varying(20),
    ubicacion_completa character varying(1000),
    fecha_utc_actualizacion timestamp with time zone NOT NULL
);


ALTER TABLE public.dat_cache_geocodificacion OWNER TO admin;

--
-- Name: dat_equipos_en_geocercas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_equipos_en_geocercas (
    id_equipo bigint NOT NULL,
    id_geocerca bigint NOT NULL,
    fecha_utc_entrada timestamp with time zone NOT NULL
);


ALTER TABLE public.dat_equipos_en_geocercas OWNER TO admin;

--
-- Name: dat_estado_actual_ble; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_estado_actual_ble (
    id_equipo bigint NOT NULL,
    mac_address character varying(17) NOT NULL,
    data bytea NOT NULL
);


ALTER TABLE public.dat_estado_actual_ble OWNER TO admin;

--
-- Name: dat_estado_actual_equipos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_estado_actual_equipos (
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    altitud numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    ignicion boolean NOT NULL,
    fecha_ultima_ignicion_utc timestamp with time zone,
    fecha_ulitmo_paquete_utc timestamp with time zone,
    ubicacion character varying(500),
    geolocalizacion public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint((longitud)::double precision, (latitud)::double precision), 4326))::public.geography) STORED,
    odometro_acumulado numeric(18,3) NOT NULL,
    segundos_motor_acumulado numeric(18,3) NOT NULL,
    trafico_gprs_acumulado bigint NOT NULL,
    tipo_ultimo_paquete integer NOT NULL,
    fecha_ultimo_ping timestamp with time zone,
    claves_geocerca character varying(2000),
    ip_servidor_conectado character varying(50),
    puerto_servidor_conectado integer
);


ALTER TABLE public.dat_estado_actual_equipos OWNER TO admin;

--
-- Name: dat_estado_actual_io_raw; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_estado_actual_io_raw (
    id_equipo bigint NOT NULL,
    io_id integer NOT NULL,
    io_value bytea NOT NULL
);


ALTER TABLE public.dat_estado_actual_io_raw OWNER TO admin;

--
-- Name: dat_estado_actual_sensores; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_estado_actual_sensores (
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    valor character varying(50) NOT NULL,
    fechahora_utc_actualizacion timestamp with time zone NOT NULL
);


ALTER TABLE public.dat_estado_actual_sensores OWNER TO admin;

--
-- Name: dat_sesiones; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_sesiones (
    id_sesion bigint NOT NULL,
    id_usuario integer NOT NULL,
    refresh_token character varying(255) NOT NULL,
    fecha_expiracion timestamp with time zone NOT NULL,
    dispositivo character varying(255),
    id_cuenta_contexto integer NOT NULL,
    esta_revocado boolean DEFAULT false NOT NULL,
    fecha_creacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.dat_sesiones OWNER TO admin;

--
-- Name: dat_sesiones_id_sesion_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.dat_sesiones ALTER COLUMN id_sesion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dat_sesiones_id_sesion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: log_comandos_enviados; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.log_comandos_enviados (
    id_log_comando bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_comando integer NOT NULL,
    id_usuario_solicitante integer NOT NULL,
    fecha_solicitud_utc timestamp with time zone NOT NULL,
    parametros_adicionales character varying(500),
    estado_envio character varying(50) NOT NULL,
    fecha_confirmacion_utc timestamp with time zone,
    comando text,
    respuesta_equipo text
);


ALTER TABLE public.log_comandos_enviados OWNER TO admin;

--
-- Name: log_comandos_enviados_id_log_comando_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.log_comandos_enviados ALTER COLUMN id_log_comando ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.log_comandos_enviados_id_log_comando_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: rel_equipo_comando; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_equipo_comando (
    id_equipo bigint NOT NULL,
    id_comando integer NOT NULL,
    id_usuario_asignador integer NOT NULL,
    fecha_asignacion_utc timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.rel_equipo_comando OWNER TO admin;

--
-- Name: rel_equipo_contadores; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_equipo_contadores (
    id_equipo bigint NOT NULL,
    id_tipo_contador integer NOT NULL,
    id_fuente_contador integer NOT NULL,
    valor_inicial numeric(18,3) NOT NULL,
    es_automatico boolean NOT NULL
);


ALTER TABLE public.rel_equipo_contadores OWNER TO admin;

--
-- Name: rel_equipo_mapeo_sensores; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_equipo_mapeo_sensores (
    id_mapeo integer NOT NULL,
    id_equipo bigint NOT NULL,
    parametro_origen character varying(50) NOT NULL,
    codigo_sensor_real character varying(50) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_creacion_utc timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.rel_equipo_mapeo_sensores OWNER TO admin;

--
-- Name: rel_equipo_mapeo_sensores_id_mapeo_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.rel_equipo_mapeo_sensores ALTER COLUMN id_mapeo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.rel_equipo_mapeo_sensores_id_mapeo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: rel_equipo_sensor; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_equipo_sensor (
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    parametro_origen character varying(100) NOT NULL,
    nombre_personalizado character varying(100)
);


ALTER TABLE public.rel_equipo_sensor OWNER TO admin;

--
-- Name: rel_geocerca_grupo; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_geocerca_grupo (
    id_geocerca bigint NOT NULL,
    id_grupo_geocerca integer NOT NULL
);


ALTER TABLE public.rel_geocerca_grupo OWNER TO admin;

--
-- Name: rel_role_objeto_permiso; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_role_objeto_permiso (
    id_role integer NOT NULL,
    id_tipo_objeto integer NOT NULL,
    id_objeto bigint NOT NULL,
    id_permiso integer NOT NULL
);


ALTER TABLE public.rel_role_objeto_permiso OWNER TO admin;

--
-- Name: rel_role_permiso; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_role_permiso (
    id_role integer NOT NULL,
    id_permiso integer NOT NULL
);


ALTER TABLE public.rel_role_permiso OWNER TO admin;

--
-- Name: rel_usuario_objeto_permiso; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_usuario_objeto_permiso (
    id_usuario integer NOT NULL,
    id_tipo_objeto integer NOT NULL,
    id_objeto bigint NOT NULL,
    id_permiso integer NOT NULL
);


ALTER TABLE public.rel_usuario_objeto_permiso OWNER TO admin;

--
-- Name: rel_usuario_role; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rel_usuario_role (
    id_usuario integer NOT NULL,
    id_role integer NOT NULL
);


ALTER TABLE public.rel_usuario_role OWNER TO admin;

--
-- Name: vw_estado_vehiculos_geocercas; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.vw_estado_vehiculos_geocercas AS
 SELECT deg.id_equipo,
    e.tag AS nombre_equipo,
    deg.id_geocerca,
    g.nombre AS nombre_geocerca,
    g.tipo_geocerca,
    deg.fecha_utc_entrada,
    g.id_cuenta AS id_cuenta_geocerca,
    e.id_cuenta AS id_cuenta_equipo,
    g.es_confidencial AS geocerca_es_confidencial,
    e.es_confidencial AS equipo_es_confidencial,
    g.estado AS estado_geocerca,
    e.estado AS estado_equipo,
    g.id_usuario_creador AS geocerca_creador,
    e.id_usuario_creador AS equipo_creador
   FROM ((public.dat_equipos_en_geocercas deg
     JOIN public.cat_geocercas g ON ((deg.id_geocerca = g.id_geocerca)))
     JOIN public.cat_equipos e ON ((deg.id_equipo = e.id_equipo)));


ALTER VIEW public.vw_estado_vehiculos_geocercas OWNER TO admin;

--
-- Name: cat_acciones_auditoria pk_cat_acciones_auditoria; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_acciones_auditoria
    ADD CONSTRAINT pk_cat_acciones_auditoria PRIMARY KEY (id_accion);


--
-- Name: cat_colores pk_cat_colores; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_colores
    ADD CONSTRAINT pk_cat_colores PRIMARY KEY (id_color);


--
-- Name: cat_comandos pk_cat_comandos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_comandos
    ADD CONSTRAINT pk_cat_comandos PRIMARY KEY (id_comando);


--
-- Name: cat_cuentas pk_cat_cuentas; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_cuentas
    ADD CONSTRAINT pk_cat_cuentas PRIMARY KEY (id_cuenta);


--
-- Name: cat_equipos pk_cat_equipos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT pk_cat_equipos PRIMARY KEY (id_equipo);


--
-- Name: cat_fabricantes_dispositivos pk_cat_fabricantes_dispositivos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_fabricantes_dispositivos
    ADD CONSTRAINT pk_cat_fabricantes_dispositivos PRIMARY KEY (id_fabricante);


--
-- Name: cat_fuentes_contador pk_cat_fuentes_contador; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_fuentes_contador
    ADD CONSTRAINT pk_cat_fuentes_contador PRIMARY KEY (id_fuente_contador);


--
-- Name: cat_geocercas pk_cat_geocercas; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_geocercas
    ADD CONSTRAINT pk_cat_geocercas PRIMARY KEY (id_geocerca);


--
-- Name: cat_grupos_geocercas pk_cat_grupos_geocercas; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_grupos_geocercas
    ADD CONSTRAINT pk_cat_grupos_geocercas PRIMARY KEY (id_grupo_geocerca);


--
-- Name: cat_iconos pk_cat_iconos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_iconos
    ADD CONSTRAINT pk_cat_iconos PRIMARY KEY (id_icono);


--
-- Name: cat_marcas_vehiculos pk_cat_marcas_vehiculos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_marcas_vehiculos
    ADD CONSTRAINT pk_cat_marcas_vehiculos PRIMARY KEY (id_marca_vehiculo);


--
-- Name: cat_modelos_dispositivo pk_cat_modelos_dispositivo; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_modelos_dispositivo
    ADD CONSTRAINT pk_cat_modelos_dispositivo PRIMARY KEY (id_modelo_dispositivo);


--
-- Name: cat_modelos_vehiculos pk_cat_modelos_vehiculos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_modelos_vehiculos
    ADD CONSTRAINT pk_cat_modelos_vehiculos PRIMARY KEY (id_modelo_vehiculo);


--
-- Name: cat_perfil_modelos_motor pk_cat_perfil_modelos_motor; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_perfil_modelos_motor
    ADD CONSTRAINT pk_cat_perfil_modelos_motor PRIMARY KEY (id_modelo_motor);


--
-- Name: cat_perfil_tipos_carga pk_cat_perfil_tipos_carga; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_perfil_tipos_carga
    ADD CONSTRAINT pk_cat_perfil_tipos_carga PRIMARY KEY (id_tipo_carga);


--
-- Name: cat_permisos pk_cat_permisos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_permisos
    ADD CONSTRAINT pk_cat_permisos PRIMARY KEY (id_permiso);


--
-- Name: cat_roles pk_cat_roles; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_roles
    ADD CONSTRAINT pk_cat_roles PRIMARY KEY (id_role);


--
-- Name: cat_sensores pk_cat_sensores; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_sensores
    ADD CONSTRAINT pk_cat_sensores PRIMARY KEY (id_sensor);


--
-- Name: cat_teltonika_ios pk_cat_teltonika_ios; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_teltonika_ios
    ADD CONSTRAINT pk_cat_teltonika_ios PRIMARY KEY (io_id);


--
-- Name: cat_tipos_combustible pk_cat_tipos_combustible; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_combustible
    ADD CONSTRAINT pk_cat_tipos_combustible PRIMARY KEY (id_tipo_combustible);


--
-- Name: cat_tipos_contador pk_cat_tipos_contador; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_contador
    ADD CONSTRAINT pk_cat_tipos_contador PRIMARY KEY (id_tipo_contador);


--
-- Name: cat_tipos_objeto pk_cat_tipos_objeto; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_objeto
    ADD CONSTRAINT pk_cat_tipos_objeto PRIMARY KEY (id_tipo_objeto);


--
-- Name: cat_tipos_unidad pk_cat_tipos_unidad; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_unidad
    ADD CONSTRAINT pk_cat_tipos_unidad PRIMARY KEY (id_tipo_unidad);


--
-- Name: cat_usuarios pk_cat_usuarios; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_usuarios
    ADD CONSTRAINT pk_cat_usuarios PRIMARY KEY (id_usuario);


--
-- Name: config_perfil_vehiculo pk_config_perfil_vehiculo; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT pk_config_perfil_vehiculo PRIMARY KEY (id_equipo);


--
-- Name: dat_cache_geocodificacion pk_dat_cache_geocodificacion; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_cache_geocodificacion
    ADD CONSTRAINT pk_dat_cache_geocodificacion PRIMARY KEY (latitud_truncada, longitud_truncada);


--
-- Name: dat_equipos_en_geocercas pk_dat_equipos_en_geocercas; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_equipos_en_geocercas
    ADD CONSTRAINT pk_dat_equipos_en_geocercas PRIMARY KEY (id_equipo, id_geocerca);


--
-- Name: dat_estado_actual_ble pk_dat_estado_actual_ble; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_ble
    ADD CONSTRAINT pk_dat_estado_actual_ble PRIMARY KEY (id_equipo, mac_address);


--
-- Name: dat_estado_actual_equipos pk_dat_estado_actual_equipos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_equipos
    ADD CONSTRAINT pk_dat_estado_actual_equipos PRIMARY KEY (id_equipo);


--
-- Name: dat_estado_actual_io_raw pk_dat_estado_actual_io_raw; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_io_raw
    ADD CONSTRAINT pk_dat_estado_actual_io_raw PRIMARY KEY (id_equipo, io_id);


--
-- Name: dat_estado_actual_sensores pk_dat_estado_actual_sensores; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_sensores
    ADD CONSTRAINT pk_dat_estado_actual_sensores PRIMARY KEY (id_equipo, id_sensor);


--
-- Name: dat_sesiones pk_dat_sesiones; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_sesiones
    ADD CONSTRAINT pk_dat_sesiones PRIMARY KEY (id_sesion);


--
-- Name: log_comandos_enviados pk_log_comandos_enviados; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_comandos_enviados
    ADD CONSTRAINT pk_log_comandos_enviados PRIMARY KEY (id_log_comando);


--
-- Name: rel_equipo_comando pk_rel_equipo_comando; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_comando
    ADD CONSTRAINT pk_rel_equipo_comando PRIMARY KEY (id_equipo, id_comando);


--
-- Name: rel_equipo_contadores pk_rel_equipo_contadores; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_contadores
    ADD CONSTRAINT pk_rel_equipo_contadores PRIMARY KEY (id_equipo, id_tipo_contador);


--
-- Name: rel_equipo_mapeo_sensores pk_rel_equipo_mapeo_sensores; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_mapeo_sensores
    ADD CONSTRAINT pk_rel_equipo_mapeo_sensores PRIMARY KEY (id_mapeo);


--
-- Name: rel_equipo_sensor pk_rel_equipo_sensor; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_sensor
    ADD CONSTRAINT pk_rel_equipo_sensor PRIMARY KEY (id_equipo, id_sensor);


--
-- Name: rel_geocerca_grupo pk_rel_geocerca_grupo; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_geocerca_grupo
    ADD CONSTRAINT pk_rel_geocerca_grupo PRIMARY KEY (id_geocerca, id_grupo_geocerca);


--
-- Name: rel_role_objeto_permiso pk_rel_role_objeto_permiso; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_objeto_permiso
    ADD CONSTRAINT pk_rel_role_objeto_permiso PRIMARY KEY (id_role, id_tipo_objeto, id_objeto, id_permiso);


--
-- Name: rel_role_permiso pk_rel_role_permiso; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_permiso
    ADD CONSTRAINT pk_rel_role_permiso PRIMARY KEY (id_role, id_permiso);


--
-- Name: rel_usuario_objeto_permiso pk_rel_usuario_objeto_permiso; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_objeto_permiso
    ADD CONSTRAINT pk_rel_usuario_objeto_permiso PRIMARY KEY (id_usuario, id_tipo_objeto, id_objeto, id_permiso);


--
-- Name: rel_usuario_role pk_rel_usuario_role; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_role
    ADD CONSTRAINT pk_rel_usuario_role PRIMARY KEY (id_usuario, id_role);


--
-- Name: cat_acciones_auditoria uq_cat_acciones_auditoria_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_acciones_auditoria
    ADD CONSTRAINT uq_cat_acciones_auditoria_nombre UNIQUE (nombre_accion);


--
-- Name: cat_colores uq_cat_colores_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_colores
    ADD CONSTRAINT uq_cat_colores_nombre UNIQUE (nombre);


--
-- Name: cat_comandos uq_cat_comandos_codigo; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_comandos
    ADD CONSTRAINT uq_cat_comandos_codigo UNIQUE (codigo_comando);


--
-- Name: cat_cuentas uq_cat_cuentas_padre_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_cuentas
    ADD CONSTRAINT uq_cat_cuentas_padre_nombre UNIQUE NULLS NOT DISTINCT (id_cuenta_padre, nombre_cuenta);


--
-- Name: cat_equipos uq_cat_equipos_id_equipo_cliente; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT uq_cat_equipos_id_equipo_cliente UNIQUE (id_equipo_cliente);


--
-- Name: cat_equipos uq_cat_equipos_tag; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT uq_cat_equipos_tag UNIQUE (tag);


--
-- Name: cat_fabricantes_dispositivos uq_cat_fabricantes_dispositivos_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_fabricantes_dispositivos
    ADD CONSTRAINT uq_cat_fabricantes_dispositivos_nombre UNIQUE (nombre);


--
-- Name: cat_grupos_geocercas uq_cat_grupos_geocercas_cuenta_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_grupos_geocercas
    ADD CONSTRAINT uq_cat_grupos_geocercas_cuenta_nombre UNIQUE (id_cuenta, nombre_grupo);


--
-- Name: cat_marcas_vehiculos uq_cat_marcas_vehiculos_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_marcas_vehiculos
    ADD CONSTRAINT uq_cat_marcas_vehiculos_nombre UNIQUE (nombre);


--
-- Name: cat_permisos uq_cat_permisos_codigo; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_permisos
    ADD CONSTRAINT uq_cat_permisos_codigo UNIQUE (codigo_permiso);


--
-- Name: cat_roles uq_cat_roles_cuenta_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_roles
    ADD CONSTRAINT uq_cat_roles_cuenta_nombre UNIQUE (id_cuenta, nombre_role);


--
-- Name: cat_sensores uq_cat_sensores_codigo; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_sensores
    ADD CONSTRAINT uq_cat_sensores_codigo UNIQUE (codigo_sensor);


--
-- Name: cat_tipos_objeto uq_cat_tipos_objeto_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_objeto
    ADD CONSTRAINT uq_cat_tipos_objeto_nombre UNIQUE (nombre_objeto);


--
-- Name: cat_tipos_unidad uq_cat_tipos_unidad_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_unidad
    ADD CONSTRAINT uq_cat_tipos_unidad_nombre UNIQUE (nombre);


--
-- Name: cat_modelos_dispositivo uq_modelos_dispositivo_fabricante_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_modelos_dispositivo
    ADD CONSTRAINT uq_modelos_dispositivo_fabricante_nombre UNIQUE (id_fabricante, nombre_modelo);


--
-- Name: cat_modelos_vehiculos uq_modelos_vehiculos_marca_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_modelos_vehiculos
    ADD CONSTRAINT uq_modelos_vehiculos_marca_nombre UNIQUE (id_marca_vehiculo, nombre);


--
-- Name: rel_equipo_mapeo_sensores uq_rel_equipo_parametro; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_mapeo_sensores
    ADD CONSTRAINT uq_rel_equipo_parametro UNIQUE (id_equipo, parametro_origen);


--
-- Name: cat_tipos_combustible uq_tipos_combustible_nombre; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_tipos_combustible
    ADD CONSTRAINT uq_tipos_combustible_nombre UNIQUE (nombre);


--
-- Name: gin_cache_geocodificacion_ubicacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX gin_cache_geocodificacion_ubicacion ON public.dat_cache_geocodificacion USING gin (ubicacion_completa public.gin_trgm_ops);


--
-- Name: ix_cache_geocodificacion_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_cache_geocodificacion_fecha ON public.dat_cache_geocodificacion USING btree (fecha_utc_actualizacion);


--
-- Name: ix_cat_permisos_categoria_grupo; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_cat_permisos_categoria_grupo ON public.cat_permisos USING btree (categoria, grupo);


--
-- Name: ix_cat_roles_cuenta_activo; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_cat_roles_cuenta_activo ON public.cat_roles USING btree (id_cuenta) WHERE (estado = 1);


--
-- Name: ix_cat_sensores_predeterminado; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_cat_sensores_predeterminado ON public.cat_sensores USING btree (es_predeterminado) WHERE (es_predeterminado = true);


--
-- Name: ix_config_perfil_placas; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_config_perfil_placas ON public.config_perfil_vehiculo USING btree (placas);


--
-- Name: ix_config_perfil_vin; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_config_perfil_vin ON public.config_perfil_vehiculo USING btree (vin);


--
-- Name: ix_cuentas_padre; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_cuentas_padre ON public.cat_cuentas USING btree (id_cuenta_padre) INCLUDE (nombre_cuenta);


--
-- Name: ix_dat_equipos_en_geocercas_geocerca; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_equipos_en_geocercas_geocerca ON public.dat_equipos_en_geocercas USING btree (id_geocerca);


--
-- Name: ix_dat_sesiones_usuario; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_sesiones_usuario ON public.dat_sesiones USING btree (id_usuario) WHERE (esta_revocado = false);


--
-- Name: ix_equipos_cuenta_estado; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_equipos_cuenta_estado ON public.cat_equipos USING btree (id_cuenta, estado) INCLUDE (tag, id_equipo_cliente, id_tipo_unidad);


--
-- Name: ix_geocercas_cuenta_estado; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_geocercas_cuenta_estado ON public.cat_geocercas USING btree (id_cuenta, estado) INCLUDE (nombre, tipo_geocerca);


--
-- Name: ix_grupos_geocercas_cuenta_estado; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_grupos_geocercas_cuenta_estado ON public.cat_grupos_geocercas USING btree (id_cuenta, estado);


--
-- Name: ix_log_comandos_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_comandos_equipo_fecha ON public.log_comandos_enviados USING btree (id_equipo, fecha_solicitud_utc DESC);


--
-- Name: ix_modelos_motor_cuenta_estado; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_modelos_motor_cuenta_estado ON public.cat_perfil_modelos_motor USING btree (id_cuenta, estado) INCLUDE (nombre);


--
-- Name: ix_rel_equipo_comando_comando; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_equipo_comando_comando ON public.rel_equipo_comando USING btree (id_comando);


--
-- Name: ix_rel_equipo_sensor_sensor; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_equipo_sensor_sensor ON public.rel_equipo_sensor USING btree (id_sensor);


--
-- Name: ix_rel_geocerca_grupo_grupo; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_geocerca_grupo_grupo ON public.rel_geocerca_grupo USING btree (id_grupo_geocerca);


--
-- Name: ix_rel_role_objeto_seguridad; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_role_objeto_seguridad ON public.rel_role_objeto_permiso USING btree (id_objeto, id_tipo_objeto, id_role) INCLUDE (id_permiso);


--
-- Name: ix_rel_role_permiso_permiso; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_role_permiso_permiso ON public.rel_role_permiso USING btree (id_permiso);


--
-- Name: ix_rel_usuario_objeto_seguridad; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_usuario_objeto_seguridad ON public.rel_usuario_objeto_permiso USING btree (id_objeto, id_tipo_objeto, id_usuario) INCLUDE (id_permiso);


--
-- Name: ix_rel_usuario_role_role; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_rel_usuario_role_role ON public.rel_usuario_role USING btree (id_role);


--
-- Name: ix_tipos_carga_cuenta_estado; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_tipos_carga_cuenta_estado ON public.cat_perfil_tipos_carga USING btree (id_cuenta, estado) INCLUDE (nombre);


--
-- Name: ix_usuarios_cuenta; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_usuarios_cuenta ON public.cat_usuarios USING btree (id_cuenta, estado);


--
-- Name: six_cat_geocercas_geometria; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX six_cat_geocercas_geometria ON public.cat_geocercas USING gist (geometria);


--
-- Name: six_estado_actual_geolocalizacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX six_estado_actual_geolocalizacion ON public.dat_estado_actual_equipos USING gist (geolocalizacion);


--
-- Name: uq_cat_usuarios_correo; Type: INDEX; Schema: public; Owner: admin
--

CREATE UNIQUE INDEX uq_cat_usuarios_correo ON public.cat_usuarios USING btree (correo_electronico) WHERE (estado >= 0);


--
-- Name: uq_dat_sesiones_token; Type: INDEX; Schema: public; Owner: admin
--

CREATE UNIQUE INDEX uq_dat_sesiones_token ON public.dat_sesiones USING btree (refresh_token);


--
-- Name: uq_modelos_motor_cuenta_nombre; Type: INDEX; Schema: public; Owner: admin
--

CREATE UNIQUE INDEX uq_modelos_motor_cuenta_nombre ON public.cat_perfil_modelos_motor USING btree (id_cuenta, nombre) WHERE (estado = 1);


--
-- Name: uq_tipos_carga_cuenta_nombre; Type: INDEX; Schema: public; Owner: admin
--

CREATE UNIQUE INDEX uq_tipos_carga_cuenta_nombre ON public.cat_perfil_tipos_carga USING btree (id_cuenta, nombre) WHERE (estado = 1);


--
-- Name: cat_cuentas fk_cat_cuentas_padre; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_cuentas
    ADD CONSTRAINT fk_cat_cuentas_padre FOREIGN KEY (id_cuenta_padre) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_geocercas fk_cat_geocercas_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_geocercas
    ADD CONSTRAINT fk_cat_geocercas_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_geocercas fk_cat_geocercas_iconos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_geocercas
    ADD CONSTRAINT fk_cat_geocercas_iconos FOREIGN KEY (id_icono) REFERENCES public.cat_iconos(id_icono);


--
-- Name: cat_geocercas fk_cat_geocercas_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_geocercas
    ADD CONSTRAINT fk_cat_geocercas_usuarios FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: cat_grupos_geocercas fk_cat_grupos_geocercas_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_grupos_geocercas
    ADD CONSTRAINT fk_cat_grupos_geocercas_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_grupos_geocercas fk_cat_grupos_geocercas_iconos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_grupos_geocercas
    ADD CONSTRAINT fk_cat_grupos_geocercas_iconos FOREIGN KEY (id_icono) REFERENCES public.cat_iconos(id_icono);


--
-- Name: cat_grupos_geocercas fk_cat_grupos_geocercas_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_grupos_geocercas
    ADD CONSTRAINT fk_cat_grupos_geocercas_usuarios FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: cat_roles fk_cat_roles_usuario_creador; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_roles
    ADD CONSTRAINT fk_cat_roles_usuario_creador FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: config_perfil_vehiculo fk_config_perfil_colores; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_colores FOREIGN KEY (id_color) REFERENCES public.cat_colores(id_color);


--
-- Name: config_perfil_vehiculo fk_config_perfil_combustible; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_combustible FOREIGN KEY (id_tipo_combustible) REFERENCES public.cat_tipos_combustible(id_tipo_combustible);


--
-- Name: config_perfil_vehiculo fk_config_perfil_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: config_perfil_vehiculo fk_config_perfil_marcas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_marcas FOREIGN KEY (id_marca_vehiculo) REFERENCES public.cat_marcas_vehiculos(id_marca_vehiculo);


--
-- Name: config_perfil_vehiculo fk_config_perfil_modelos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_modelos FOREIGN KEY (id_modelo_vehiculo) REFERENCES public.cat_modelos_vehiculos(id_modelo_vehiculo);


--
-- Name: config_perfil_vehiculo fk_config_perfil_modelos_motor; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_modelos_motor FOREIGN KEY (id_modelo_motor) REFERENCES public.cat_perfil_modelos_motor(id_modelo_motor);


--
-- Name: config_perfil_vehiculo fk_config_perfil_tipos_carga; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.config_perfil_vehiculo
    ADD CONSTRAINT fk_config_perfil_tipos_carga FOREIGN KEY (id_tipo_carga) REFERENCES public.cat_perfil_tipos_carga(id_tipo_carga);


--
-- Name: dat_equipos_en_geocercas fk_dat_equipos_en_geocercas_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_equipos_en_geocercas
    ADD CONSTRAINT fk_dat_equipos_en_geocercas_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: dat_equipos_en_geocercas fk_dat_equipos_en_geocercas_geocercas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_equipos_en_geocercas
    ADD CONSTRAINT fk_dat_equipos_en_geocercas_geocercas FOREIGN KEY (id_geocerca) REFERENCES public.cat_geocercas(id_geocerca) ON DELETE CASCADE;


--
-- Name: dat_estado_actual_ble fk_dat_estado_actual_ble_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_ble
    ADD CONSTRAINT fk_dat_estado_actual_ble_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: dat_estado_actual_io_raw fk_dat_estado_actual_io_raw_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_io_raw
    ADD CONSTRAINT fk_dat_estado_actual_io_raw_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: rel_equipo_sensor fk_equipo_sensor_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_sensor
    ADD CONSTRAINT fk_equipo_sensor_catalogo FOREIGN KEY (id_sensor) REFERENCES public.cat_sensores(id_sensor);


--
-- Name: rel_equipo_sensor fk_equipo_sensor_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_sensor
    ADD CONSTRAINT fk_equipo_sensor_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: cat_equipos fk_equipos_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT fk_equipos_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_equipos fk_equipos_iconos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT fk_equipos_iconos FOREIGN KEY (id_icono) REFERENCES public.cat_iconos(id_icono);


--
-- Name: cat_equipos fk_equipos_modelos_dispositivo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT fk_equipos_modelos_dispositivo FOREIGN KEY (id_modelo_dispositivo) REFERENCES public.cat_modelos_dispositivo(id_modelo_dispositivo);


--
-- Name: cat_equipos fk_equipos_tipos_unidad; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT fk_equipos_tipos_unidad FOREIGN KEY (id_tipo_unidad) REFERENCES public.cat_tipos_unidad(id_tipo_unidad);


--
-- Name: cat_equipos fk_equipos_usuarios_creador; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_equipos
    ADD CONSTRAINT fk_equipos_usuarios_creador FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: dat_estado_actual_equipos fk_estado_actual_cat_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_equipos
    ADD CONSTRAINT fk_estado_actual_cat_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: dat_estado_actual_sensores fk_estado_sensores_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_sensores
    ADD CONSTRAINT fk_estado_sensores_catalogo FOREIGN KEY (id_sensor) REFERENCES public.cat_sensores(id_sensor);


--
-- Name: dat_estado_actual_sensores fk_estado_sensores_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_estado_actual_sensores
    ADD CONSTRAINT fk_estado_sensores_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: cat_fuentes_contador fk_fuente_tipo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_fuentes_contador
    ADD CONSTRAINT fk_fuente_tipo FOREIGN KEY (id_tipo_contador) REFERENCES public.cat_tipos_contador(id_tipo_contador);


--
-- Name: cat_iconos fk_iconos_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_iconos
    ADD CONSTRAINT fk_iconos_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_iconos fk_iconos_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_iconos
    ADD CONSTRAINT fk_iconos_usuarios FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: log_comandos_enviados fk_log_comandos_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_comandos_enviados
    ADD CONSTRAINT fk_log_comandos_catalogo FOREIGN KEY (id_comando) REFERENCES public.cat_comandos(id_comando);


--
-- Name: log_comandos_enviados fk_log_comandos_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_comandos_enviados
    ADD CONSTRAINT fk_log_comandos_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo);


--
-- Name: log_comandos_enviados fk_log_comandos_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_comandos_enviados
    ADD CONSTRAINT fk_log_comandos_usuarios FOREIGN KEY (id_usuario_solicitante) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: cat_modelos_dispositivo fk_modelos_dispositivo_fabricante; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_modelos_dispositivo
    ADD CONSTRAINT fk_modelos_dispositivo_fabricante FOREIGN KEY (id_fabricante) REFERENCES public.cat_fabricantes_dispositivos(id_fabricante);


--
-- Name: cat_perfil_modelos_motor fk_modelos_motor_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_perfil_modelos_motor
    ADD CONSTRAINT fk_modelos_motor_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_perfil_modelos_motor fk_modelos_motor_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_perfil_modelos_motor
    ADD CONSTRAINT fk_modelos_motor_usuarios FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: cat_modelos_vehiculos fk_modelos_vehiculos_marca; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_modelos_vehiculos
    ADD CONSTRAINT fk_modelos_vehiculos_marca FOREIGN KEY (id_marca_vehiculo) REFERENCES public.cat_marcas_vehiculos(id_marca_vehiculo);


--
-- Name: rel_usuario_objeto_permiso fk_permiso_polimorfico_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_objeto_permiso
    ADD CONSTRAINT fk_permiso_polimorfico_catalogo FOREIGN KEY (id_permiso) REFERENCES public.cat_permisos(id_permiso);


--
-- Name: rel_usuario_objeto_permiso fk_permiso_polimorfico_tipos_objeto; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_objeto_permiso
    ADD CONSTRAINT fk_permiso_polimorfico_tipos_objeto FOREIGN KEY (id_tipo_objeto) REFERENCES public.cat_tipos_objeto(id_tipo_objeto);


--
-- Name: rel_usuario_objeto_permiso fk_permiso_polimorfico_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_objeto_permiso
    ADD CONSTRAINT fk_permiso_polimorfico_usuarios FOREIGN KEY (id_usuario) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: rel_equipo_comando fk_rel_comando_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_comando
    ADD CONSTRAINT fk_rel_comando_catalogo FOREIGN KEY (id_comando) REFERENCES public.cat_comandos(id_comando) ON DELETE CASCADE;


--
-- Name: rel_equipo_comando fk_rel_comando_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_comando
    ADD CONSTRAINT fk_rel_comando_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: rel_equipo_comando fk_rel_comando_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_comando
    ADD CONSTRAINT fk_rel_comando_usuarios FOREIGN KEY (id_usuario_asignador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: rel_equipo_contadores fk_rel_contadores_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_contadores
    ADD CONSTRAINT fk_rel_contadores_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo) ON DELETE CASCADE;


--
-- Name: rel_equipo_contadores fk_rel_contadores_fuentes; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_contadores
    ADD CONSTRAINT fk_rel_contadores_fuentes FOREIGN KEY (id_fuente_contador) REFERENCES public.cat_fuentes_contador(id_fuente_contador);


--
-- Name: rel_equipo_contadores fk_rel_contadores_tipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_contadores
    ADD CONSTRAINT fk_rel_contadores_tipos FOREIGN KEY (id_tipo_contador) REFERENCES public.cat_tipos_contador(id_tipo_contador);


--
-- Name: rel_geocerca_grupo fk_rel_geocerca_grupo_geocercas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_geocerca_grupo
    ADD CONSTRAINT fk_rel_geocerca_grupo_geocercas FOREIGN KEY (id_geocerca) REFERENCES public.cat_geocercas(id_geocerca) ON DELETE CASCADE;


--
-- Name: rel_geocerca_grupo fk_rel_geocerca_grupo_grupos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_geocerca_grupo
    ADD CONSTRAINT fk_rel_geocerca_grupo_grupos FOREIGN KEY (id_grupo_geocerca) REFERENCES public.cat_grupos_geocercas(id_grupo_geocerca) ON DELETE CASCADE;


--
-- Name: rel_equipo_mapeo_sensores fk_rel_mapeo_cat_sensores; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_mapeo_sensores
    ADD CONSTRAINT fk_rel_mapeo_cat_sensores FOREIGN KEY (codigo_sensor_real) REFERENCES public.cat_sensores(codigo_sensor);


--
-- Name: rel_equipo_mapeo_sensores fk_rel_mapeo_equipos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_equipo_mapeo_sensores
    ADD CONSTRAINT fk_rel_mapeo_equipos FOREIGN KEY (id_equipo) REFERENCES public.cat_equipos(id_equipo);


--
-- Name: rel_role_objeto_permiso fk_role_objeto_permiso_permisos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_objeto_permiso
    ADD CONSTRAINT fk_role_objeto_permiso_permisos FOREIGN KEY (id_permiso) REFERENCES public.cat_permisos(id_permiso);


--
-- Name: rel_role_objeto_permiso fk_role_objeto_permiso_roles; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_objeto_permiso
    ADD CONSTRAINT fk_role_objeto_permiso_roles FOREIGN KEY (id_role) REFERENCES public.cat_roles(id_role) ON DELETE CASCADE;


--
-- Name: rel_role_objeto_permiso fk_role_objeto_permiso_tipos_objeto; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_objeto_permiso
    ADD CONSTRAINT fk_role_objeto_permiso_tipos_objeto FOREIGN KEY (id_tipo_objeto) REFERENCES public.cat_tipos_objeto(id_tipo_objeto);


--
-- Name: rel_role_permiso fk_role_permiso_permisos; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_permiso
    ADD CONSTRAINT fk_role_permiso_permisos FOREIGN KEY (id_permiso) REFERENCES public.cat_permisos(id_permiso) ON DELETE CASCADE;


--
-- Name: rel_role_permiso fk_role_permiso_roles; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_role_permiso
    ADD CONSTRAINT fk_role_permiso_roles FOREIGN KEY (id_role) REFERENCES public.cat_roles(id_role) ON DELETE CASCADE;


--
-- Name: dat_sesiones fk_sesiones_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_sesiones
    ADD CONSTRAINT fk_sesiones_usuarios FOREIGN KEY (id_usuario) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: cat_perfil_tipos_carga fk_tipos_carga_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_perfil_tipos_carga
    ADD CONSTRAINT fk_tipos_carga_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- Name: cat_perfil_tipos_carga fk_tipos_carga_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_perfil_tipos_carga
    ADD CONSTRAINT fk_tipos_carga_usuarios FOREIGN KEY (id_usuario_creador) REFERENCES public.cat_usuarios(id_usuario);


--
-- Name: rel_usuario_role fk_usuario_role_roles; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_role
    ADD CONSTRAINT fk_usuario_role_roles FOREIGN KEY (id_role) REFERENCES public.cat_roles(id_role) ON DELETE CASCADE;


--
-- Name: rel_usuario_role fk_usuario_role_usuarios; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rel_usuario_role
    ADD CONSTRAINT fk_usuario_role_usuarios FOREIGN KEY (id_usuario) REFERENCES public.cat_usuarios(id_usuario) ON DELETE CASCADE;


--
-- Name: cat_usuarios fk_usuarios_cuentas; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.cat_usuarios
    ADD CONSTRAINT fk_usuarios_cuentas FOREIGN KEY (id_cuenta) REFERENCES public.cat_cuentas(id_cuenta);


--
-- PostgreSQL database dump complete
--

