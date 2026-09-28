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
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: type_geofence_event_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_geofence_event_batch AS (
	temp_id integer,
	id_gps bigint,
	id_equipo bigint,
	latitud numeric(18,6),
	longitud numeric(18,6),
	odometro numeric(18,3),
	velocidad numeric(18,3),
	velocidad_maxima_kmh numeric(18,3),
	velocidad_promedio_kmh numeric(18,3),
	orientacion numeric(18,3),
	fechahora_utc timestamp with time zone,
	fechahora_utc_recepcion timestamp with time zone,
	evento integer,
	id_geoespacial bigint,
	nombre_geoespacial character varying(100),
	tipo_geoespacial smallint,
	tiempo_estancia_segundos numeric(18,3)
);


ALTER TYPE public.type_geofence_event_batch OWNER TO admin;

--
-- Name: type_gps_ble_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_gps_ble_batch AS (
	temp_id integer,
	mac_address character varying(17),
	data bytea
);


ALTER TYPE public.type_gps_ble_batch OWNER TO admin;

--
-- Name: type_gps_event_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_gps_event_batch AS (
	temp_id integer,
	id_equipo bigint,
	latitud numeric(18,6),
	longitud numeric(18,6),
	altitud numeric(18,3),
	velocidad numeric(18,3),
	orientacion numeric(18,3),
	ignicion boolean,
	fechahora_utc timestamp with time zone,
	fechahora_utc_recepcion timestamp with time zone,
	odometro_acumulado numeric(18,3),
	segundos_motor_acumulado bigint,
	trafico_gprs_acumulado bigint,
	tipo_paquete integer
);


ALTER TYPE public.type_gps_event_batch OWNER TO admin;

--
-- Name: type_gps_geocoding_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_gps_geocoding_batch AS (
	id_gps bigint,
	id_equipo bigint,
	fechahora_utc timestamp with time zone,
	latitud numeric(18,6),
	longitud numeric(18,6),
	calle character varying(255),
	numero_exterior character varying(30),
	colonia character varying(200),
	ciudad character varying(200),
	estado character varying(200),
	pais character varying(100),
	codigo_postal character varying(20),
	ubicacion_completa character varying(1000)
);


ALTER TYPE public.type_gps_geocoding_batch OWNER TO admin;

--
-- Name: type_gps_io_raw_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_gps_io_raw_batch AS (
	temp_id integer,
	io_id integer,
	io_value bytea
);


ALTER TYPE public.type_gps_io_raw_batch OWNER TO admin;

--
-- Name: type_gps_sensor_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_gps_sensor_batch AS (
	temp_id integer,
	id_sensor integer,
	valor character varying(50)
);


ALTER TYPE public.type_gps_sensor_batch OWNER TO admin;

--
-- Name: type_reporte_calles_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_reporte_calles_batch AS (
	id_equipo bigint,
	id_gps_entrada bigint,
	calle character varying(255),
	ubicacion_completa character varying(1000),
	latitud_entrada numeric(18,6),
	longitud_entrada numeric(18,6),
	fechahora_utc_entrada timestamp with time zone,
	fechahora_utc_salida timestamp with time zone,
	tiempo_transcurrido_seg integer,
	distancia_recorrida_km numeric(18,3),
	velocidad_maxima_kmh numeric(18,2),
	velocidad_media_kmh numeric(18,2)
);


ALTER TYPE public.type_reporte_calles_batch OWNER TO admin;

--
-- Name: type_tcp_data_batch; Type: TYPE; Schema: public; Owner: admin
--

CREATE TYPE public.type_tcp_data_batch AS (
	temp_id integer,
	id_equipo bigint,
	datos_ascii text,
	datos_binarios bytea,
	decodificacion text,
	fechahora_utc timestamp with time zone
);


ALTER TYPE public.type_tcp_data_batch OWNER TO admin;

--
-- Name: usp_insert_gps_geocoding_batch(public.type_gps_geocoding_batch[]); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.usp_insert_gps_geocoding_batch(p_geocoded_events public.type_gps_geocoding_batch[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dat_gps_geocodificacion (
        id_gps, id_equipo, fechahora_utc, latitud, longitud,
        calle, numero_exterior, colonia, ciudad, estado,
        pais, codigo_postal, ubicacion_completa
    )
    SELECT
        g.id_gps, g.id_equipo, g.fechahora_utc, g.latitud, g.longitud,
        g.calle, g.numero_exterior, g.colonia, g.ciudad, g.estado,
        g.pais, g.codigo_postal, g.ubicacion_completa
    FROM unnest(p_geocoded_events) AS g;
END;
$$;


ALTER FUNCTION public.usp_insert_gps_geocoding_batch(p_geocoded_events public.type_gps_geocoding_batch[]) OWNER TO admin;

--
-- Name: usp_insert_reporte_calles_batch(public.type_reporte_calles_batch[]); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.usp_insert_reporte_calles_batch(p_eventos_calle public.type_reporte_calles_batch[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO dat_reporte_calles_visitadas (
        id_equipo, id_gps_entrada, calle, ubicacion_completa,
        latitud_entrada, longitud_entrada, fechahora_utc_entrada,
        fechahora_utc_salida, tiempo_transcurrido_seg, distancia_recorrida_km,
        velocidad_maxima_kmh, velocidad_media_kmh
    )
    SELECT
        e.id_equipo, e.id_gps_entrada, e.calle, e.ubicacion_completa,
        e.latitud_entrada, e.longitud_entrada, e.fechahora_utc_entrada,
        e.fechahora_utc_salida, e.tiempo_transcurrido_seg, e.distancia_recorrida_km,
        e.velocidad_maxima_kmh, e.velocidad_media_kmh
    FROM unnest(p_eventos_calle) AS e;
END;
$$;


ALTER FUNCTION public.usp_insert_reporte_calles_batch(p_eventos_calle public.type_reporte_calles_batch[]) OWNER TO admin;

SET default_tablespace = '';

--
-- Name: dat_geoespacial_eventos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_geoespacial_eventos (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    odometro numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,3) NOT NULL,
    velocidad_promedio_kmh numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    evento integer NOT NULL,
    id_geoespacial bigint NOT NULL,
    nombre_geoespacial character varying(100),
    tipo_geoespacial smallint NOT NULL,
    tiempo_estancia_segundos numeric(18,3) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_geoespacial_eventos OWNER TO admin;

SET default_table_access_method = heap;

--
-- Name: dat_geoespacial_eventos_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_geoespacial_eventos_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    odometro numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,3) NOT NULL,
    velocidad_promedio_kmh numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    evento integer NOT NULL,
    id_geoespacial bigint NOT NULL,
    nombre_geoespacial character varying(100),
    tipo_geoespacial smallint NOT NULL,
    tiempo_estancia_segundos numeric(18,3) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_geoespacial_eventos_2026_q1 OWNER TO admin;

--
-- Name: dat_geoespacial_eventos_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_geoespacial_eventos_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    odometro numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,3) NOT NULL,
    velocidad_promedio_kmh numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    evento integer NOT NULL,
    id_geoespacial bigint NOT NULL,
    nombre_geoespacial character varying(100),
    tipo_geoespacial smallint NOT NULL,
    tiempo_estancia_segundos numeric(18,3) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_geoespacial_eventos_2026_q2 OWNER TO admin;

--
-- Name: dat_geoespacial_eventos_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_geoespacial_eventos_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    odometro numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,3) NOT NULL,
    velocidad_promedio_kmh numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    evento integer NOT NULL,
    id_geoespacial bigint NOT NULL,
    nombre_geoespacial character varying(100),
    tipo_geoespacial smallint NOT NULL,
    tiempo_estancia_segundos numeric(18,3) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_geoespacial_eventos_2026_q3 OWNER TO admin;

--
-- Name: dat_geoespacial_eventos_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_geoespacial_eventos_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    odometro numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,3) NOT NULL,
    velocidad_promedio_kmh numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    evento integer NOT NULL,
    id_geoespacial bigint NOT NULL,
    nombre_geoespacial character varying(100),
    tipo_geoespacial smallint NOT NULL,
    tiempo_estancia_segundos numeric(18,3) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_geoespacial_eventos_2026_q4 OWNER TO admin;

--
-- Name: dat_gps_ble; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_ble (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    mac_address character varying(17) NOT NULL,
    data bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_gps_ble OWNER TO admin;

--
-- Name: dat_gps_ble_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_ble_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    mac_address character varying(17) NOT NULL,
    data bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_ble_2026_q1 OWNER TO admin;

--
-- Name: dat_gps_ble_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_ble_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    mac_address character varying(17) NOT NULL,
    data bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_ble_2026_q2 OWNER TO admin;

--
-- Name: dat_gps_ble_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_ble_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    mac_address character varying(17) NOT NULL,
    data bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_ble_2026_q3 OWNER TO admin;

--
-- Name: dat_gps_ble_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_ble_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    mac_address character varying(17) NOT NULL,
    data bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_ble_2026_q4 OWNER TO admin;

--
-- Name: dat_gps_equipos; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_equipos (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    altitud numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    ignicion boolean NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    geolocalizacion public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint((longitud)::double precision, (latitud)::double precision), 4326))::public.geography) STORED,
    odometro_acumulado numeric(18,3) NOT NULL,
    segundos_motor_acumulado bigint NOT NULL,
    trafico_gprs_acumulado bigint NOT NULL,
    tipo_paquete integer NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_gps_equipos OWNER TO admin;

--
-- Name: dat_gps_equipos_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_equipos_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    altitud numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    ignicion boolean NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    geolocalizacion public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint((longitud)::double precision, (latitud)::double precision), 4326))::public.geography) STORED,
    odometro_acumulado numeric(18,3) NOT NULL,
    segundos_motor_acumulado bigint NOT NULL,
    trafico_gprs_acumulado bigint NOT NULL,
    tipo_paquete integer NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_equipos_2026_q1 OWNER TO admin;

--
-- Name: dat_gps_equipos_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_equipos_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    altitud numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    ignicion boolean NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    geolocalizacion public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint((longitud)::double precision, (latitud)::double precision), 4326))::public.geography) STORED,
    odometro_acumulado numeric(18,3) NOT NULL,
    segundos_motor_acumulado bigint NOT NULL,
    trafico_gprs_acumulado bigint NOT NULL,
    tipo_paquete integer NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_equipos_2026_q2 OWNER TO admin;

--
-- Name: dat_gps_equipos_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_equipos_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    altitud numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    ignicion boolean NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    geolocalizacion public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint((longitud)::double precision, (latitud)::double precision), 4326))::public.geography) STORED,
    odometro_acumulado numeric(18,3) NOT NULL,
    segundos_motor_acumulado bigint NOT NULL,
    trafico_gprs_acumulado bigint NOT NULL,
    tipo_paquete integer NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_equipos_2026_q3 OWNER TO admin;

--
-- Name: dat_gps_equipos_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_equipos_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    altitud numeric(18,3) NOT NULL,
    velocidad numeric(18,3) NOT NULL,
    orientacion numeric(18,3) NOT NULL,
    ignicion boolean NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    fechahora_utc_recepcion timestamp(3) with time zone NOT NULL,
    geolocalizacion public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint((longitud)::double precision, (latitud)::double precision), 4326))::public.geography) STORED,
    odometro_acumulado numeric(18,3) NOT NULL,
    segundos_motor_acumulado bigint NOT NULL,
    trafico_gprs_acumulado bigint NOT NULL,
    tipo_paquete integer NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_equipos_2026_q4 OWNER TO admin;

--
-- Name: dat_gps_equipos_id_gps_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.dat_gps_equipos ALTER COLUMN id_gps ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dat_gps_equipos_id_gps_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dat_gps_geocodificacion; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_geocodificacion (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    calle character varying(255),
    numero_exterior character varying(30),
    colonia character varying(200),
    ciudad character varying(200),
    estado character varying(200),
    pais character varying(100),
    codigo_postal character varying(20),
    ubicacion_completa character varying(1000),
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_gps_geocodificacion OWNER TO admin;

--
-- Name: dat_gps_geocodificacion_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_geocodificacion_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    calle character varying(255),
    numero_exterior character varying(30),
    colonia character varying(200),
    ciudad character varying(200),
    estado character varying(200),
    pais character varying(100),
    codigo_postal character varying(20),
    ubicacion_completa character varying(1000),
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_geocodificacion_2026_q1 OWNER TO admin;

--
-- Name: dat_gps_geocodificacion_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_geocodificacion_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    calle character varying(255),
    numero_exterior character varying(30),
    colonia character varying(200),
    ciudad character varying(200),
    estado character varying(200),
    pais character varying(100),
    codigo_postal character varying(20),
    ubicacion_completa character varying(1000),
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_geocodificacion_2026_q2 OWNER TO admin;

--
-- Name: dat_gps_geocodificacion_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_geocodificacion_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    calle character varying(255),
    numero_exterior character varying(30),
    colonia character varying(200),
    ciudad character varying(200),
    estado character varying(200),
    pais character varying(100),
    codigo_postal character varying(20),
    ubicacion_completa character varying(1000),
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_geocodificacion_2026_q3 OWNER TO admin;

--
-- Name: dat_gps_geocodificacion_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_geocodificacion_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    latitud numeric(18,6) NOT NULL,
    longitud numeric(18,6) NOT NULL,
    calle character varying(255),
    numero_exterior character varying(30),
    colonia character varying(200),
    ciudad character varying(200),
    estado character varying(200),
    pais character varying(100),
    codigo_postal character varying(20),
    ubicacion_completa character varying(1000),
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_geocodificacion_2026_q4 OWNER TO admin;

--
-- Name: dat_gps_io_raw; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_io_raw (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    io_id integer NOT NULL,
    io_value bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_gps_io_raw OWNER TO admin;

--
-- Name: dat_gps_io_raw_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_io_raw_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    io_id integer NOT NULL,
    io_value bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_io_raw_2026_q1 OWNER TO admin;

--
-- Name: dat_gps_io_raw_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_io_raw_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    io_id integer NOT NULL,
    io_value bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_io_raw_2026_q2 OWNER TO admin;

--
-- Name: dat_gps_io_raw_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_io_raw_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    io_id integer NOT NULL,
    io_value bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_io_raw_2026_q3 OWNER TO admin;

--
-- Name: dat_gps_io_raw_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_io_raw_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    io_id integer NOT NULL,
    io_value bytea NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_io_raw_2026_q4 OWNER TO admin;

--
-- Name: dat_gps_sensores; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_sensores (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    valor character varying(50) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_gps_sensores OWNER TO admin;

--
-- Name: dat_gps_sensores_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_sensores_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    valor character varying(50) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_sensores_2026_q1 OWNER TO admin;

--
-- Name: dat_gps_sensores_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_sensores_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    valor character varying(50) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_sensores_2026_q2 OWNER TO admin;

--
-- Name: dat_gps_sensores_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_sensores_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    valor character varying(50) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_sensores_2026_q3 OWNER TO admin;

--
-- Name: dat_gps_sensores_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_gps_sensores_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_sensor integer NOT NULL,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    valor character varying(50) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_gps_sensores_2026_q4 OWNER TO admin;

--
-- Name: dat_reporte_calles_visitadas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_reporte_calles_visitadas (
    id_reporte_calle bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_gps_entrada bigint NOT NULL,
    calle character varying(255) NOT NULL,
    ubicacion_completa character varying(1000),
    latitud_entrada numeric(18,6) NOT NULL,
    longitud_entrada numeric(18,6) NOT NULL,
    fechahora_utc_entrada timestamp(0) with time zone NOT NULL,
    fechahora_utc_salida timestamp(0) with time zone NOT NULL,
    tiempo_transcurrido_seg integer NOT NULL,
    distancia_recorrida_km numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,2) NOT NULL,
    velocidad_media_kmh numeric(18,2) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc_salida);


ALTER TABLE public.dat_reporte_calles_visitadas OWNER TO admin;

--
-- Name: dat_reporte_calles_visitadas_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_reporte_calles_visitadas_2026_q1 (
    id_reporte_calle bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_gps_entrada bigint NOT NULL,
    calle character varying(255) NOT NULL,
    ubicacion_completa character varying(1000),
    latitud_entrada numeric(18,6) NOT NULL,
    longitud_entrada numeric(18,6) NOT NULL,
    fechahora_utc_entrada timestamp(0) with time zone NOT NULL,
    fechahora_utc_salida timestamp(0) with time zone NOT NULL,
    tiempo_transcurrido_seg integer NOT NULL,
    distancia_recorrida_km numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,2) NOT NULL,
    velocidad_media_kmh numeric(18,2) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_reporte_calles_visitadas_2026_q1 OWNER TO admin;

--
-- Name: dat_reporte_calles_visitadas_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_reporte_calles_visitadas_2026_q2 (
    id_reporte_calle bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_gps_entrada bigint NOT NULL,
    calle character varying(255) NOT NULL,
    ubicacion_completa character varying(1000),
    latitud_entrada numeric(18,6) NOT NULL,
    longitud_entrada numeric(18,6) NOT NULL,
    fechahora_utc_entrada timestamp(0) with time zone NOT NULL,
    fechahora_utc_salida timestamp(0) with time zone NOT NULL,
    tiempo_transcurrido_seg integer NOT NULL,
    distancia_recorrida_km numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,2) NOT NULL,
    velocidad_media_kmh numeric(18,2) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_reporte_calles_visitadas_2026_q2 OWNER TO admin;

--
-- Name: dat_reporte_calles_visitadas_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_reporte_calles_visitadas_2026_q3 (
    id_reporte_calle bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_gps_entrada bigint NOT NULL,
    calle character varying(255) NOT NULL,
    ubicacion_completa character varying(1000),
    latitud_entrada numeric(18,6) NOT NULL,
    longitud_entrada numeric(18,6) NOT NULL,
    fechahora_utc_entrada timestamp(0) with time zone NOT NULL,
    fechahora_utc_salida timestamp(0) with time zone NOT NULL,
    tiempo_transcurrido_seg integer NOT NULL,
    distancia_recorrida_km numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,2) NOT NULL,
    velocidad_media_kmh numeric(18,2) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_reporte_calles_visitadas_2026_q3 OWNER TO admin;

--
-- Name: dat_reporte_calles_visitadas_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_reporte_calles_visitadas_2026_q4 (
    id_reporte_calle bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_gps_entrada bigint NOT NULL,
    calle character varying(255) NOT NULL,
    ubicacion_completa character varying(1000),
    latitud_entrada numeric(18,6) NOT NULL,
    longitud_entrada numeric(18,6) NOT NULL,
    fechahora_utc_entrada timestamp(0) with time zone NOT NULL,
    fechahora_utc_salida timestamp(0) with time zone NOT NULL,
    tiempo_transcurrido_seg integer NOT NULL,
    distancia_recorrida_km numeric(18,3) NOT NULL,
    velocidad_maxima_kmh numeric(18,2) NOT NULL,
    velocidad_media_kmh numeric(18,2) NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc_salida AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc_salida AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_reporte_calles_visitadas_2026_q4 OWNER TO admin;

--
-- Name: dat_reporte_calles_visitadas_id_reporte_calle_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.dat_reporte_calles_visitadas ALTER COLUMN id_reporte_calle ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dat_reporte_calles_visitadas_id_reporte_calle_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dat_tcp; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_tcp (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    datos_ascii text,
    datos_binarios bytea,
    decodificacion text,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fechahora_utc);


ALTER TABLE public.dat_tcp OWNER TO admin;

--
-- Name: dat_tcp_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_tcp_2026_q1 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    datos_ascii text,
    datos_binarios bytea,
    decodificacion text,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_tcp_2026_q1 OWNER TO admin;

--
-- Name: dat_tcp_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_tcp_2026_q2 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    datos_ascii text,
    datos_binarios bytea,
    decodificacion text,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_tcp_2026_q2 OWNER TO admin;

--
-- Name: dat_tcp_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_tcp_2026_q3 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    datos_ascii text,
    datos_binarios bytea,
    decodificacion text,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_tcp_2026_q3 OWNER TO admin;

--
-- Name: dat_tcp_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.dat_tcp_2026_q4 (
    id_gps bigint NOT NULL,
    id_equipo bigint NOT NULL,
    datos_ascii text,
    datos_binarios bytea,
    decodificacion text,
    fechahora_utc timestamp(0) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fechahora_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fechahora_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.dat_tcp_2026_q4 OWNER TO admin;

--
-- Name: log_auditoria_usuarios; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.log_auditoria_usuarios (
    id_log bigint NOT NULL,
    id_usuario integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_tipo_accion integer NOT NULL,
    id_tipo_objeto integer,
    id_objeto bigint,
    descripcion character varying(500) NOT NULL,
    detalles_json jsonb,
    ip_origen character varying(50),
    fecha_utc timestamp(3) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
)
PARTITION BY RANGE (fecha_utc);


ALTER TABLE public.log_auditoria_usuarios OWNER TO admin;

--
-- Name: log_auditoria_usuarios_2026_q1; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.log_auditoria_usuarios_2026_q1 (
    id_log bigint NOT NULL,
    id_usuario integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_tipo_accion integer NOT NULL,
    id_tipo_objeto integer,
    id_objeto bigint,
    descripcion character varying(500) NOT NULL,
    detalles_json jsonb,
    ip_origen character varying(50),
    fecha_utc timestamp(3) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.log_auditoria_usuarios_2026_q1 OWNER TO admin;

--
-- Name: log_auditoria_usuarios_2026_q2; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.log_auditoria_usuarios_2026_q2 (
    id_log bigint NOT NULL,
    id_usuario integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_tipo_accion integer NOT NULL,
    id_tipo_objeto integer,
    id_objeto bigint,
    descripcion character varying(500) NOT NULL,
    detalles_json jsonb,
    ip_origen character varying(50),
    fecha_utc timestamp(3) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.log_auditoria_usuarios_2026_q2 OWNER TO admin;

--
-- Name: log_auditoria_usuarios_2026_q3; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.log_auditoria_usuarios_2026_q3 (
    id_log bigint NOT NULL,
    id_usuario integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_tipo_accion integer NOT NULL,
    id_tipo_objeto integer,
    id_objeto bigint,
    descripcion character varying(500) NOT NULL,
    detalles_json jsonb,
    ip_origen character varying(50),
    fecha_utc timestamp(3) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.log_auditoria_usuarios_2026_q3 OWNER TO admin;

--
-- Name: log_auditoria_usuarios_2026_q4; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.log_auditoria_usuarios_2026_q4 (
    id_log bigint NOT NULL,
    id_usuario integer NOT NULL,
    id_cuenta integer NOT NULL,
    id_tipo_accion integer NOT NULL,
    id_tipo_objeto integer,
    id_objeto bigint,
    descripcion character varying(500) NOT NULL,
    detalles_json jsonb,
    ip_origen character varying(50),
    fecha_utc timestamp(3) with time zone NOT NULL,
    anio smallint GENERATED ALWAYS AS (EXTRACT(year FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    mes smallint GENERATED ALWAYS AS (EXTRACT(month FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    semana_anio smallint GENERATED ALWAYS AS (EXTRACT(week FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_semana smallint GENERATED ALWAYS AS (EXTRACT(isodow FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    dia_mes smallint GENERATED ALWAYS AS (EXTRACT(day FROM (fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    fecha date GENERATED ALWAYS AS (date((fecha_utc AT TIME ZONE 'UTC'::text))) STORED,
    turno smallint GENERATED ALWAYS AS (
CASE
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (6)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (13)::numeric)) THEN 1
    WHEN ((EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) >= (14)::numeric) AND (EXTRACT(hour FROM (fecha_utc AT TIME ZONE 'UTC'::text)) <= (21)::numeric)) THEN 2
    ELSE 3
END) STORED
);


ALTER TABLE public.log_auditoria_usuarios_2026_q4 OWNER TO admin;

--
-- Name: log_auditoria_usuarios_id_log_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

ALTER TABLE public.log_auditoria_usuarios ALTER COLUMN id_log ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.log_auditoria_usuarios_id_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dat_geoespacial_eventos_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_geoespacial_eventos_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_geoespacial_eventos_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_geoespacial_eventos_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_gps_ble_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_gps_ble_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_gps_ble_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_gps_ble_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_gps_equipos_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_gps_equipos_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_gps_equipos_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_gps_equipos_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_gps_geocodificacion_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_gps_geocodificacion_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_gps_geocodificacion_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_gps_geocodificacion_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_gps_io_raw_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_gps_io_raw_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_gps_io_raw_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_gps_io_raw_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_gps_sensores_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_gps_sensores_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_gps_sensores_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_gps_sensores_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_reporte_calles_visitadas_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_reporte_calles_visitadas_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_reporte_calles_visitadas_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_reporte_calles_visitadas_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_tcp_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp ATTACH PARTITION public.dat_tcp_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: dat_tcp_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp ATTACH PARTITION public.dat_tcp_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: dat_tcp_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp ATTACH PARTITION public.dat_tcp_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: dat_tcp_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp ATTACH PARTITION public.dat_tcp_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: log_auditoria_usuarios_2026_q1; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q1 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: log_auditoria_usuarios_2026_q2; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q2 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: log_auditoria_usuarios_2026_q3; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q3 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: log_auditoria_usuarios_2026_q4; Type: TABLE ATTACH; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q4 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: dat_geoespacial_eventos pk_dat_geoespacial_eventos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos
    ADD CONSTRAINT pk_dat_geoespacial_eventos PRIMARY KEY (fechahora_utc, id_gps, id_geoespacial, evento);


--
-- Name: dat_geoespacial_eventos_2026_q1 dat_geoespacial_eventos_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos_2026_q1
    ADD CONSTRAINT dat_geoespacial_eventos_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps, id_geoespacial, evento);


--
-- Name: dat_geoespacial_eventos_2026_q2 dat_geoespacial_eventos_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos_2026_q2
    ADD CONSTRAINT dat_geoespacial_eventos_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps, id_geoespacial, evento);


--
-- Name: dat_geoespacial_eventos_2026_q3 dat_geoespacial_eventos_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos_2026_q3
    ADD CONSTRAINT dat_geoespacial_eventos_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps, id_geoespacial, evento);


--
-- Name: dat_geoespacial_eventos_2026_q4 dat_geoespacial_eventos_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_geoespacial_eventos_2026_q4
    ADD CONSTRAINT dat_geoespacial_eventos_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps, id_geoespacial, evento);


--
-- Name: dat_gps_ble pk_dat_gps_ble; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble
    ADD CONSTRAINT pk_dat_gps_ble PRIMARY KEY (fechahora_utc, id_gps, mac_address);


--
-- Name: dat_gps_ble_2026_q1 dat_gps_ble_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble_2026_q1
    ADD CONSTRAINT dat_gps_ble_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps, mac_address);


--
-- Name: dat_gps_ble_2026_q2 dat_gps_ble_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble_2026_q2
    ADD CONSTRAINT dat_gps_ble_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps, mac_address);


--
-- Name: dat_gps_ble_2026_q3 dat_gps_ble_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble_2026_q3
    ADD CONSTRAINT dat_gps_ble_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps, mac_address);


--
-- Name: dat_gps_ble_2026_q4 dat_gps_ble_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_ble_2026_q4
    ADD CONSTRAINT dat_gps_ble_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps, mac_address);


--
-- Name: dat_gps_equipos pk_dat_gps_equipos; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos
    ADD CONSTRAINT pk_dat_gps_equipos PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_equipos_2026_q1 dat_gps_equipos_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos_2026_q1
    ADD CONSTRAINT dat_gps_equipos_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_equipos_2026_q2 dat_gps_equipos_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos_2026_q2
    ADD CONSTRAINT dat_gps_equipos_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_equipos_2026_q3 dat_gps_equipos_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos_2026_q3
    ADD CONSTRAINT dat_gps_equipos_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_equipos_2026_q4 dat_gps_equipos_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_equipos_2026_q4
    ADD CONSTRAINT dat_gps_equipos_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_geocodificacion pk_dat_gps_geocodificacion; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion
    ADD CONSTRAINT pk_dat_gps_geocodificacion PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_geocodificacion_2026_q1 dat_gps_geocodificacion_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion_2026_q1
    ADD CONSTRAINT dat_gps_geocodificacion_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_geocodificacion_2026_q2 dat_gps_geocodificacion_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion_2026_q2
    ADD CONSTRAINT dat_gps_geocodificacion_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_geocodificacion_2026_q3 dat_gps_geocodificacion_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion_2026_q3
    ADD CONSTRAINT dat_gps_geocodificacion_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_geocodificacion_2026_q4 dat_gps_geocodificacion_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_geocodificacion_2026_q4
    ADD CONSTRAINT dat_gps_geocodificacion_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_gps_io_raw pk_dat_gps_io_raw; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw
    ADD CONSTRAINT pk_dat_gps_io_raw PRIMARY KEY (fechahora_utc, id_gps, io_id);


--
-- Name: dat_gps_io_raw_2026_q1 dat_gps_io_raw_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw_2026_q1
    ADD CONSTRAINT dat_gps_io_raw_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps, io_id);


--
-- Name: dat_gps_io_raw_2026_q2 dat_gps_io_raw_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw_2026_q2
    ADD CONSTRAINT dat_gps_io_raw_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps, io_id);


--
-- Name: dat_gps_io_raw_2026_q3 dat_gps_io_raw_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw_2026_q3
    ADD CONSTRAINT dat_gps_io_raw_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps, io_id);


--
-- Name: dat_gps_io_raw_2026_q4 dat_gps_io_raw_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_io_raw_2026_q4
    ADD CONSTRAINT dat_gps_io_raw_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps, io_id);


--
-- Name: dat_gps_sensores pk_dat_gps_sensores; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores
    ADD CONSTRAINT pk_dat_gps_sensores PRIMARY KEY (fechahora_utc, id_gps, id_sensor);


--
-- Name: dat_gps_sensores_2026_q1 dat_gps_sensores_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores_2026_q1
    ADD CONSTRAINT dat_gps_sensores_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps, id_sensor);


--
-- Name: dat_gps_sensores_2026_q2 dat_gps_sensores_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores_2026_q2
    ADD CONSTRAINT dat_gps_sensores_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps, id_sensor);


--
-- Name: dat_gps_sensores_2026_q3 dat_gps_sensores_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores_2026_q3
    ADD CONSTRAINT dat_gps_sensores_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps, id_sensor);


--
-- Name: dat_gps_sensores_2026_q4 dat_gps_sensores_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_gps_sensores_2026_q4
    ADD CONSTRAINT dat_gps_sensores_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps, id_sensor);


--
-- Name: dat_reporte_calles_visitadas pk_dat_reporte_calles_visitadas; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas
    ADD CONSTRAINT pk_dat_reporte_calles_visitadas PRIMARY KEY (fechahora_utc_salida, id_reporte_calle);


--
-- Name: dat_reporte_calles_visitadas_2026_q1 dat_reporte_calles_visitadas_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas_2026_q1
    ADD CONSTRAINT dat_reporte_calles_visitadas_2026_q1_pkey PRIMARY KEY (fechahora_utc_salida, id_reporte_calle);


--
-- Name: dat_reporte_calles_visitadas_2026_q2 dat_reporte_calles_visitadas_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas_2026_q2
    ADD CONSTRAINT dat_reporte_calles_visitadas_2026_q2_pkey PRIMARY KEY (fechahora_utc_salida, id_reporte_calle);


--
-- Name: dat_reporte_calles_visitadas_2026_q3 dat_reporte_calles_visitadas_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas_2026_q3
    ADD CONSTRAINT dat_reporte_calles_visitadas_2026_q3_pkey PRIMARY KEY (fechahora_utc_salida, id_reporte_calle);


--
-- Name: dat_reporte_calles_visitadas_2026_q4 dat_reporte_calles_visitadas_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_reporte_calles_visitadas_2026_q4
    ADD CONSTRAINT dat_reporte_calles_visitadas_2026_q4_pkey PRIMARY KEY (fechahora_utc_salida, id_reporte_calle);


--
-- Name: dat_tcp pk_dat_tcp; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp
    ADD CONSTRAINT pk_dat_tcp PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_tcp_2026_q1 dat_tcp_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp_2026_q1
    ADD CONSTRAINT dat_tcp_2026_q1_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_tcp_2026_q2 dat_tcp_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp_2026_q2
    ADD CONSTRAINT dat_tcp_2026_q2_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_tcp_2026_q3 dat_tcp_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp_2026_q3
    ADD CONSTRAINT dat_tcp_2026_q3_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: dat_tcp_2026_q4 dat_tcp_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.dat_tcp_2026_q4
    ADD CONSTRAINT dat_tcp_2026_q4_pkey PRIMARY KEY (fechahora_utc, id_gps);


--
-- Name: log_auditoria_usuarios pk_log_auditoria_usuarios; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios
    ADD CONSTRAINT pk_log_auditoria_usuarios PRIMARY KEY (fecha_utc, id_log);


--
-- Name: log_auditoria_usuarios_2026_q1 log_auditoria_usuarios_2026_q1_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios_2026_q1
    ADD CONSTRAINT log_auditoria_usuarios_2026_q1_pkey PRIMARY KEY (fecha_utc, id_log);


--
-- Name: log_auditoria_usuarios_2026_q2 log_auditoria_usuarios_2026_q2_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios_2026_q2
    ADD CONSTRAINT log_auditoria_usuarios_2026_q2_pkey PRIMARY KEY (fecha_utc, id_log);


--
-- Name: log_auditoria_usuarios_2026_q3 log_auditoria_usuarios_2026_q3_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios_2026_q3
    ADD CONSTRAINT log_auditoria_usuarios_2026_q3_pkey PRIMARY KEY (fecha_utc, id_log);


--
-- Name: log_auditoria_usuarios_2026_q4 log_auditoria_usuarios_2026_q4_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.log_auditoria_usuarios_2026_q4
    ADD CONSTRAINT log_auditoria_usuarios_2026_q4_pkey PRIMARY KEY (fecha_utc, id_log);


--
-- Name: ix_dat_geoespacial_eventos_geocerca_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_geoespacial_eventos_geocerca_fecha ON ONLY public.dat_geoespacial_eventos USING btree (id_geoespacial, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx1; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx1 ON public.dat_geoespacial_eventos_2026_q2 USING btree (id_geoespacial, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx2; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx2 ON public.dat_geoespacial_eventos_2026_q3 USING btree (id_geoespacial, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx3; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx3 ON public.dat_geoespacial_eventos_2026_q4 USING btree (id_geoespacial, fechahora_utc);


--
-- Name: ix_dat_geoespacial_eventos_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_geoespacial_eventos_agrupacion ON ONLY public.dat_geoespacial_eventos USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_geoespacial_eventos_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_geoespacial_eventos_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_geoespacial_eventos_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_geoespacial_eventos_dia_semana ON ONLY public.dat_geoespacial_eventos USING btree (dia_semana);


--
-- Name: dat_geoespacial_eventos_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q1_dia_semana_idx ON public.dat_geoespacial_eventos_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_geoespacial_eventos_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_geoespacial_eventos_fecha ON ONLY public.dat_geoespacial_eventos USING btree (fecha);


--
-- Name: dat_geoespacial_eventos_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q1_fecha_idx ON public.dat_geoespacial_eventos_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_geoespacial_eventos_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_geoespacial_eventos_equipo_fecha ON ONLY public.dat_geoespacial_eventos USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_geoespacial_eventos_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_geoespacial_eventos_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_geoespacial_eventos_semana ON ONLY public.dat_geoespacial_eventos USING btree (semana_anio);


--
-- Name: dat_geoespacial_eventos_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q1_semana_anio_idx ON public.dat_geoespacial_eventos_2026_q1 USING btree (semana_anio);


--
-- Name: dat_geoespacial_eventos_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_geoespacial_eventos_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_geoespacial_eventos_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q2_dia_semana_idx ON public.dat_geoespacial_eventos_2026_q2 USING btree (dia_semana);


--
-- Name: dat_geoespacial_eventos_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q2_fecha_idx ON public.dat_geoespacial_eventos_2026_q2 USING btree (fecha);


--
-- Name: dat_geoespacial_eventos_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_geoespacial_eventos_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q2_semana_anio_idx ON public.dat_geoespacial_eventos_2026_q2 USING btree (semana_anio);


--
-- Name: dat_geoespacial_eventos_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_geoespacial_eventos_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_geoespacial_eventos_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q3_dia_semana_idx ON public.dat_geoespacial_eventos_2026_q3 USING btree (dia_semana);


--
-- Name: dat_geoespacial_eventos_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q3_fecha_idx ON public.dat_geoespacial_eventos_2026_q3 USING btree (fecha);


--
-- Name: dat_geoespacial_eventos_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_geoespacial_eventos_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q3_semana_anio_idx ON public.dat_geoespacial_eventos_2026_q3 USING btree (semana_anio);


--
-- Name: dat_geoespacial_eventos_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_geoespacial_eventos_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_geoespacial_eventos_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q4_dia_semana_idx ON public.dat_geoespacial_eventos_2026_q4 USING btree (dia_semana);


--
-- Name: dat_geoespacial_eventos_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q4_fecha_idx ON public.dat_geoespacial_eventos_2026_q4 USING btree (fecha);


--
-- Name: dat_geoespacial_eventos_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_geoespacial_eventos_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_geoespacial_eventos_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q4_semana_anio_idx ON public.dat_geoespacial_eventos_2026_q4 USING btree (semana_anio);


--
-- Name: dat_geoespacial_eventos_2026_q_id_geoespacial_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_geoespacial_eventos_2026_q_id_geoespacial_fechahora_utc_idx ON public.dat_geoespacial_eventos_2026_q1 USING btree (id_geoespacial, fechahora_utc);


--
-- Name: ix_dat_gps_ble_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_ble_agrupacion ON ONLY public.dat_gps_ble USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_ble_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_gps_ble_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_gps_ble_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_ble_dia_semana ON ONLY public.dat_gps_ble USING btree (dia_semana);


--
-- Name: dat_gps_ble_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q1_dia_semana_idx ON public.dat_gps_ble_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_gps_ble_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_ble_fecha ON ONLY public.dat_gps_ble USING btree (fecha);


--
-- Name: dat_gps_ble_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q1_fecha_idx ON public.dat_gps_ble_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_gps_ble_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_ble_equipo_fecha ON ONLY public.dat_gps_ble USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_ble_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_gps_ble_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_gps_ble_mac_address; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_ble_mac_address ON ONLY public.dat_gps_ble USING btree (mac_address);


--
-- Name: dat_gps_ble_2026_q1_mac_address_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q1_mac_address_idx ON public.dat_gps_ble_2026_q1 USING btree (mac_address);


--
-- Name: ix_dat_gps_ble_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_ble_semana ON ONLY public.dat_gps_ble USING btree (semana_anio);


--
-- Name: dat_gps_ble_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q1_semana_anio_idx ON public.dat_gps_ble_2026_q1 USING btree (semana_anio);


--
-- Name: dat_gps_ble_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_gps_ble_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_ble_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q2_dia_semana_idx ON public.dat_gps_ble_2026_q2 USING btree (dia_semana);


--
-- Name: dat_gps_ble_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q2_fecha_idx ON public.dat_gps_ble_2026_q2 USING btree (fecha);


--
-- Name: dat_gps_ble_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_gps_ble_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_ble_2026_q2_mac_address_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q2_mac_address_idx ON public.dat_gps_ble_2026_q2 USING btree (mac_address);


--
-- Name: dat_gps_ble_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q2_semana_anio_idx ON public.dat_gps_ble_2026_q2 USING btree (semana_anio);


--
-- Name: dat_gps_ble_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_gps_ble_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_ble_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q3_dia_semana_idx ON public.dat_gps_ble_2026_q3 USING btree (dia_semana);


--
-- Name: dat_gps_ble_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q3_fecha_idx ON public.dat_gps_ble_2026_q3 USING btree (fecha);


--
-- Name: dat_gps_ble_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_gps_ble_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_ble_2026_q3_mac_address_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q3_mac_address_idx ON public.dat_gps_ble_2026_q3 USING btree (mac_address);


--
-- Name: dat_gps_ble_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q3_semana_anio_idx ON public.dat_gps_ble_2026_q3 USING btree (semana_anio);


--
-- Name: dat_gps_ble_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_gps_ble_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_ble_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q4_dia_semana_idx ON public.dat_gps_ble_2026_q4 USING btree (dia_semana);


--
-- Name: dat_gps_ble_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q4_fecha_idx ON public.dat_gps_ble_2026_q4 USING btree (fecha);


--
-- Name: dat_gps_ble_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_gps_ble_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_ble_2026_q4_mac_address_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q4_mac_address_idx ON public.dat_gps_ble_2026_q4 USING btree (mac_address);


--
-- Name: dat_gps_ble_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_ble_2026_q4_semana_anio_idx ON public.dat_gps_ble_2026_q4 USING btree (semana_anio);


--
-- Name: ix_dat_gps_equipos_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_agrupacion ON ONLY public.dat_gps_equipos USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_equipos_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_gps_equipos_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_gps_equipos_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_dia_semana ON ONLY public.dat_gps_equipos USING btree (dia_semana);


--
-- Name: dat_gps_equipos_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_dia_semana_idx ON public.dat_gps_equipos_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_gps_equipos_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_fecha ON ONLY public.dat_gps_equipos USING btree (fecha);


--
-- Name: dat_gps_equipos_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_fecha_idx ON public.dat_gps_equipos_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_gps_equipos_fecha_recepcion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_fecha_recepcion ON ONLY public.dat_gps_equipos USING btree (fechahora_utc_recepcion);


--
-- Name: dat_gps_equipos_2026_q1_fechahora_utc_recepcion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_fechahora_utc_recepcion_idx ON public.dat_gps_equipos_2026_q1 USING btree (fechahora_utc_recepcion);


--
-- Name: six_dat_gps_equipos_geolocalizacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX six_dat_gps_equipos_geolocalizacion ON ONLY public.dat_gps_equipos USING gist (geolocalizacion);


--
-- Name: dat_gps_equipos_2026_q1_geolocalizacion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_geolocalizacion_idx ON public.dat_gps_equipos_2026_q1 USING gist (geolocalizacion);


--
-- Name: ix_dat_gps_equipos_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_equipo_fecha ON ONLY public.dat_gps_equipos USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_gps_equipos_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_gps_equipos_tipo_paquete; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_tipo_paquete ON ONLY public.dat_gps_equipos USING btree (id_equipo, fechahora_utc, tipo_paquete);


--
-- Name: dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_tipo_paquet_idx ON public.dat_gps_equipos_2026_q1 USING btree (id_equipo, fechahora_utc, tipo_paquete);


--
-- Name: ix_dat_gps_equipos_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_equipos_semana ON ONLY public.dat_gps_equipos USING btree (semana_anio);


--
-- Name: dat_gps_equipos_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q1_semana_anio_idx ON public.dat_gps_equipos_2026_q1 USING btree (semana_anio);


--
-- Name: dat_gps_equipos_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_gps_equipos_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_equipos_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_dia_semana_idx ON public.dat_gps_equipos_2026_q2 USING btree (dia_semana);


--
-- Name: dat_gps_equipos_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_fecha_idx ON public.dat_gps_equipos_2026_q2 USING btree (fecha);


--
-- Name: dat_gps_equipos_2026_q2_fechahora_utc_recepcion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_fechahora_utc_recepcion_idx ON public.dat_gps_equipos_2026_q2 USING btree (fechahora_utc_recepcion);


--
-- Name: dat_gps_equipos_2026_q2_geolocalizacion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_geolocalizacion_idx ON public.dat_gps_equipos_2026_q2 USING gist (geolocalizacion);


--
-- Name: dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_gps_equipos_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_tipo_paquet_idx ON public.dat_gps_equipos_2026_q2 USING btree (id_equipo, fechahora_utc, tipo_paquete);


--
-- Name: dat_gps_equipos_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q2_semana_anio_idx ON public.dat_gps_equipos_2026_q2 USING btree (semana_anio);


--
-- Name: dat_gps_equipos_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_gps_equipos_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_equipos_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_dia_semana_idx ON public.dat_gps_equipos_2026_q3 USING btree (dia_semana);


--
-- Name: dat_gps_equipos_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_fecha_idx ON public.dat_gps_equipos_2026_q3 USING btree (fecha);


--
-- Name: dat_gps_equipos_2026_q3_fechahora_utc_recepcion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_fechahora_utc_recepcion_idx ON public.dat_gps_equipos_2026_q3 USING btree (fechahora_utc_recepcion);


--
-- Name: dat_gps_equipos_2026_q3_geolocalizacion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_geolocalizacion_idx ON public.dat_gps_equipos_2026_q3 USING gist (geolocalizacion);


--
-- Name: dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_gps_equipos_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_tipo_paquet_idx ON public.dat_gps_equipos_2026_q3 USING btree (id_equipo, fechahora_utc, tipo_paquete);


--
-- Name: dat_gps_equipos_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q3_semana_anio_idx ON public.dat_gps_equipos_2026_q3 USING btree (semana_anio);


--
-- Name: dat_gps_equipos_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_gps_equipos_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_equipos_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_dia_semana_idx ON public.dat_gps_equipos_2026_q4 USING btree (dia_semana);


--
-- Name: dat_gps_equipos_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_fecha_idx ON public.dat_gps_equipos_2026_q4 USING btree (fecha);


--
-- Name: dat_gps_equipos_2026_q4_fechahora_utc_recepcion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_fechahora_utc_recepcion_idx ON public.dat_gps_equipos_2026_q4 USING btree (fechahora_utc_recepcion);


--
-- Name: dat_gps_equipos_2026_q4_geolocalizacion_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_geolocalizacion_idx ON public.dat_gps_equipos_2026_q4 USING gist (geolocalizacion);


--
-- Name: dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_gps_equipos_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_tipo_paquet_idx ON public.dat_gps_equipos_2026_q4 USING btree (id_equipo, fechahora_utc, tipo_paquete);


--
-- Name: dat_gps_equipos_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_equipos_2026_q4_semana_anio_idx ON public.dat_gps_equipos_2026_q4 USING btree (semana_anio);


--
-- Name: ix_dat_gps_geocodificacion_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_geocodificacion_agrupacion ON ONLY public.dat_gps_geocodificacion USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_geocodificacion_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_gps_geocodificacion_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_gps_geocodificacion_calle_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_geocodificacion_calle_fecha ON ONLY public.dat_gps_geocodificacion USING btree (calle, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q1_calle_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q1_calle_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q1 USING btree (calle, fechahora_utc);


--
-- Name: ix_dat_gps_geocodificacion_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_geocodificacion_dia_semana ON ONLY public.dat_gps_geocodificacion USING btree (dia_semana);


--
-- Name: dat_gps_geocodificacion_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q1_dia_semana_idx ON public.dat_gps_geocodificacion_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_gps_geocodificacion_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_geocodificacion_fecha ON ONLY public.dat_gps_geocodificacion USING btree (fecha);


--
-- Name: dat_gps_geocodificacion_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q1_fecha_idx ON public.dat_gps_geocodificacion_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_gps_geocodificacion_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_geocodificacion_equipo_fecha ON ONLY public.dat_gps_geocodificacion USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_gps_geocodificacion_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_geocodificacion_semana ON ONLY public.dat_gps_geocodificacion USING btree (semana_anio);


--
-- Name: dat_gps_geocodificacion_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q1_semana_anio_idx ON public.dat_gps_geocodificacion_2026_q1 USING btree (semana_anio);


--
-- Name: dat_gps_geocodificacion_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_gps_geocodificacion_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_geocodificacion_2026_q2_calle_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q2_calle_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q2 USING btree (calle, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q2_dia_semana_idx ON public.dat_gps_geocodificacion_2026_q2 USING btree (dia_semana);


--
-- Name: dat_gps_geocodificacion_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q2_fecha_idx ON public.dat_gps_geocodificacion_2026_q2 USING btree (fecha);


--
-- Name: dat_gps_geocodificacion_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q2_semana_anio_idx ON public.dat_gps_geocodificacion_2026_q2 USING btree (semana_anio);


--
-- Name: dat_gps_geocodificacion_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_gps_geocodificacion_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_geocodificacion_2026_q3_calle_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q3_calle_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q3 USING btree (calle, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q3_dia_semana_idx ON public.dat_gps_geocodificacion_2026_q3 USING btree (dia_semana);


--
-- Name: dat_gps_geocodificacion_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q3_fecha_idx ON public.dat_gps_geocodificacion_2026_q3 USING btree (fecha);


--
-- Name: dat_gps_geocodificacion_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q3_semana_anio_idx ON public.dat_gps_geocodificacion_2026_q3 USING btree (semana_anio);


--
-- Name: dat_gps_geocodificacion_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_gps_geocodificacion_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_geocodificacion_2026_q4_calle_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q4_calle_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q4 USING btree (calle, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q4_dia_semana_idx ON public.dat_gps_geocodificacion_2026_q4 USING btree (dia_semana);


--
-- Name: dat_gps_geocodificacion_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q4_fecha_idx ON public.dat_gps_geocodificacion_2026_q4 USING btree (fecha);


--
-- Name: dat_gps_geocodificacion_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_gps_geocodificacion_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_geocodificacion_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_geocodificacion_2026_q4_semana_anio_idx ON public.dat_gps_geocodificacion_2026_q4 USING btree (semana_anio);


--
-- Name: ix_dat_gps_io_raw_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_io_raw_agrupacion ON ONLY public.dat_gps_io_raw USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_io_raw_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_gps_io_raw_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_gps_io_raw_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_io_raw_dia_semana ON ONLY public.dat_gps_io_raw USING btree (dia_semana);


--
-- Name: dat_gps_io_raw_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q1_dia_semana_idx ON public.dat_gps_io_raw_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_gps_io_raw_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_io_raw_fecha ON ONLY public.dat_gps_io_raw USING btree (fecha);


--
-- Name: dat_gps_io_raw_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q1_fecha_idx ON public.dat_gps_io_raw_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_gps_io_raw_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_io_raw_equipo_fecha ON ONLY public.dat_gps_io_raw USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_io_raw_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_gps_io_raw_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_gps_io_raw_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_io_raw_semana ON ONLY public.dat_gps_io_raw USING btree (semana_anio);


--
-- Name: dat_gps_io_raw_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q1_semana_anio_idx ON public.dat_gps_io_raw_2026_q1 USING btree (semana_anio);


--
-- Name: dat_gps_io_raw_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_gps_io_raw_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_io_raw_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q2_dia_semana_idx ON public.dat_gps_io_raw_2026_q2 USING btree (dia_semana);


--
-- Name: dat_gps_io_raw_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q2_fecha_idx ON public.dat_gps_io_raw_2026_q2 USING btree (fecha);


--
-- Name: dat_gps_io_raw_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_gps_io_raw_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_io_raw_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q2_semana_anio_idx ON public.dat_gps_io_raw_2026_q2 USING btree (semana_anio);


--
-- Name: dat_gps_io_raw_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_gps_io_raw_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_io_raw_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q3_dia_semana_idx ON public.dat_gps_io_raw_2026_q3 USING btree (dia_semana);


--
-- Name: dat_gps_io_raw_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q3_fecha_idx ON public.dat_gps_io_raw_2026_q3 USING btree (fecha);


--
-- Name: dat_gps_io_raw_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_gps_io_raw_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_io_raw_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q3_semana_anio_idx ON public.dat_gps_io_raw_2026_q3 USING btree (semana_anio);


--
-- Name: dat_gps_io_raw_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_gps_io_raw_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_io_raw_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q4_dia_semana_idx ON public.dat_gps_io_raw_2026_q4 USING btree (dia_semana);


--
-- Name: dat_gps_io_raw_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q4_fecha_idx ON public.dat_gps_io_raw_2026_q4 USING btree (fecha);


--
-- Name: dat_gps_io_raw_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_gps_io_raw_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_io_raw_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_io_raw_2026_q4_semana_anio_idx ON public.dat_gps_io_raw_2026_q4 USING btree (semana_anio);


--
-- Name: ix_dat_gps_sensores_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_sensores_agrupacion ON ONLY public.dat_gps_sensores USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_sensores_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_gps_sensores_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_gps_sensores_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_sensores_dia_semana ON ONLY public.dat_gps_sensores USING btree (dia_semana);


--
-- Name: dat_gps_sensores_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q1_dia_semana_idx ON public.dat_gps_sensores_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_gps_sensores_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_sensores_fecha ON ONLY public.dat_gps_sensores USING btree (fecha);


--
-- Name: dat_gps_sensores_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q1_fecha_idx ON public.dat_gps_sensores_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_gps_sensores_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_sensores_equipo_fecha ON ONLY public.dat_gps_sensores USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_gps_sensores_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_gps_sensores_sensor_tiempo; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_sensores_sensor_tiempo ON ONLY public.dat_gps_sensores USING btree (id_sensor, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q1_id_sensor_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q1_id_sensor_fechahora_utc_idx ON public.dat_gps_sensores_2026_q1 USING btree (id_sensor, fechahora_utc);


--
-- Name: ix_dat_gps_sensores_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_gps_sensores_semana ON ONLY public.dat_gps_sensores USING btree (semana_anio);


--
-- Name: dat_gps_sensores_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q1_semana_anio_idx ON public.dat_gps_sensores_2026_q1 USING btree (semana_anio);


--
-- Name: dat_gps_sensores_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_gps_sensores_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_sensores_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q2_dia_semana_idx ON public.dat_gps_sensores_2026_q2 USING btree (dia_semana);


--
-- Name: dat_gps_sensores_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q2_fecha_idx ON public.dat_gps_sensores_2026_q2 USING btree (fecha);


--
-- Name: dat_gps_sensores_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_gps_sensores_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q2_id_sensor_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q2_id_sensor_fechahora_utc_idx ON public.dat_gps_sensores_2026_q2 USING btree (id_sensor, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q2_semana_anio_idx ON public.dat_gps_sensores_2026_q2 USING btree (semana_anio);


--
-- Name: dat_gps_sensores_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_gps_sensores_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_sensores_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q3_dia_semana_idx ON public.dat_gps_sensores_2026_q3 USING btree (dia_semana);


--
-- Name: dat_gps_sensores_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q3_fecha_idx ON public.dat_gps_sensores_2026_q3 USING btree (fecha);


--
-- Name: dat_gps_sensores_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_gps_sensores_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q3_id_sensor_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q3_id_sensor_fechahora_utc_idx ON public.dat_gps_sensores_2026_q3 USING btree (id_sensor, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q3_semana_anio_idx ON public.dat_gps_sensores_2026_q3 USING btree (semana_anio);


--
-- Name: dat_gps_sensores_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_gps_sensores_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_gps_sensores_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q4_dia_semana_idx ON public.dat_gps_sensores_2026_q4 USING btree (dia_semana);


--
-- Name: dat_gps_sensores_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q4_fecha_idx ON public.dat_gps_sensores_2026_q4 USING btree (fecha);


--
-- Name: dat_gps_sensores_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_gps_sensores_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q4_id_sensor_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q4_id_sensor_fechahora_utc_idx ON public.dat_gps_sensores_2026_q4 USING btree (id_sensor, fechahora_utc);


--
-- Name: dat_gps_sensores_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_gps_sensores_2026_q4_semana_anio_idx ON public.dat_gps_sensores_2026_q4 USING btree (semana_anio);


--
-- Name: ix_dat_reporte_calles_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_reporte_calles_agrupacion ON ONLY public.dat_reporte_calles_visitadas USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_reporte_calles_visitadas_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_reporte_calles_visitadas_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_reporte_calles_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_reporte_calles_dia_semana ON ONLY public.dat_reporte_calles_visitadas USING btree (dia_semana);


--
-- Name: dat_reporte_calles_visitadas_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q1_dia_semana_idx ON public.dat_reporte_calles_visitadas_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_reporte_calles_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_reporte_calles_fecha ON ONLY public.dat_reporte_calles_visitadas USING btree (fecha);


--
-- Name: dat_reporte_calles_visitadas_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q1_fecha_idx ON public.dat_reporte_calles_visitadas_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_reporte_calles_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_reporte_calles_semana ON ONLY public.dat_reporte_calles_visitadas USING btree (semana_anio);


--
-- Name: dat_reporte_calles_visitadas_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q1_semana_anio_idx ON public.dat_reporte_calles_visitadas_2026_q1 USING btree (semana_anio);


--
-- Name: dat_reporte_calles_visitadas_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_reporte_calles_visitadas_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_reporte_calles_visitadas_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q2_dia_semana_idx ON public.dat_reporte_calles_visitadas_2026_q2 USING btree (dia_semana);


--
-- Name: dat_reporte_calles_visitadas_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q2_fecha_idx ON public.dat_reporte_calles_visitadas_2026_q2 USING btree (fecha);


--
-- Name: dat_reporte_calles_visitadas_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q2_semana_anio_idx ON public.dat_reporte_calles_visitadas_2026_q2 USING btree (semana_anio);


--
-- Name: dat_reporte_calles_visitadas_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_reporte_calles_visitadas_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_reporte_calles_visitadas_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q3_dia_semana_idx ON public.dat_reporte_calles_visitadas_2026_q3 USING btree (dia_semana);


--
-- Name: dat_reporte_calles_visitadas_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q3_fecha_idx ON public.dat_reporte_calles_visitadas_2026_q3 USING btree (fecha);


--
-- Name: dat_reporte_calles_visitadas_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q3_semana_anio_idx ON public.dat_reporte_calles_visitadas_2026_q3 USING btree (semana_anio);


--
-- Name: dat_reporte_calles_visitadas_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_reporte_calles_visitadas_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_reporte_calles_visitadas_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q4_dia_semana_idx ON public.dat_reporte_calles_visitadas_2026_q4 USING btree (dia_semana);


--
-- Name: dat_reporte_calles_visitadas_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q4_fecha_idx ON public.dat_reporte_calles_visitadas_2026_q4 USING btree (fecha);


--
-- Name: dat_reporte_calles_visitadas_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_2026_q4_semana_anio_idx ON public.dat_reporte_calles_visitadas_2026_q4 USING btree (semana_anio);


--
-- Name: ix_dat_reporte_calles_calle_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_reporte_calles_calle_fecha ON ONLY public.dat_reporte_calles_visitadas USING btree (calle, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas_202_calle_fechahora_utc_salida_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_202_calle_fechahora_utc_salida_idx ON public.dat_reporte_calles_visitadas_2026_q1 USING btree (calle, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx1; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx1 ON public.dat_reporte_calles_visitadas_2026_q2 USING btree (calle, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx2; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx2 ON public.dat_reporte_calles_visitadas_2026_q3 USING btree (calle, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx3; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx3 ON public.dat_reporte_calles_visitadas_2026_q4 USING btree (calle, fechahora_utc_salida);


--
-- Name: ix_dat_reporte_calles_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_reporte_calles_equipo_fecha ON ONLY public.dat_reporte_calles_visitadas USING btree (id_equipo, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx1; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx1 ON public.dat_reporte_calles_visitadas_2026_q2 USING btree (id_equipo, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx2; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx2 ON public.dat_reporte_calles_visitadas_2026_q3 USING btree (id_equipo, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx3; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx3 ON public.dat_reporte_calles_visitadas_2026_q4 USING btree (id_equipo, fechahora_utc_salida);


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_salid_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_reporte_calles_visitadas__id_equipo_fechahora_utc_salid_idx ON public.dat_reporte_calles_visitadas_2026_q1 USING btree (id_equipo, fechahora_utc_salida);


--
-- Name: ix_dat_tcp_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_tcp_agrupacion ON ONLY public.dat_tcp USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_tcp_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q1_anio_mes_dia_mes_turno_idx ON public.dat_tcp_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_dat_tcp_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_tcp_dia_semana ON ONLY public.dat_tcp USING btree (dia_semana);


--
-- Name: dat_tcp_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q1_dia_semana_idx ON public.dat_tcp_2026_q1 USING btree (dia_semana);


--
-- Name: ix_dat_tcp_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_tcp_fecha ON ONLY public.dat_tcp USING btree (fecha);


--
-- Name: dat_tcp_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q1_fecha_idx ON public.dat_tcp_2026_q1 USING btree (fecha);


--
-- Name: ix_dat_tcp_equipo_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_tcp_equipo_fecha ON ONLY public.dat_tcp USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_tcp_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q1_id_equipo_fechahora_utc_idx ON public.dat_tcp_2026_q1 USING btree (id_equipo, fechahora_utc);


--
-- Name: ix_dat_tcp_id_gps; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_tcp_id_gps ON ONLY public.dat_tcp USING btree (id_gps);


--
-- Name: dat_tcp_2026_q1_id_gps_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q1_id_gps_idx ON public.dat_tcp_2026_q1 USING btree (id_gps);


--
-- Name: ix_dat_tcp_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_dat_tcp_semana ON ONLY public.dat_tcp USING btree (semana_anio);


--
-- Name: dat_tcp_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q1_semana_anio_idx ON public.dat_tcp_2026_q1 USING btree (semana_anio);


--
-- Name: dat_tcp_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q2_anio_mes_dia_mes_turno_idx ON public.dat_tcp_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_tcp_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q2_dia_semana_idx ON public.dat_tcp_2026_q2 USING btree (dia_semana);


--
-- Name: dat_tcp_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q2_fecha_idx ON public.dat_tcp_2026_q2 USING btree (fecha);


--
-- Name: dat_tcp_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q2_id_equipo_fechahora_utc_idx ON public.dat_tcp_2026_q2 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_tcp_2026_q2_id_gps_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q2_id_gps_idx ON public.dat_tcp_2026_q2 USING btree (id_gps);


--
-- Name: dat_tcp_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q2_semana_anio_idx ON public.dat_tcp_2026_q2 USING btree (semana_anio);


--
-- Name: dat_tcp_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q3_anio_mes_dia_mes_turno_idx ON public.dat_tcp_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_tcp_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q3_dia_semana_idx ON public.dat_tcp_2026_q3 USING btree (dia_semana);


--
-- Name: dat_tcp_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q3_fecha_idx ON public.dat_tcp_2026_q3 USING btree (fecha);


--
-- Name: dat_tcp_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q3_id_equipo_fechahora_utc_idx ON public.dat_tcp_2026_q3 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_tcp_2026_q3_id_gps_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q3_id_gps_idx ON public.dat_tcp_2026_q3 USING btree (id_gps);


--
-- Name: dat_tcp_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q3_semana_anio_idx ON public.dat_tcp_2026_q3 USING btree (semana_anio);


--
-- Name: dat_tcp_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q4_anio_mes_dia_mes_turno_idx ON public.dat_tcp_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: dat_tcp_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q4_dia_semana_idx ON public.dat_tcp_2026_q4 USING btree (dia_semana);


--
-- Name: dat_tcp_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q4_fecha_idx ON public.dat_tcp_2026_q4 USING btree (fecha);


--
-- Name: dat_tcp_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q4_id_equipo_fechahora_utc_idx ON public.dat_tcp_2026_q4 USING btree (id_equipo, fechahora_utc);


--
-- Name: dat_tcp_2026_q4_id_gps_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q4_id_gps_idx ON public.dat_tcp_2026_q4 USING btree (id_gps);


--
-- Name: dat_tcp_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX dat_tcp_2026_q4_semana_anio_idx ON public.dat_tcp_2026_q4 USING btree (semana_anio);


--
-- Name: ix_log_auditoria_usuarios_agrupacion; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_auditoria_usuarios_agrupacion ON ONLY public.log_auditoria_usuarios USING btree (anio, mes, dia_mes, turno);


--
-- Name: ix_log_auditoria_usuarios_dia_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_auditoria_usuarios_dia_semana ON ONLY public.log_auditoria_usuarios USING btree (dia_semana);


--
-- Name: ix_log_auditoria_usuarios_fecha; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_auditoria_usuarios_fecha ON ONLY public.log_auditoria_usuarios USING btree (fecha);


--
-- Name: ix_log_auditoria_usuarios_objeto; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_auditoria_usuarios_objeto ON ONLY public.log_auditoria_usuarios USING btree (id_tipo_objeto, id_objeto, fecha_utc);


--
-- Name: ix_log_auditoria_usuarios_semana; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_auditoria_usuarios_semana ON ONLY public.log_auditoria_usuarios USING btree (semana_anio);


--
-- Name: ix_log_auditoria_usuarios_usuario; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX ix_log_auditoria_usuarios_usuario ON ONLY public.log_auditoria_usuarios USING btree (id_usuario, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q1_anio_mes_dia_mes_turno_idx ON public.log_auditoria_usuarios_2026_q1 USING btree (anio, mes, dia_mes, turno);


--
-- Name: log_auditoria_usuarios_2026_q1_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q1_dia_semana_idx ON public.log_auditoria_usuarios_2026_q1 USING btree (dia_semana);


--
-- Name: log_auditoria_usuarios_2026_q1_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q1_fecha_idx ON public.log_auditoria_usuarios_2026_q1 USING btree (fecha);


--
-- Name: log_auditoria_usuarios_2026_q1_id_usuario_fecha_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q1_id_usuario_fecha_utc_idx ON public.log_auditoria_usuarios_2026_q1 USING btree (id_usuario, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q1_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q1_semana_anio_idx ON public.log_auditoria_usuarios_2026_q1 USING btree (semana_anio);


--
-- Name: log_auditoria_usuarios_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q2_anio_mes_dia_mes_turno_idx ON public.log_auditoria_usuarios_2026_q2 USING btree (anio, mes, dia_mes, turno);


--
-- Name: log_auditoria_usuarios_2026_q2_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q2_dia_semana_idx ON public.log_auditoria_usuarios_2026_q2 USING btree (dia_semana);


--
-- Name: log_auditoria_usuarios_2026_q2_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q2_fecha_idx ON public.log_auditoria_usuarios_2026_q2 USING btree (fecha);


--
-- Name: log_auditoria_usuarios_2026_q2_id_usuario_fecha_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q2_id_usuario_fecha_utc_idx ON public.log_auditoria_usuarios_2026_q2 USING btree (id_usuario, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q2_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q2_semana_anio_idx ON public.log_auditoria_usuarios_2026_q2 USING btree (semana_anio);


--
-- Name: log_auditoria_usuarios_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q3_anio_mes_dia_mes_turno_idx ON public.log_auditoria_usuarios_2026_q3 USING btree (anio, mes, dia_mes, turno);


--
-- Name: log_auditoria_usuarios_2026_q3_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q3_dia_semana_idx ON public.log_auditoria_usuarios_2026_q3 USING btree (dia_semana);


--
-- Name: log_auditoria_usuarios_2026_q3_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q3_fecha_idx ON public.log_auditoria_usuarios_2026_q3 USING btree (fecha);


--
-- Name: log_auditoria_usuarios_2026_q3_id_usuario_fecha_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q3_id_usuario_fecha_utc_idx ON public.log_auditoria_usuarios_2026_q3 USING btree (id_usuario, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q3_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q3_semana_anio_idx ON public.log_auditoria_usuarios_2026_q3 USING btree (semana_anio);


--
-- Name: log_auditoria_usuarios_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q4_anio_mes_dia_mes_turno_idx ON public.log_auditoria_usuarios_2026_q4 USING btree (anio, mes, dia_mes, turno);


--
-- Name: log_auditoria_usuarios_2026_q4_dia_semana_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q4_dia_semana_idx ON public.log_auditoria_usuarios_2026_q4 USING btree (dia_semana);


--
-- Name: log_auditoria_usuarios_2026_q4_fecha_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q4_fecha_idx ON public.log_auditoria_usuarios_2026_q4 USING btree (fecha);


--
-- Name: log_auditoria_usuarios_2026_q4_id_usuario_fecha_utc_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q4_id_usuario_fecha_utc_idx ON public.log_auditoria_usuarios_2026_q4 USING btree (id_usuario, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q4_semana_anio_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q4_semana_anio_idx ON public.log_auditoria_usuarios_2026_q4 USING btree (semana_anio);


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx1; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx1 ON public.log_auditoria_usuarios_2026_q2 USING btree (id_tipo_objeto, id_objeto, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx2; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx2 ON public.log_auditoria_usuarios_2026_q3 USING btree (id_tipo_objeto, id_objeto, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx3; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx3 ON public.log_auditoria_usuarios_2026_q4 USING btree (id_tipo_objeto, id_objeto, fecha_utc);


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fech_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fech_idx ON public.log_auditoria_usuarios_2026_q1 USING btree (id_tipo_objeto, id_objeto, fecha_utc);


--
-- Name: dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx1; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_geocerca_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx1;


--
-- Name: dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx2; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_geocerca_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx2;


--
-- Name: dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx3; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_geocerca_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026__id_geoespacial_fechahora_utc_idx3;


--
-- Name: dat_geoespacial_eventos_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_agrupacion ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_geoespacial_eventos_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_dia_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1_dia_semana_idx;


--
-- Name: dat_geoespacial_eventos_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1_fecha_idx;


--
-- Name: dat_geoespacial_eventos_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_equipo_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_geoespacial_eventos_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1_pkey;


--
-- Name: dat_geoespacial_eventos_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q1_semana_anio_idx;


--
-- Name: dat_geoespacial_eventos_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_agrupacion ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_geoespacial_eventos_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_dia_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2_dia_semana_idx;


--
-- Name: dat_geoespacial_eventos_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2_fecha_idx;


--
-- Name: dat_geoespacial_eventos_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_equipo_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_geoespacial_eventos_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2_pkey;


--
-- Name: dat_geoespacial_eventos_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q2_semana_anio_idx;


--
-- Name: dat_geoespacial_eventos_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_agrupacion ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_geoespacial_eventos_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_dia_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3_dia_semana_idx;


--
-- Name: dat_geoespacial_eventos_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3_fecha_idx;


--
-- Name: dat_geoespacial_eventos_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_equipo_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_geoespacial_eventos_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3_pkey;


--
-- Name: dat_geoespacial_eventos_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q3_semana_anio_idx;


--
-- Name: dat_geoespacial_eventos_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_agrupacion ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_geoespacial_eventos_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_dia_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4_dia_semana_idx;


--
-- Name: dat_geoespacial_eventos_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4_fecha_idx;


--
-- Name: dat_geoespacial_eventos_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_equipo_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_geoespacial_eventos_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_geoespacial_eventos ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4_pkey;


--
-- Name: dat_geoespacial_eventos_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_semana ATTACH PARTITION public.dat_geoespacial_eventos_2026_q4_semana_anio_idx;


--
-- Name: dat_geoespacial_eventos_2026_q_id_geoespacial_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_geoespacial_eventos_geocerca_fecha ATTACH PARTITION public.dat_geoespacial_eventos_2026_q_id_geoespacial_fechahora_utc_idx;


--
-- Name: dat_gps_ble_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_agrupacion ATTACH PARTITION public.dat_gps_ble_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_ble_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_dia_semana ATTACH PARTITION public.dat_gps_ble_2026_q1_dia_semana_idx;


--
-- Name: dat_gps_ble_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_fecha ATTACH PARTITION public.dat_gps_ble_2026_q1_fecha_idx;


--
-- Name: dat_gps_ble_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_equipo_fecha ATTACH PARTITION public.dat_gps_ble_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_ble_2026_q1_mac_address_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_mac_address ATTACH PARTITION public.dat_gps_ble_2026_q1_mac_address_idx;


--
-- Name: dat_gps_ble_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q1_pkey;


--
-- Name: dat_gps_ble_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_semana ATTACH PARTITION public.dat_gps_ble_2026_q1_semana_anio_idx;


--
-- Name: dat_gps_ble_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_agrupacion ATTACH PARTITION public.dat_gps_ble_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_ble_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_dia_semana ATTACH PARTITION public.dat_gps_ble_2026_q2_dia_semana_idx;


--
-- Name: dat_gps_ble_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_fecha ATTACH PARTITION public.dat_gps_ble_2026_q2_fecha_idx;


--
-- Name: dat_gps_ble_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_equipo_fecha ATTACH PARTITION public.dat_gps_ble_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_ble_2026_q2_mac_address_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_mac_address ATTACH PARTITION public.dat_gps_ble_2026_q2_mac_address_idx;


--
-- Name: dat_gps_ble_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q2_pkey;


--
-- Name: dat_gps_ble_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_semana ATTACH PARTITION public.dat_gps_ble_2026_q2_semana_anio_idx;


--
-- Name: dat_gps_ble_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_agrupacion ATTACH PARTITION public.dat_gps_ble_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_ble_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_dia_semana ATTACH PARTITION public.dat_gps_ble_2026_q3_dia_semana_idx;


--
-- Name: dat_gps_ble_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_fecha ATTACH PARTITION public.dat_gps_ble_2026_q3_fecha_idx;


--
-- Name: dat_gps_ble_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_equipo_fecha ATTACH PARTITION public.dat_gps_ble_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_ble_2026_q3_mac_address_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_mac_address ATTACH PARTITION public.dat_gps_ble_2026_q3_mac_address_idx;


--
-- Name: dat_gps_ble_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q3_pkey;


--
-- Name: dat_gps_ble_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_semana ATTACH PARTITION public.dat_gps_ble_2026_q3_semana_anio_idx;


--
-- Name: dat_gps_ble_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_agrupacion ATTACH PARTITION public.dat_gps_ble_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_ble_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_dia_semana ATTACH PARTITION public.dat_gps_ble_2026_q4_dia_semana_idx;


--
-- Name: dat_gps_ble_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_fecha ATTACH PARTITION public.dat_gps_ble_2026_q4_fecha_idx;


--
-- Name: dat_gps_ble_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_equipo_fecha ATTACH PARTITION public.dat_gps_ble_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_ble_2026_q4_mac_address_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_mac_address ATTACH PARTITION public.dat_gps_ble_2026_q4_mac_address_idx;


--
-- Name: dat_gps_ble_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_ble ATTACH PARTITION public.dat_gps_ble_2026_q4_pkey;


--
-- Name: dat_gps_ble_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_ble_semana ATTACH PARTITION public.dat_gps_ble_2026_q4_semana_anio_idx;


--
-- Name: dat_gps_equipos_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_agrupacion ATTACH PARTITION public.dat_gps_equipos_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_equipos_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_dia_semana ATTACH PARTITION public.dat_gps_equipos_2026_q1_dia_semana_idx;


--
-- Name: dat_gps_equipos_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q1_fecha_idx;


--
-- Name: dat_gps_equipos_2026_q1_fechahora_utc_recepcion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha_recepcion ATTACH PARTITION public.dat_gps_equipos_2026_q1_fechahora_utc_recepcion_idx;


--
-- Name: dat_gps_equipos_2026_q1_geolocalizacion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.six_dat_gps_equipos_geolocalizacion ATTACH PARTITION public.dat_gps_equipos_2026_q1_geolocalizacion_idx;


--
-- Name: dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_equipo_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_tipo_paquete ATTACH PARTITION public.dat_gps_equipos_2026_q1_id_equipo_fechahora_utc_tipo_paquet_idx;


--
-- Name: dat_gps_equipos_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q1_pkey;


--
-- Name: dat_gps_equipos_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_semana ATTACH PARTITION public.dat_gps_equipos_2026_q1_semana_anio_idx;


--
-- Name: dat_gps_equipos_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_agrupacion ATTACH PARTITION public.dat_gps_equipos_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_equipos_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_dia_semana ATTACH PARTITION public.dat_gps_equipos_2026_q2_dia_semana_idx;


--
-- Name: dat_gps_equipos_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q2_fecha_idx;


--
-- Name: dat_gps_equipos_2026_q2_fechahora_utc_recepcion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha_recepcion ATTACH PARTITION public.dat_gps_equipos_2026_q2_fechahora_utc_recepcion_idx;


--
-- Name: dat_gps_equipos_2026_q2_geolocalizacion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.six_dat_gps_equipos_geolocalizacion ATTACH PARTITION public.dat_gps_equipos_2026_q2_geolocalizacion_idx;


--
-- Name: dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_equipo_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_tipo_paquete ATTACH PARTITION public.dat_gps_equipos_2026_q2_id_equipo_fechahora_utc_tipo_paquet_idx;


--
-- Name: dat_gps_equipos_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q2_pkey;


--
-- Name: dat_gps_equipos_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_semana ATTACH PARTITION public.dat_gps_equipos_2026_q2_semana_anio_idx;


--
-- Name: dat_gps_equipos_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_agrupacion ATTACH PARTITION public.dat_gps_equipos_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_equipos_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_dia_semana ATTACH PARTITION public.dat_gps_equipos_2026_q3_dia_semana_idx;


--
-- Name: dat_gps_equipos_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q3_fecha_idx;


--
-- Name: dat_gps_equipos_2026_q3_fechahora_utc_recepcion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha_recepcion ATTACH PARTITION public.dat_gps_equipos_2026_q3_fechahora_utc_recepcion_idx;


--
-- Name: dat_gps_equipos_2026_q3_geolocalizacion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.six_dat_gps_equipos_geolocalizacion ATTACH PARTITION public.dat_gps_equipos_2026_q3_geolocalizacion_idx;


--
-- Name: dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_equipo_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_tipo_paquete ATTACH PARTITION public.dat_gps_equipos_2026_q3_id_equipo_fechahora_utc_tipo_paquet_idx;


--
-- Name: dat_gps_equipos_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q3_pkey;


--
-- Name: dat_gps_equipos_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_semana ATTACH PARTITION public.dat_gps_equipos_2026_q3_semana_anio_idx;


--
-- Name: dat_gps_equipos_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_agrupacion ATTACH PARTITION public.dat_gps_equipos_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_equipos_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_dia_semana ATTACH PARTITION public.dat_gps_equipos_2026_q4_dia_semana_idx;


--
-- Name: dat_gps_equipos_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q4_fecha_idx;


--
-- Name: dat_gps_equipos_2026_q4_fechahora_utc_recepcion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_fecha_recepcion ATTACH PARTITION public.dat_gps_equipos_2026_q4_fechahora_utc_recepcion_idx;


--
-- Name: dat_gps_equipos_2026_q4_geolocalizacion_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.six_dat_gps_equipos_geolocalizacion ATTACH PARTITION public.dat_gps_equipos_2026_q4_geolocalizacion_idx;


--
-- Name: dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_equipo_fecha ATTACH PARTITION public.dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_tipo_paquet_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_tipo_paquete ATTACH PARTITION public.dat_gps_equipos_2026_q4_id_equipo_fechahora_utc_tipo_paquet_idx;


--
-- Name: dat_gps_equipos_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_equipos ATTACH PARTITION public.dat_gps_equipos_2026_q4_pkey;


--
-- Name: dat_gps_equipos_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_equipos_semana ATTACH PARTITION public.dat_gps_equipos_2026_q4_semana_anio_idx;


--
-- Name: dat_gps_geocodificacion_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_agrupacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_geocodificacion_2026_q1_calle_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_calle_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_calle_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_dia_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_dia_semana_idx;


--
-- Name: dat_gps_geocodificacion_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_fecha_idx;


--
-- Name: dat_gps_geocodificacion_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_equipo_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_pkey;


--
-- Name: dat_gps_geocodificacion_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q1_semana_anio_idx;


--
-- Name: dat_gps_geocodificacion_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_agrupacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_geocodificacion_2026_q2_calle_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_calle_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_calle_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_dia_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_dia_semana_idx;


--
-- Name: dat_gps_geocodificacion_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_fecha_idx;


--
-- Name: dat_gps_geocodificacion_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_equipo_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_pkey;


--
-- Name: dat_gps_geocodificacion_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q2_semana_anio_idx;


--
-- Name: dat_gps_geocodificacion_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_agrupacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_geocodificacion_2026_q3_calle_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_calle_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_calle_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_dia_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_dia_semana_idx;


--
-- Name: dat_gps_geocodificacion_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_fecha_idx;


--
-- Name: dat_gps_geocodificacion_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_equipo_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_pkey;


--
-- Name: dat_gps_geocodificacion_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q3_semana_anio_idx;


--
-- Name: dat_gps_geocodificacion_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_agrupacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_geocodificacion_2026_q4_calle_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_calle_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_calle_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_dia_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_dia_semana_idx;


--
-- Name: dat_gps_geocodificacion_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_fecha_idx;


--
-- Name: dat_gps_geocodificacion_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_equipo_fecha ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_geocodificacion_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_geocodificacion ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_pkey;


--
-- Name: dat_gps_geocodificacion_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_geocodificacion_semana ATTACH PARTITION public.dat_gps_geocodificacion_2026_q4_semana_anio_idx;


--
-- Name: dat_gps_io_raw_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_agrupacion ATTACH PARTITION public.dat_gps_io_raw_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_io_raw_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_dia_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q1_dia_semana_idx;


--
-- Name: dat_gps_io_raw_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q1_fecha_idx;


--
-- Name: dat_gps_io_raw_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_equipo_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_io_raw_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q1_pkey;


--
-- Name: dat_gps_io_raw_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q1_semana_anio_idx;


--
-- Name: dat_gps_io_raw_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_agrupacion ATTACH PARTITION public.dat_gps_io_raw_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_io_raw_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_dia_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q2_dia_semana_idx;


--
-- Name: dat_gps_io_raw_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q2_fecha_idx;


--
-- Name: dat_gps_io_raw_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_equipo_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_io_raw_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q2_pkey;


--
-- Name: dat_gps_io_raw_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q2_semana_anio_idx;


--
-- Name: dat_gps_io_raw_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_agrupacion ATTACH PARTITION public.dat_gps_io_raw_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_io_raw_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_dia_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q3_dia_semana_idx;


--
-- Name: dat_gps_io_raw_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q3_fecha_idx;


--
-- Name: dat_gps_io_raw_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_equipo_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_io_raw_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q3_pkey;


--
-- Name: dat_gps_io_raw_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q3_semana_anio_idx;


--
-- Name: dat_gps_io_raw_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_agrupacion ATTACH PARTITION public.dat_gps_io_raw_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_io_raw_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_dia_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q4_dia_semana_idx;


--
-- Name: dat_gps_io_raw_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q4_fecha_idx;


--
-- Name: dat_gps_io_raw_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_equipo_fecha ATTACH PARTITION public.dat_gps_io_raw_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_io_raw_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_io_raw ATTACH PARTITION public.dat_gps_io_raw_2026_q4_pkey;


--
-- Name: dat_gps_io_raw_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_io_raw_semana ATTACH PARTITION public.dat_gps_io_raw_2026_q4_semana_anio_idx;


--
-- Name: dat_gps_sensores_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_agrupacion ATTACH PARTITION public.dat_gps_sensores_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_sensores_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_dia_semana ATTACH PARTITION public.dat_gps_sensores_2026_q1_dia_semana_idx;


--
-- Name: dat_gps_sensores_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q1_fecha_idx;


--
-- Name: dat_gps_sensores_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_equipo_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q1_id_sensor_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_sensor_tiempo ATTACH PARTITION public.dat_gps_sensores_2026_q1_id_sensor_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q1_pkey;


--
-- Name: dat_gps_sensores_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_semana ATTACH PARTITION public.dat_gps_sensores_2026_q1_semana_anio_idx;


--
-- Name: dat_gps_sensores_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_agrupacion ATTACH PARTITION public.dat_gps_sensores_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_sensores_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_dia_semana ATTACH PARTITION public.dat_gps_sensores_2026_q2_dia_semana_idx;


--
-- Name: dat_gps_sensores_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q2_fecha_idx;


--
-- Name: dat_gps_sensores_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_equipo_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q2_id_sensor_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_sensor_tiempo ATTACH PARTITION public.dat_gps_sensores_2026_q2_id_sensor_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q2_pkey;


--
-- Name: dat_gps_sensores_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_semana ATTACH PARTITION public.dat_gps_sensores_2026_q2_semana_anio_idx;


--
-- Name: dat_gps_sensores_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_agrupacion ATTACH PARTITION public.dat_gps_sensores_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_sensores_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_dia_semana ATTACH PARTITION public.dat_gps_sensores_2026_q3_dia_semana_idx;


--
-- Name: dat_gps_sensores_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q3_fecha_idx;


--
-- Name: dat_gps_sensores_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_equipo_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q3_id_sensor_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_sensor_tiempo ATTACH PARTITION public.dat_gps_sensores_2026_q3_id_sensor_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q3_pkey;


--
-- Name: dat_gps_sensores_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_semana ATTACH PARTITION public.dat_gps_sensores_2026_q3_semana_anio_idx;


--
-- Name: dat_gps_sensores_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_agrupacion ATTACH PARTITION public.dat_gps_sensores_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_gps_sensores_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_dia_semana ATTACH PARTITION public.dat_gps_sensores_2026_q4_dia_semana_idx;


--
-- Name: dat_gps_sensores_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q4_fecha_idx;


--
-- Name: dat_gps_sensores_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_equipo_fecha ATTACH PARTITION public.dat_gps_sensores_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q4_id_sensor_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_sensor_tiempo ATTACH PARTITION public.dat_gps_sensores_2026_q4_id_sensor_fechahora_utc_idx;


--
-- Name: dat_gps_sensores_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_gps_sensores ATTACH PARTITION public.dat_gps_sensores_2026_q4_pkey;


--
-- Name: dat_gps_sensores_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_gps_sensores_semana ATTACH PARTITION public.dat_gps_sensores_2026_q4_semana_anio_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_agrupacion ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_dia_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q1_dia_semana_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q1_fecha_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q1_pkey;


--
-- Name: dat_reporte_calles_visitadas_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q1_semana_anio_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_agrupacion ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_dia_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q2_dia_semana_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q2_fecha_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q2_pkey;


--
-- Name: dat_reporte_calles_visitadas_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q2_semana_anio_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_agrupacion ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_dia_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q3_dia_semana_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q3_fecha_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q3_pkey;


--
-- Name: dat_reporte_calles_visitadas_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q3_semana_anio_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_agrupacion ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_dia_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q4_dia_semana_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q4_fecha_idx;


--
-- Name: dat_reporte_calles_visitadas_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_reporte_calles_visitadas ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q4_pkey;


--
-- Name: dat_reporte_calles_visitadas_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_semana ATTACH PARTITION public.dat_reporte_calles_visitadas_2026_q4_semana_anio_idx;


--
-- Name: dat_reporte_calles_visitadas_202_calle_fechahora_utc_salida_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_calle_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_202_calle_fechahora_utc_salida_idx;


--
-- Name: dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx1; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_calle_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx1;


--
-- Name: dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx2; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_calle_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx2;


--
-- Name: dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx3; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_calle_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas_20_calle_fechahora_utc_salida_idx3;


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx1; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_equipo_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx1;


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx2; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_equipo_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx2;


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx3; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_equipo_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas__id_equipo_fechahora_utc_sali_idx3;


--
-- Name: dat_reporte_calles_visitadas__id_equipo_fechahora_utc_salid_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_reporte_calles_equipo_fecha ATTACH PARTITION public.dat_reporte_calles_visitadas__id_equipo_fechahora_utc_salid_idx;


--
-- Name: dat_tcp_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_agrupacion ATTACH PARTITION public.dat_tcp_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_tcp_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_dia_semana ATTACH PARTITION public.dat_tcp_2026_q1_dia_semana_idx;


--
-- Name: dat_tcp_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_fecha ATTACH PARTITION public.dat_tcp_2026_q1_fecha_idx;


--
-- Name: dat_tcp_2026_q1_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_equipo_fecha ATTACH PARTITION public.dat_tcp_2026_q1_id_equipo_fechahora_utc_idx;


--
-- Name: dat_tcp_2026_q1_id_gps_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_id_gps ATTACH PARTITION public.dat_tcp_2026_q1_id_gps_idx;


--
-- Name: dat_tcp_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_tcp ATTACH PARTITION public.dat_tcp_2026_q1_pkey;


--
-- Name: dat_tcp_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_semana ATTACH PARTITION public.dat_tcp_2026_q1_semana_anio_idx;


--
-- Name: dat_tcp_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_agrupacion ATTACH PARTITION public.dat_tcp_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_tcp_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_dia_semana ATTACH PARTITION public.dat_tcp_2026_q2_dia_semana_idx;


--
-- Name: dat_tcp_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_fecha ATTACH PARTITION public.dat_tcp_2026_q2_fecha_idx;


--
-- Name: dat_tcp_2026_q2_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_equipo_fecha ATTACH PARTITION public.dat_tcp_2026_q2_id_equipo_fechahora_utc_idx;


--
-- Name: dat_tcp_2026_q2_id_gps_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_id_gps ATTACH PARTITION public.dat_tcp_2026_q2_id_gps_idx;


--
-- Name: dat_tcp_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_tcp ATTACH PARTITION public.dat_tcp_2026_q2_pkey;


--
-- Name: dat_tcp_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_semana ATTACH PARTITION public.dat_tcp_2026_q2_semana_anio_idx;


--
-- Name: dat_tcp_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_agrupacion ATTACH PARTITION public.dat_tcp_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_tcp_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_dia_semana ATTACH PARTITION public.dat_tcp_2026_q3_dia_semana_idx;


--
-- Name: dat_tcp_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_fecha ATTACH PARTITION public.dat_tcp_2026_q3_fecha_idx;


--
-- Name: dat_tcp_2026_q3_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_equipo_fecha ATTACH PARTITION public.dat_tcp_2026_q3_id_equipo_fechahora_utc_idx;


--
-- Name: dat_tcp_2026_q3_id_gps_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_id_gps ATTACH PARTITION public.dat_tcp_2026_q3_id_gps_idx;


--
-- Name: dat_tcp_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_tcp ATTACH PARTITION public.dat_tcp_2026_q3_pkey;


--
-- Name: dat_tcp_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_semana ATTACH PARTITION public.dat_tcp_2026_q3_semana_anio_idx;


--
-- Name: dat_tcp_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_agrupacion ATTACH PARTITION public.dat_tcp_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: dat_tcp_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_dia_semana ATTACH PARTITION public.dat_tcp_2026_q4_dia_semana_idx;


--
-- Name: dat_tcp_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_fecha ATTACH PARTITION public.dat_tcp_2026_q4_fecha_idx;


--
-- Name: dat_tcp_2026_q4_id_equipo_fechahora_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_equipo_fecha ATTACH PARTITION public.dat_tcp_2026_q4_id_equipo_fechahora_utc_idx;


--
-- Name: dat_tcp_2026_q4_id_gps_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_id_gps ATTACH PARTITION public.dat_tcp_2026_q4_id_gps_idx;


--
-- Name: dat_tcp_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_dat_tcp ATTACH PARTITION public.dat_tcp_2026_q4_pkey;


--
-- Name: dat_tcp_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_dat_tcp_semana ATTACH PARTITION public.dat_tcp_2026_q4_semana_anio_idx;


--
-- Name: log_auditoria_usuarios_2026_q1_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_agrupacion ATTACH PARTITION public.log_auditoria_usuarios_2026_q1_anio_mes_dia_mes_turno_idx;


--
-- Name: log_auditoria_usuarios_2026_q1_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_dia_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q1_dia_semana_idx;


--
-- Name: log_auditoria_usuarios_2026_q1_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_fecha ATTACH PARTITION public.log_auditoria_usuarios_2026_q1_fecha_idx;


--
-- Name: log_auditoria_usuarios_2026_q1_id_usuario_fecha_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_usuario ATTACH PARTITION public.log_auditoria_usuarios_2026_q1_id_usuario_fecha_utc_idx;


--
-- Name: log_auditoria_usuarios_2026_q1_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q1_pkey;


--
-- Name: log_auditoria_usuarios_2026_q1_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q1_semana_anio_idx;


--
-- Name: log_auditoria_usuarios_2026_q2_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_agrupacion ATTACH PARTITION public.log_auditoria_usuarios_2026_q2_anio_mes_dia_mes_turno_idx;


--
-- Name: log_auditoria_usuarios_2026_q2_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_dia_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q2_dia_semana_idx;


--
-- Name: log_auditoria_usuarios_2026_q2_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_fecha ATTACH PARTITION public.log_auditoria_usuarios_2026_q2_fecha_idx;


--
-- Name: log_auditoria_usuarios_2026_q2_id_usuario_fecha_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_usuario ATTACH PARTITION public.log_auditoria_usuarios_2026_q2_id_usuario_fecha_utc_idx;


--
-- Name: log_auditoria_usuarios_2026_q2_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q2_pkey;


--
-- Name: log_auditoria_usuarios_2026_q2_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q2_semana_anio_idx;


--
-- Name: log_auditoria_usuarios_2026_q3_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_agrupacion ATTACH PARTITION public.log_auditoria_usuarios_2026_q3_anio_mes_dia_mes_turno_idx;


--
-- Name: log_auditoria_usuarios_2026_q3_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_dia_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q3_dia_semana_idx;


--
-- Name: log_auditoria_usuarios_2026_q3_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_fecha ATTACH PARTITION public.log_auditoria_usuarios_2026_q3_fecha_idx;


--
-- Name: log_auditoria_usuarios_2026_q3_id_usuario_fecha_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_usuario ATTACH PARTITION public.log_auditoria_usuarios_2026_q3_id_usuario_fecha_utc_idx;


--
-- Name: log_auditoria_usuarios_2026_q3_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q3_pkey;


--
-- Name: log_auditoria_usuarios_2026_q3_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q3_semana_anio_idx;


--
-- Name: log_auditoria_usuarios_2026_q4_anio_mes_dia_mes_turno_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_agrupacion ATTACH PARTITION public.log_auditoria_usuarios_2026_q4_anio_mes_dia_mes_turno_idx;


--
-- Name: log_auditoria_usuarios_2026_q4_dia_semana_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_dia_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q4_dia_semana_idx;


--
-- Name: log_auditoria_usuarios_2026_q4_fecha_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_fecha ATTACH PARTITION public.log_auditoria_usuarios_2026_q4_fecha_idx;


--
-- Name: log_auditoria_usuarios_2026_q4_id_usuario_fecha_utc_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_usuario ATTACH PARTITION public.log_auditoria_usuarios_2026_q4_id_usuario_fecha_utc_idx;


--
-- Name: log_auditoria_usuarios_2026_q4_pkey; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.pk_log_auditoria_usuarios ATTACH PARTITION public.log_auditoria_usuarios_2026_q4_pkey;


--
-- Name: log_auditoria_usuarios_2026_q4_semana_anio_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_semana ATTACH PARTITION public.log_auditoria_usuarios_2026_q4_semana_anio_idx;


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx1; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_objeto ATTACH PARTITION public.log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx1;


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx2; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_objeto ATTACH PARTITION public.log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx2;


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx3; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_objeto ATTACH PARTITION public.log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fec_idx3;


--
-- Name: log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fech_idx; Type: INDEX ATTACH; Schema: public; Owner: admin
--

ALTER INDEX public.ix_log_auditoria_usuarios_objeto ATTACH PARTITION public.log_auditoria_usuarios_2026_q_id_tipo_objeto_id_objeto_fech_idx;


--
-- PostgreSQL database dump complete
--

