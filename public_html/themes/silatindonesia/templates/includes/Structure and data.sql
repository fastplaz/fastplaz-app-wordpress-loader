--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: apinbox(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION apinbox() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

jml INT;

x INT;

BEGIN

 IF  (SELECT id FROM tps_surveyor WHERE msisdn = NEW.fromnum) IS NULL

 THEN 

   INSERT INTO apoutbox (tonum,msgtext) VALUES (NEW.fromnum,'Maaf, no hp anda tidak terdaftar');

   RETURN NEW;

 ELSE

   IF  (SELECT id FROM tps WHERE msisdn = NEW.fromnum AND kode = CAST(SUBSTRING(NEW.msgtext, '_*([A-Z,0-9]{1,2})') AS TEXT)) IS NULL

     THEN

        INSERT INTO apoutbox (tonum,msgtext) VALUES (NEW.fromnum,'Maaf, kode tps yg anda kirimkan salah');

        RETURN NEW;

     ELSE

	SELECT count(id) INTO jml FROM apinbox WHERE (fromnum = NEW.fromnum) AND (CAST(SUBSTRING(msgtext, '_*([A-Z,0-9]{1,2})') AS TEXT) = CAST(SUBSTRING(NEW.msgtext, '_*([A-Z,0-9]{1,2})') AS TEXT));

	IF jml = 1 

	THEN

		INSERT INTO vote_colector (calon_id,apinbox_id,tps_id,post_date,vote) 

			(SELECT calon.id AS calon_id,NEW.id,tps_id,NEW.cdate,suara

				FROM

				(SELECT tps.pilkada_id, tps.id AS tps_id,

					SUBSTRING(NEW.msgtext, '_*([A-Z,0-9]{1,2})') AS notps,

					CAST(SUBSTRING(cast(regexp_matches(NEW.msgtext, '([^,]:+)', 'g') AS text), '_*([0-9]{1,10})') AS INTEGER ) AS urut_calon, 

						CAST(SUBSTRING(cast(regexp_matches(NEW.msgtext, '(:[^,]+)', 'g') AS text), '_*([0-9]{1,10})') AS INTEGER) AS suara

				FROM tps 

					WHERE tps.kode = SUBSTRING(NEW.msgtext, '_*([A-Z,0-9]{1,2})')

				) as ss

				LEFT JOIN calon 

					ON calon.pilkada_id = ss.pilkada_id

					AND calon.urut = ss.urut_calon

			);

		RETURN NEW;

	ELSE

		UPDATE vote_colector 

			SET apinbox_id = NEW.id,

			vote = dhevie.suara,

			post_date = NEW.cdate

			FROM

			(SELECT calon.id AS calon_id,NEW.id,tps_id,NEW.cdate,suara

				FROM

				(SELECT tps.pilkada_id, tps.id AS tps_id,

					SUBSTRING(NEW.msgtext, '_*([A-Z,0-9]{1,2})') AS notps,

					CAST(SUBSTRING(cast(regexp_matches(NEW.msgtext, '([^,]:+)', 'g') AS text), '_*([0-9]{1,10})') AS INTEGER ) AS urut_calon, 

						CAST(SUBSTRING(cast(regexp_matches(NEW.msgtext, '(:[^,]+)', 'g') AS text), '_*([0-9]{1,10})') AS INTEGER) AS suara

				FROM tps 

					WHERE tps.kode = SUBSTRING(NEW.msgtext, '_*([A-Z,0-9]{1,2})')

				) as ss

				LEFT JOIN calon 

					ON calon.pilkada_id = ss.pilkada_id

					AND calon.urut = ss.urut_calon

			) AS dhevie WHERE dhevie.calon_id = vote_colector.calon_id

					AND dhevie.tps_id = vote_colector.tps_id;

		RETURN NEW;

	END IF;

     END  IF;

  END IF;

END;

$$;


ALTER FUNCTION public.apinbox() OWNER TO postgres;

--
-- Name: calon(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION calon() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on calon table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.pilkada_id <> OLD.pilkada_id) OR (NEW.nama <> OLD.nama) OR (NEW.urut <> OLD.urut) OR (NEW.status_id <> OLD.status_id) THEN

	UPDATE calon SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on calon table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.calon() OWNER TO postgres;

--
-- Name: createtps(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION createtps(pilkadaid character varying, notps character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE

  mpilkadaid TEXT;

  jns int;

BEGIN

SELECT jenis,mpilkada_id INTO jns,mpilkadaid FROM pilkada_event p

 LEFT JOIN (SELECT id,jenis FROM mpilkada ) x ON x.id = p.mpilkada_id

WHERE p.id = CAST(pilkadaid AS uuid);

IF jns = 1 THEN 

  INSERT INTO tps (pilkada_id,desa_id,kode,no) SELECT CAST(pilkadaid AS uuid),id,random_string(2),notps FROM vdesa WHERE idkab = (SELECT id_fk FROM vmpilkada WHERE id = CAST(mpilkadaid AS uuid));

ELSE

  INSERT INTO tps (pilkada_id,desa_id,kode,no) SELECT CAST(pilkadaid AS uuid),id,random_string(2),notps FROM vdesa WHERE idprop = (SELECT id_fk FROM vmpilkada WHERE id = CAST(mpilkadaid AS uuid));

END IF;

RETURN;

END;

$$;


ALTER FUNCTION public.createtps(pilkadaid character varying, notps character varying) OWNER TO postgres;

--
-- Name: desa(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION desa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on desa table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.nama <> OLD.nama) OR (NEW.kode <> OLD.kode) THEN

	UPDATE desa SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on desa table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.desa() OWNER TO postgres;

--
-- Name: kabupaten(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION kabupaten() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO mpilkada (id_fk,parent_id,jenis) VALUES (NEW.id, NEW.propinsi_id,1);

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on kabupaten table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.nama <> OLD.nama) OR (NEW.kode <> OLD.kode) THEN

	UPDATE kabupaten SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on kabupaten table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.kabupaten() OWNER TO postgres;

--
-- Name: kecamatan(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION kecamatan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on kecamatan table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.nama <> OLD.nama) OR (NEW.kode <> OLD.kode) THEN

	UPDATE kecamatan SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on kecamatan table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.kecamatan() OWNER TO postgres;

--
-- Name: pilkada_event(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION pilkada_event() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on pilkada_event table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.mpilkada_id <> OLD.mpilkada_id) OR (NEW.tahun <> OLD.tahun) OR (NEW.status_id <> OLD.status_id) THEN

	UPDATE pilkada_event SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on pilkada_event table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.pilkada_event() OWNER TO postgres;

--
-- Name: propinsi(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION propinsi() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE nmr uuid;

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO mpilkada (id_fk,parent_id,jenis) VALUES (NEW.id,NEW.id,0);

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'isi data on propinsi table with id '||NEW.id);

   RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.nama <> OLD.nama) OR (NEW.kode <> OLD.kode) THEN

	--SELECT id INTO nmr FROM propinsi WHERE id = OLD.id;

	UPDATE propinsi SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on propinsi table with id '||OLD.id);

   RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.propinsi() OWNER TO postgres;

--
-- Name: random_string(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION random_string(length integer) RETURNS text
    LANGUAGE plpgsql
    AS $$

declare

  result text ;

begin

  if length < 0 then

    raise exception 'Given length cannot be less than 0';

  end if;

LOOP

SELECT array_to_string(array((

   SELECT SUBSTRING('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

                    FROM mod((random()*32)::int, 32)+1 FOR 1)

	INTO result FROM generate_series(1,length))),'');

EXIT WHEN NOT EXISTS(SELECT 1 FROM tps WHERE kode = result);

END LOOP;

  return result;

end;

$$;


ALTER FUNCTION public.random_string(length integer) OWNER TO postgres;

--
-- Name: tps(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION tps() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on tps table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.pilkada_id <> OLD.pilkada_id) OR (NEW.desa_id <> OLD.desa_id) OR (NEW.no <> OLD.no) THEN

	UPDATE tps SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on tps table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.tps() OWNER TO postgres;

--
-- Name: tps_surveyor(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION tps_surveyor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

DECLARE

BEGIN

 IF (TG_OP = 'INSERT') THEN 

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.createdby,NEW.createddate,'create data on tps_surveyor table with id '||NEW.id);

	RETURN NEW;

 ELSIF (TG_OP = 'UPDATE') THEN 

   IF (NEW.tps_id <> OLD.tps_id) OR (NEW.nama <> OLD.nama) OR (NEW.msisdn <> OLD.msisdn) THEN

	UPDATE tps_surveyor SET updateddate = now() WHERE id = OLD.id;

	INSERT INTO logs (user_id,logsdate,actions) VALUES (NEW.updatedby,now(),'update data on tps_surveyor table with id '||OLD.id);

	RETURN NEW;

   ELSE

	RETURN NULL;

   END IF;

 END IF;

END;

$$;


ALTER FUNCTION public.tps_surveyor() OWNER TO postgres;

--
-- Name: uuid_generate_v1(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_generate_v1() RETURNS uuid
    LANGUAGE c STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v1';


ALTER FUNCTION public.uuid_generate_v1() OWNER TO postgres;

--
-- Name: uuid_generate_v1mc(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_generate_v1mc() RETURNS uuid
    LANGUAGE c STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v1mc';


ALTER FUNCTION public.uuid_generate_v1mc() OWNER TO postgres;

--
-- Name: uuid_generate_v3(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_generate_v3(namespace uuid, name text) RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v3';


ALTER FUNCTION public.uuid_generate_v3(namespace uuid, name text) OWNER TO postgres;

--
-- Name: uuid_generate_v4(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_generate_v4() RETURNS uuid
    LANGUAGE c STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v4';


ALTER FUNCTION public.uuid_generate_v4() OWNER TO postgres;

--
-- Name: uuid_generate_v5(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_generate_v5(namespace uuid, name text) RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_generate_v5';


ALTER FUNCTION public.uuid_generate_v5(namespace uuid, name text) OWNER TO postgres;

--
-- Name: uuid_nil(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_nil() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_nil';


ALTER FUNCTION public.uuid_nil() OWNER TO postgres;

--
-- Name: uuid_ns_dns(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_ns_dns() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_dns';


ALTER FUNCTION public.uuid_ns_dns() OWNER TO postgres;

--
-- Name: uuid_ns_oid(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_ns_oid() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_oid';


ALTER FUNCTION public.uuid_ns_oid() OWNER TO postgres;

--
-- Name: uuid_ns_url(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_ns_url() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_url';


ALTER FUNCTION public.uuid_ns_url() OWNER TO postgres;

--
-- Name: uuid_ns_x500(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION uuid_ns_x500() RETURNS uuid
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/uuid-ossp', 'uuid_ns_x500';


ALTER FUNCTION public.uuid_ns_x500() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: acls; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE acls (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    controllers character varying(100),
    actions character varying(100),
    status smallint
);


ALTER TABLE public.acls OWNER TO postgres;

--
-- Name: apinbox; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE apinbox (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    cdate timestamp without time zone DEFAULT now(),
    fromnum character varying(21),
    msgtext text
);


ALTER TABLE public.apinbox OWNER TO postgres;

--
-- Name: apoutbox; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE apoutbox (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    cdate timestamp without time zone DEFAULT now(),
    syuserlogin_id uuid,
    tonum character varying(21),
    msgtext text,
    flag smallint,
    processingdate timestamp without time zone
);


ALTER TABLE public.apoutbox OWNER TO postgres;

--
-- Name: calon; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE calon (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    pilkada_id uuid NOT NULL,
    urut smallint,
    nama character varying(50),
    description text,
    status_id smallint DEFAULT 1,
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.calon OWNER TO postgres;

--
-- Name: desa; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE desa (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    kecamatan_id uuid,
    kode character(2),
    nama character varying(50),
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.desa OWNER TO postgres;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE groups (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    nama character varying(30)
);


ALTER TABLE public.groups OWNER TO postgres;

--
-- Name: kabupaten; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE kabupaten (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    propinsi_id uuid,
    kode character(2),
    nama character varying(50),
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.kabupaten OWNER TO postgres;

--
-- Name: TABLE kabupaten; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE kabupaten IS 'nama kabupaten, kode sesuai kode administratif';


--
-- Name: kecamatan; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE kecamatan (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    kabupaten_id uuid,
    kode character(2),
    nama character varying(50),
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.kecamatan OWNER TO postgres;

--
-- Name: TABLE kecamatan; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE kecamatan IS 'daftar nama kecamatan, kode mengikuti administratif';


--
-- Name: level_acls; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE level_acls (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    level_id uuid,
    acl_id uuid
);


ALTER TABLE public.level_acls OWNER TO postgres;

--
-- Name: level_menus; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE level_menus (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    level_id uuid,
    menu_id uuid
);


ALTER TABLE public.level_menus OWNER TO postgres;

--
-- Name: levels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE levels (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    name character varying(50)
);


ALTER TABLE public.levels OWNER TO postgres;

--
-- Name: logs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE logs (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    user_id uuid,
    logsdate timestamp without time zone,
    actions text
);


ALTER TABLE public.logs OWNER TO postgres;

--
-- Name: menus; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE menus (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    group_id uuid,
    nama character varying(100),
    link character varying(100)
);


ALTER TABLE public.menus OWNER TO postgres;

--
-- Name: mpilkada; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE mpilkada (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    id_fk uuid,
    parent_id uuid,
    jenis integer DEFAULT 0,
    description text,
    status_id smallint DEFAULT 1
);


ALTER TABLE public.mpilkada OWNER TO postgres;

--
-- Name: TABLE mpilkada; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE mpilkada IS 'master pilkada, berisi list propinsi dan kabupaten, di lookup ketika buat event Pilkada...

table ini terisi otomatsi ketika mengisi table propinsi dan table kabupaten';


--
-- Name: COLUMN mpilkada.id_fk; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN mpilkada.id_fk IS 'id_fk berisi id nya table propinsi dan table kabupaten';


--
-- Name: COLUMN mpilkada.parent_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN mpilkada.parent_id IS 'berisi id propinsi, bila pilkada TK I, id_fk pasti sama parent_id';


--
-- Name: COLUMN mpilkada.status_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN mpilkada.status_id IS '1=deleted';


--
-- Name: pilkada_event; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pilkada_event (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    mpilkada_id uuid,
    tahun integer,
    description text,
    status_id smallint DEFAULT 1,
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.pilkada_event OWNER TO postgres;

--
-- Name: TABLE pilkada_event; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE pilkada_event IS 'membuat event pilkada';


--
-- Name: propinsi; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE propinsi (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    kode character(2),
    nama character varying(50),
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.propinsi OWNER TO postgres;

--
-- Name: TABLE propinsi; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE propinsi IS 'daftar propinsi, kode sesuai kode administrasi';


--
-- Name: sysparam; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sysparam (
    name character varying(35) NOT NULL,
    val character varying(50)
);


ALTER TABLE public.sysparam OWNER TO postgres;

--
-- Name: syuserlogin; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE syuserlogin (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    uname character varying(35),
    pwd character varying(50),
    cdate timestamp without time zone,
    level_id uuid
);


ALTER TABLE public.syuserlogin OWNER TO postgres;

--
-- Name: tps; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tps (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    pilkada_id uuid NOT NULL,
    desa_id uuid NOT NULL,
    kode character varying(2),
    no character varying(2),
    status_id smallint DEFAULT 1,
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone,
    msisdn character varying(21)
);


ALTER TABLE public.tps OWNER TO postgres;

--
-- Name: TABLE tps; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE tps IS 'daftar tps';


--
-- Name: COLUMN tps.kode; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN tps.kode IS 'uniqe, dipakai utk format sms';


--
-- Name: COLUMN tps.no; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN tps.no IS 'no tps sesuai riil dilapangan, misal 01, 02 etc';


--
-- Name: COLUMN tps.msisdn; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN tps.msisdn IS 'format 62...';


--
-- Name: tps_surveyor; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tps_surveyor (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    nama character varying(50),
    msisdn character varying(21),
    tps_id uuid,
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.tps_surveyor OWNER TO postgres;

--
-- Name: COLUMN tps_surveyor.msisdn; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN tps_surveyor.msisdn IS 'format: 62....';


--
-- Name: vote_colector; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE vote_colector (
    id uuid DEFAULT uuid_generate_v5(uuid_ns_x500(), (uuid_generate_v4())::text) NOT NULL,
    calon_id uuid,
    apinbox_id uuid,
    tps_id uuid,
    post_date timestamp without time zone,
    vote integer,
    createdby uuid,
    createddate timestamp without time zone DEFAULT now(),
    updatedby uuid,
    updateddate timestamp without time zone
);


ALTER TABLE public.vote_colector OWNER TO postgres;

--
-- Name: TABLE vote_colector; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE vote_colector IS 'menampung data hasil pengolahan message dari sms incoming';


--
-- Name: vcalontps; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vcalontps AS
 SELECT calon.pilkada_id,
    ss.tps_id,
    ( SELECT desa.nama
           FROM desa
          WHERE (desa.id = tps.desa_id)) AS nama_desa,
    tps.no AS notps,
    ss.calon_id,
    calon.urut,
    calon.nama,
    ss.suara
   FROM ((( SELECT vote_colector.calon_id,
            vote_colector.tps_id,
            sum(vote_colector.vote) AS suara
           FROM vote_colector
          GROUP BY vote_colector.calon_id, vote_colector.tps_id) ss
   LEFT JOIN calon ON ((calon.id = ss.calon_id)))
   LEFT JOIN tps ON ((tps.id = ss.tps_id)));


ALTER TABLE public.vcalontps OWNER TO postgres;

--
-- Name: VIEW vcalontps; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vcalontps IS 'jumlah suara per calon per tps';


--
-- Name: vdesa; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vdesa AS
 SELECT d.id,
    d.kecamatan_id,
    d.kode,
    d.nama,
    x.idkab,
    x.idprop
   FROM (desa d
   LEFT JOIN ( SELECT b.id AS idkab,
            b.propinsi_id AS idprop,
            k.id AS idkec
           FROM (kecamatan k
      LEFT JOIN kabupaten b ON ((b.id = k.kabupaten_id)))) x ON ((x.idkec = d.kecamatan_id)));


ALTER TABLE public.vdesa OWNER TO postgres;

--
-- Name: VIEW vdesa; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vdesa IS 'dipakai ketika mau mengisi table tps..

utk pilihan desa ambil dari vdesa';


--
-- Name: vdesa2; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vdesa2 AS
 SELECT d.id,
    d.kecamatan_id,
    x.kabupaten_id,
    x.propinsi_id,
    d.kode,
    d.nama,
    x.kecamatan_nama,
    x.kabupaten_nama
   FROM (desa d
   LEFT JOIN ( SELECT b.id AS kabupaten_id,
            b.propinsi_id,
            k.id AS idkec,
            k.nama AS kecamatan_nama,
            b.nama AS kabupaten_nama
           FROM (kecamatan k
      LEFT JOIN kabupaten b ON ((b.id = k.kabupaten_id)))) x ON ((x.idkec = d.kecamatan_id)));


ALTER TABLE public.vdesa2 OWNER TO postgres;

--
-- Name: VIEW vdesa2; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vdesa2 IS 'dipake utk me-lookup desa ketika mengisi table tps';


--
-- Name: vmpilkada; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vmpilkada AS
 SELECT mpilkada.id,
    mpilkada.id_fk,
    mpilkada.parent_id,
    mpilkada.jenis,
        CASE
            WHEN (mpilkada.jenis = 0) THEN 'TINGKAT I'::text
            ELSE 'TINGKAT II'::text
        END AS tingkat,
        CASE
            WHEN (mpilkada.jenis = 0) THEN ( SELECT propinsi.nama
               FROM propinsi
              WHERE (propinsi.id = mpilkada.id_fk))
            ELSE ( SELECT kabupaten.nama
               FROM kabupaten
              WHERE (kabupaten.id = mpilkada.id_fk))
        END AS nama_pilkada
   FROM mpilkada;


ALTER TABLE public.vmpilkada OWNER TO postgres;

--
-- Name: VIEW vmpilkada; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vmpilkada IS 'ketika mengisi table pilkada_event,

daftar pilkada me-lookup dari vmpilkada ini';


--
-- Name: vpilkada_event; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vpilkada_event AS
 SELECT e.id,
    e.mpilkada_id,
    e.tahun,
    e.description,
    kab.nama AS kabupaten_nama,
    prop.nama AS propinsi_nama
   FROM (((pilkada_event e
   LEFT JOIN mpilkada p ON ((p.id = e.mpilkada_id)))
   LEFT JOIN kabupaten kab ON ((kab.id = p.id_fk)))
   LEFT JOIN propinsi prop ON ((prop.id = p.parent_id)));


ALTER TABLE public.vpilkada_event OWNER TO postgres;

--
-- Name: VIEW vpilkada_event; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vpilkada_event IS 'menampilkan event pilkada

beserta informasi wilayahnya';


--
-- Name: vsms_incoming; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vsms_incoming AS
 SELECT to_char(apinbox.cdate, 'DD/MM/YYYY HH:II:SS'::text) AS cdate,
    apinbox.fromnum AS msisdn,
    apinbox.msgtext AS msg
   FROM apinbox
  ORDER BY apinbox.cdate DESC;


ALTER TABLE public.vsms_incoming OWNER TO postgres;

--
-- Name: vtotalvote; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vtotalvote AS
 SELECT calon.pilkada_id,
    ss.calon_id,
    calon.urut,
    calon.nama,
    ss.suara
   FROM (( SELECT vote_colector.calon_id,
            sum(vote_colector.vote) AS suara
           FROM vote_colector
          GROUP BY vote_colector.calon_id) ss
   LEFT JOIN calon ON ((calon.id = ss.calon_id)));


ALTER TABLE public.vtotalvote OWNER TO postgres;

--
-- Name: VIEW vtotalvote; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vtotalvote IS 'total perolehan masing2 calon//

utk call : SELECT * FROM vtotalvote WHERE pilkada_id = ''xxxx'' ORDER BY suara DESC;';


--
-- Name: vtps; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vtps AS
 SELECT t.id,
    t.kode,
    t.no,
    d.nama AS desa_nama
   FROM (tps t
   LEFT JOIN desa d ON ((d.id = t.desa_id)));


ALTER TABLE public.vtps OWNER TO postgres;

--
-- Name: VIEW vtps; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW vtps IS 'menampilkan list tps';


--
-- Name: vtpsvote; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vtpsvote AS
 SELECT tps.pilkada_id,
    ss.tps_id,
    ( SELECT desa.nama
           FROM desa
          WHERE (desa.id = tps.desa_id)) AS nama_desa,
    tps.no AS notps,
    ss.suara
   FROM (( SELECT vote_colector.tps_id,
            sum(vote_colector.vote) AS suara
           FROM vote_colector
          GROUP BY vote_colector.tps_id) ss
   LEFT JOIN tps ON ((tps.id = ss.tps_id)));


ALTER TABLE public.vtpsvote OWNER TO postgres;

--
-- Data for Name: acls; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY acls (id, controllers, actions, status) FROM stdin;
\.


--
-- Data for Name: apinbox; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY apinbox (id, cdate, fromnum, msgtext) FROM stdin;
9e264848-e5de-55e2-abc8-ee1ed6229e48	2014-02-13 13:52:56.923681	6287876469000	TC,1:440,2:577,3:255
bae3331b-0fed-574c-a4d2-4fabda88d1b4	2014-02-13 22:02:15.477	6287876469000	AL,1:10,2:20,3:30
5e4280ae-3990-50c7-8511-5eb7fd262bde	2014-02-13 22:04:16.472	6287876469001	apa kaabadsf
447bb4fb-a1ea-5121-8c30-058847072cdd	2014-02-13 22:04:37.337	6287876469000	test ngawur
5aee63b6-38fb-5379-8eea-f9e5ed983893	2014-02-13 22:05:35.614	6287876469000	AL,1:10,2:20,3:30
ed20d0ae-78dc-5811-9660-2728d7eab31e	2014-02-13 22:06:51.544	6287876469000	AL,1:5,2:6,3:7
7d455877-fcc8-5282-a084-45855723e2c1	2014-02-13 22:07:16.277	6287876469000	AL,1:10,2:20,3:30\n
2cf034b9-5302-5fb0-b983-bb9dd697398a	2014-02-13 22:08:05.248	628155502030	
8a4d6589-7ff6-53d5-bdcd-22b16c94a6f7	2014-02-13 22:09:18.68	628155502030	FV,1:5,2:6,3:7
\.


--
-- Data for Name: apoutbox; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY apoutbox (id, cdate, syuserlogin_id, tonum, msgtext, flag, processingdate) FROM stdin;
aea45751-b41e-5ff5-baa7-5d2853893beb	2014-02-13 21:59:49.353	\N	6287876469000	Maaf, no hp anda tidak terdaftar	\N	\N
aa34bbea-c2a4-5bbb-9504-75c0143f2d2f	2014-02-13 07:26:15.706767	\N	OR,1:777,2:778,3:779	Maaf, no hp anda tidak terdaftar	\N	\N
19b9a58d-98cf-53ac-9181-8b0020bb24e6	2014-02-13 22:04:16.472	\N	6287876469001	Maaf, no hp anda tidak terdaftar	\N	\N
231c6efa-4d09-5dd5-9e0e-59d7aab39f95	2014-02-13 22:04:37.337	\N	6287876469000	Maaf, kode tps yg anda kirimkan salah	\N	\N
fcfaa9a9-449a-52d7-9304-26189ee2c02f	2014-02-13 22:08:05.248	\N	628155502030	Maaf, kode tps yg anda kirimkan salah	\N	\N
\.


--
-- Data for Name: calon; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY calon (id, pilkada_id, urut, nama, description, status_id, createdby, createddate, updatedby, updateddate) FROM stdin;
e88d703d-d9cd-5744-9c90-330bdf09c573	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	1	MANGGA & PISANG	Pasangan Calon Mangga & Pisang	0	\N	2014-02-11 21:13:58.91322	\N	\N
f850a044-9d39-55ae-a8f5-803107c2fce4	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	2	ANGGUR & MANGGIS	Balon Anggur dan Manggis	0	\N	2014-02-11 21:14:56.138096	\N	\N
9ea1f78e-2cc6-54e6-b45c-02000f00f6e7	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	3	NANAS & JAMBU	Pasangan Nanas dan Jambu	0	\N	2014-02-11 21:15:16.345261	\N	\N
\.


--
-- Data for Name: desa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY desa (id, kecamatan_id, kode, nama, createdby, createddate, updatedby, updateddate) FROM stdin;
73d39be6-63cf-5408-b068-89cb98d806ed	6690ba99-0394-5203-9664-76b38de382ca	01	Kesatrian	\N	2014-02-09 13:54:47.578	\N	\N
b807caab-26f0-5eca-a9f1-6f0e81d0f6c4	6690ba99-0394-5203-9664-76b38de382ca	02	Polehan	\N	2014-02-09 13:54:47.578	\N	\N
979273aa-2433-5503-beab-db20fe1c521d	6690ba99-0394-5203-9664-76b38de382ca	03	Purwantoro	\N	2014-02-09 13:54:47.578	\N	\N
72b865b2-b818-5be7-951f-eb04d2432e21	6690ba99-0394-5203-9664-76b38de382ca	04	Bunulrejo	\N	2014-02-09 13:54:47.578	\N	\N
f0d83204-0372-50b3-abf7-536e2abbd66a	6690ba99-0394-5203-9664-76b38de382ca	05	Pandanwangi	\N	2014-02-09 13:54:47.578	\N	\N
b621027a-d549-58a3-b29c-ea8f11728d16	6690ba99-0394-5203-9664-76b38de382ca	06	Blimbing	\N	2014-02-09 13:54:47.578	\N	\N
ab3020d1-37c6-572f-8320-e159391ac2a8	6690ba99-0394-5203-9664-76b38de382ca	07	Purwodadi	\N	2014-02-09 13:54:47.578	\N	\N
4e1d16ae-fcf6-5a49-894d-398b1b96f777	6690ba99-0394-5203-9664-76b38de382ca	08	Arjosari	\N	2014-02-09 13:54:47.578	\N	\N
8447b159-f515-53b4-bcd8-db7b59c87f93	6690ba99-0394-5203-9664-76b38de382ca	09	Balearjosari	\N	2014-02-09 13:54:47.578	\N	\N
1bf91399-347d-5580-a49e-c16d924125f8	6690ba99-0394-5203-9664-76b38de382ca	10	Polowijen	\N	2014-02-09 13:54:47.578	\N	\N
3cbd8998-c424-56aa-a773-74c17b176bbf	6690ba99-0394-5203-9664-76b38de382ca	11	Jodipan	\N	2014-02-09 13:54:47.578	\N	\N
cff92b6d-5120-5bd6-ac6f-8819f67feabb	fbd92311-1d31-507d-85b7-6aacc6db5dc1	01	Klojen	\N	2014-02-09 14:01:20.031	\N	\N
d32bf146-05f8-5588-aaaf-ad0615fca0e2	fbd92311-1d31-507d-85b7-6aacc6db5dc1	02	Rampal	\N	2014-02-09 14:01:20.031	\N	\N
e7f8c503-9505-585a-a98f-9ad529e08154	fbd92311-1d31-507d-85b7-6aacc6db5dc1	03	Samaan	\N	2014-02-09 14:01:20.031	\N	\N
9e838bbd-6a5b-5c19-870f-f47926ed1168	fbd92311-1d31-507d-85b7-6aacc6db5dc1	04	Penanggungan	\N	2014-02-09 14:01:20.031	\N	\N
26e4c87c-93e5-5e1d-856b-93f4836177a9	fbd92311-1d31-507d-85b7-6aacc6db5dc1	05	Gadingkasri	\N	2014-02-09 14:01:20.031	\N	\N
04dd178c-a00c-57e2-a0d1-241c545a2dd6	fbd92311-1d31-507d-85b7-6aacc6db5dc1	06	Bareng	\N	2014-02-09 14:01:20.031	\N	\N
cfdfd13c-e357-5359-acde-853e538e2455	fbd92311-1d31-507d-85b7-6aacc6db5dc1	07	Kasin	\N	2014-02-09 14:01:20.031	\N	\N
4f99719b-f66a-569a-b188-7b2cd44315c9	fbd92311-1d31-507d-85b7-6aacc6db5dc1	08	Sukoharjo	\N	2014-02-09 14:01:20.031	\N	\N
8a7e7e46-b5d8-5f86-adc2-dfbc42898a22	fbd92311-1d31-507d-85b7-6aacc6db5dc1	09	Kauman	\N	2014-02-09 14:01:20.031	\N	\N
928c7824-6116-5f8d-97a7-69cde1d72f92	fbd92311-1d31-507d-85b7-6aacc6db5dc1	10	Kidul Dalem	\N	2014-02-09 14:01:20.031	\N	\N
da909ac4-ad14-5d4d-9586-61ae468a9800	fbd92311-1d31-507d-85b7-6aacc6db5dc1	11	Oro Oro Dowo	\N	2014-02-09 14:01:20.031	\N	\N
f828604d-2010-5218-87e2-ae3e7f957cf0	160c9c7f-fb34-5a5c-8604-920ec1f045b4	01	Arjowinangun	\N	2014-02-09 14:07:48.64	\N	\N
e75e0f3a-24f7-5960-97d9-cfdec9dfc487	160c9c7f-fb34-5a5c-8604-920ec1f045b4	02	Tlogowaru	\N	2014-02-09 14:07:48.64	\N	\N
0dfd5d6e-5fc5-5717-b99f-5d60ca97a7cc	160c9c7f-fb34-5a5c-8604-920ec1f045b4	03	Mergosono	\N	2014-02-09 14:07:48.64	\N	\N
d4afbb5d-6a15-56a4-9875-c66c6f0b34f9	160c9c7f-fb34-5a5c-8604-920ec1f045b4	04	Bumiayu	\N	2014-02-09 14:07:48.64	\N	\N
18fb4c09-ea9f-597c-a84d-ae3c7c24e7ba	160c9c7f-fb34-5a5c-8604-920ec1f045b4	05	Wonokoyo	\N	2014-02-09 14:07:48.64	\N	\N
b7353ef1-07b1-59a3-a463-e9ed78a8edeb	160c9c7f-fb34-5a5c-8604-920ec1f045b4	06	Buring	\N	2014-02-09 14:07:48.64	\N	\N
d234ab1a-2cf2-5857-b8b6-d8512500b304	160c9c7f-fb34-5a5c-8604-920ec1f045b4	07	Kotalama	\N	2014-02-09 14:07:48.64	\N	\N
870e77c5-7f5f-595e-a7f1-11f28ed51982	160c9c7f-fb34-5a5c-8604-920ec1f045b4	08	Kedungkandang	\N	2014-02-09 14:07:48.64	\N	\N
9b100053-b809-5cca-836a-d12ce14aca84	160c9c7f-fb34-5a5c-8604-920ec1f045b4	09	Cemorokandang	\N	2014-02-09 14:07:48.64	\N	\N
25ff1ca0-9e6a-58f6-8dc2-fad72e0cc581	160c9c7f-fb34-5a5c-8604-920ec1f045b4	10	Lesanpuro	\N	2014-02-09 14:07:48.64	\N	\N
acbc14d0-5d4a-5540-bc59-457591795af5	160c9c7f-fb34-5a5c-8604-920ec1f045b4	11	Madyopuro	\N	2014-02-09 14:07:48.64	\N	\N
bf3c3b68-5586-517d-9280-bd50f49352d8	160c9c7f-fb34-5a5c-8604-920ec1f045b4	12	Sawojajar	\N	2014-02-09 14:07:48.64	\N	\N
2a2ebca2-63e4-56ef-abfa-8a57e35cf454	3202bed8-f512-5bd3-870e-f7cb39761c30	01	Bandulan	\N	2014-02-09 14:17:57.25	\N	\N
e1b28d35-ee2c-5cb0-82b1-c9ebb48fb5e8	3202bed8-f512-5bd3-870e-f7cb39761c30	02	Pisang Candi	\N	2014-02-09 14:17:57.25	\N	\N
44c89a8e-9451-5cac-9384-de9f458cf68e	3202bed8-f512-5bd3-870e-f7cb39761c30	03	Mulyorejo	\N	2014-02-09 14:17:57.25	\N	\N
a4a80b21-0d10-5017-869d-a2e14ca09225	3202bed8-f512-5bd3-870e-f7cb39761c30	04	Sukun	\N	2014-02-09 14:17:57.25	\N	\N
f5fe215e-1eaf-55f2-a141-5ad8c9686af1	3202bed8-f512-5bd3-870e-f7cb39761c30	05	Tanjungrejo	\N	2014-02-09 14:17:57.25	\N	\N
73a54677-5bff-513f-a154-20d2517c94bf	3202bed8-f512-5bd3-870e-f7cb39761c30	06	Bakalan Krajan	\N	2014-02-09 14:17:57.25	\N	\N
0ee44675-a474-5fde-bfde-a505a7a75331	3202bed8-f512-5bd3-870e-f7cb39761c30	07	Bandungrejosari	\N	2014-02-09 14:17:57.25	\N	\N
79e63a25-93d1-5aba-b771-d6288768641d	3202bed8-f512-5bd3-870e-f7cb39761c30	08	Ciptomulyo	\N	2014-02-09 14:17:57.25	\N	\N
71a28213-685f-5746-8349-8f0a35f3f599	3202bed8-f512-5bd3-870e-f7cb39761c30	09	Gadang	\N	2014-02-09 14:17:57.25	\N	\N
3f9526e6-42ac-572d-9ecc-129e8194d865	3202bed8-f512-5bd3-870e-f7cb39761c30	10	Karang Besuki	\N	2014-02-09 14:17:57.25	\N	\N
768ef350-5fc3-575a-afc5-42a0b5dc064e	3202bed8-f512-5bd3-870e-f7cb39761c30	11	Kebonsari	\N	2014-02-09 14:17:57.25	\N	\N
9746f9bf-b155-5976-9e30-753f6dd05b31	b71ed720-4481-5a27-bce4-5185c91f8cc0	01	Jatimulyo	\N	2014-02-09 14:22:07.5	\N	\N
b3b02c61-851c-5065-b577-09f6bfb9a4a1	b71ed720-4481-5a27-bce4-5185c91f8cc0	02	Lowokwaru	\N	2014-02-09 14:22:07.5	\N	\N
4fd907f1-2e04-5d6c-aae1-b2fdb3e50a97	b71ed720-4481-5a27-bce4-5185c91f8cc0	03	Tulusrejo	\N	2014-02-09 14:22:07.5	\N	\N
6b24f3ea-ea14-5db4-9c59-40cda635ebce	b71ed720-4481-5a27-bce4-5185c91f8cc0	04	Mojolangu	\N	2014-02-09 14:22:07.5	\N	\N
a078c020-7c4e-57e2-bed9-ad06c93eca92	b71ed720-4481-5a27-bce4-5185c91f8cc0	05	Tunjungsekar	\N	2014-02-09 14:22:07.5	\N	\N
4fa63681-22ae-56f3-9688-d3f6532b42ce	b71ed720-4481-5a27-bce4-5185c91f8cc0	06	Tasikmadu	\N	2014-02-09 14:22:07.5	\N	\N
39a238d2-ec7c-5d17-83c1-5bc399101720	b71ed720-4481-5a27-bce4-5185c91f8cc0	07	Tunggulwulung	\N	2014-02-09 14:22:07.5	\N	\N
1833da32-04cb-596c-8293-a2b73f4db663	b71ed720-4481-5a27-bce4-5185c91f8cc0	08	Dinoyo	\N	2014-02-09 14:22:07.5	\N	\N
88798e68-e574-5794-adde-0af2740f836d	b71ed720-4481-5a27-bce4-5185c91f8cc0	09	Merjosari	\N	2014-02-09 14:22:07.5	\N	\N
adc79868-75c9-510b-b27a-206427ec0e2e	b71ed720-4481-5a27-bce4-5185c91f8cc0	10	Tlogomas	\N	2014-02-09 14:22:07.5	\N	\N
7b8a4f81-c010-582c-aaf0-92253ff1f138	b71ed720-4481-5a27-bce4-5185c91f8cc0	11	Ketawanggede	\N	2014-02-09 14:22:07.5	\N	\N
461e10c9-7041-593e-8b78-01843dbfd9bb	b71ed720-4481-5a27-bce4-5185c91f8cc0	12	Sumbersari	\N	2014-02-09 14:22:07.5	\N	\N
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY groups (id, nama) FROM stdin;
\.


--
-- Data for Name: kabupaten; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY kabupaten (id, propinsi_id, kode, nama, createdby, createddate, updatedby, updateddate) FROM stdin;
a7119ade-f30b-5c7e-bb50-20e51ab6e924	c5d7ced3-40d5-58c3-a093-de9982bb8402	06	KAB. KEDIRI	\N	2014-02-09 13:14:55.703	\N	\N
fb37211e-6d16-5a72-a593-04a7fe58623e	c5d7ced3-40d5-58c3-a093-de9982bb8402	07	KAB. MALANG	\N	2014-02-09 13:14:55.703	\N	\N
d3c79744-91e3-5763-8633-591bab308d14	c5d7ced3-40d5-58c3-a093-de9982bb8402	08	KAB. LUMAJANG	\N	2014-02-09 13:14:55.703	\N	\N
47a39ff6-3887-514f-8dae-0480d575d786	c5d7ced3-40d5-58c3-a093-de9982bb8402	09	KAB. JEMBER	\N	2014-02-09 13:14:55.703	\N	\N
41bf8d96-d5bd-54b9-acf7-9f5cf98a1728	c5d7ced3-40d5-58c3-a093-de9982bb8402	30	KOTA. KEDIRI	\N	2014-02-09 13:14:55.703	\N	\N
1edade44-24f6-5fe5-9fce-304bea00fdb7	c5d7ced3-40d5-58c3-a093-de9982bb8402	31	KOTA. BLITAR	\N	2014-02-09 13:14:55.703	\N	\N
0ef5a01f-5f33-540e-b314-634529fd6b97	c5d7ced3-40d5-58c3-a093-de9982bb8402	32	KOTA. MALANG	\N	2014-02-09 13:14:55.703	\N	\N
\.


--
-- Data for Name: kecamatan; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY kecamatan (id, kabupaten_id, kode, nama, createdby, createddate, updatedby, updateddate) FROM stdin;
6690ba99-0394-5203-9664-76b38de382ca	0ef5a01f-5f33-540e-b314-634529fd6b97	01	BLIMBING	\N	2014-02-09 13:21:43.984	\N	\N
fbd92311-1d31-507d-85b7-6aacc6db5dc1	0ef5a01f-5f33-540e-b314-634529fd6b97	02	KLOJEN	\N	2014-02-09 13:21:43.984	\N	\N
160c9c7f-fb34-5a5c-8604-920ec1f045b4	0ef5a01f-5f33-540e-b314-634529fd6b97	03	KEDUNGKANDANG	\N	2014-02-09 13:21:43.984	\N	\N
3202bed8-f512-5bd3-870e-f7cb39761c30	0ef5a01f-5f33-540e-b314-634529fd6b97	04	SUKUN	\N	2014-02-09 13:21:43.984	\N	\N
b71ed720-4481-5a27-bce4-5185c91f8cc0	0ef5a01f-5f33-540e-b314-634529fd6b97	05	LOWOKWARU	\N	2014-02-09 13:21:43.984	\N	2014-02-09 13:26:16.671
a0b56612-7ced-5b2e-afa4-a0f2aea44044	fb37211e-6d16-5a72-a593-04a7fe58623e	01	DONOMULYO	\N	2014-02-09 13:36:51.656	\N	\N
b16deddc-2bd4-5069-9f6b-f9fc4a2c6b5e	fb37211e-6d16-5a72-a593-04a7fe58623e	02	PAGAK	\N	2014-02-09 13:36:51.656	\N	\N
e9b8e445-2374-512b-b0b3-06da96f52c1b	fb37211e-6d16-5a72-a593-04a7fe58623e	03	BANTUR	\N	2014-02-09 13:36:51.656	\N	\N
44dcadd6-51b5-5a6a-94ac-a40ccce7a521	fb37211e-6d16-5a72-a593-04a7fe58623e	04	SUMBERMANJING WETAN	\N	2014-02-09 13:36:51.656	\N	\N
7da4c747-358e-5449-ae66-b4101fad76aa	fb37211e-6d16-5a72-a593-04a7fe58623e	05	DAMPIT	\N	2014-02-09 13:36:51.656	\N	\N
8a4993ed-bafa-5e0f-8881-1f131bbd77ea	fb37211e-6d16-5a72-a593-04a7fe58623e	06	AMPELGADING	\N	2014-02-09 13:36:51.656	\N	\N
978062c2-38bb-5a89-9193-928430a879b1	fb37211e-6d16-5a72-a593-04a7fe58623e	07	PONCOKUSUMO	\N	2014-02-09 13:36:51.656	\N	\N
f9d6625a-0d49-5413-8a7d-2dffbfcb9937	fb37211e-6d16-5a72-a593-04a7fe58623e	08	WAJAK	\N	2014-02-09 13:36:51.656	\N	\N
bcc750ab-35bd-5783-9006-f2be41cd6821	fb37211e-6d16-5a72-a593-04a7fe58623e	09	TUREN	\N	2014-02-09 13:36:51.656	\N	\N
dcaaa276-cf2d-56ef-982d-f398f3591065	fb37211e-6d16-5a72-a593-04a7fe58623e	10	GONDANGLEGI	\N	2014-02-09 13:36:51.656	\N	\N
4f600460-d043-576b-b72e-7fe0de6f3e08	fb37211e-6d16-5a72-a593-04a7fe58623e	11	KALIPARE	\N	2014-02-09 13:36:51.656	\N	\N
108ccb6f-0e86-57b6-baf1-ab1c4e4913a1	fb37211e-6d16-5a72-a593-04a7fe58623e	12	SUMBERPUCUNG	\N	2014-02-09 13:36:51.656	\N	\N
57add0bb-b375-5302-9bd2-6deca584f754	fb37211e-6d16-5a72-a593-04a7fe58623e	13	KEPANJEN	\N	2014-02-09 13:36:51.656	\N	\N
0c179f85-1ccb-5e56-b0f3-7937caf6b7c8	fb37211e-6d16-5a72-a593-04a7fe58623e	14	BULULAWANG	\N	2014-02-09 13:36:51.656	\N	\N
0e11a2c6-600a-5ee8-8d42-f3bd8bbf5b02	fb37211e-6d16-5a72-a593-04a7fe58623e	15	TAJINAN	\N	2014-02-09 13:36:51.656	\N	\N
4575d49b-5baf-526e-a344-a172c72d8dc8	fb37211e-6d16-5a72-a593-04a7fe58623e	16	TUMPANG	\N	2014-02-09 13:36:51.656	\N	\N
b8847b9b-e7e8-5d85-a5ba-b20b9b3c32fd	fb37211e-6d16-5a72-a593-04a7fe58623e	17	JABUNG	\N	2014-02-09 13:36:51.656	\N	\N
9ecf17fc-5e10-589e-bd3b-af51ca2a13f1	fb37211e-6d16-5a72-a593-04a7fe58623e	18	PAKIS	\N	2014-02-09 13:36:51.656	\N	\N
9ba28589-9ae9-57e7-af9c-0b7267d4e6d9	fb37211e-6d16-5a72-a593-04a7fe58623e	19	PAKISHAJI	\N	2014-02-09 13:36:51.656	\N	\N
593f8649-7fd6-59d5-af68-eb60ac72bee5	fb37211e-6d16-5a72-a593-04a7fe58623e	20	NGAJUNG	\N	2014-02-09 13:36:51.656	\N	\N
a0386026-dfcd-53ed-961e-6203091b86f9	fb37211e-6d16-5a72-a593-04a7fe58623e	21	WAGIR	\N	2014-02-09 13:36:51.656	\N	\N
8be3ac27-24b7-5524-a81d-ba8586d60fa6	fb37211e-6d16-5a72-a593-04a7fe58623e	22	DAU	\N	2014-02-09 13:36:51.656	\N	\N
fcb1f598-ee80-5492-bc02-e3f8c8b46ec5	fb37211e-6d16-5a72-a593-04a7fe58623e	23	KARANG PLOSO	\N	2014-02-09 13:36:51.656	\N	\N
6cb9b06f-fe2b-5e9b-9a34-a3c8187349b1	fb37211e-6d16-5a72-a593-04a7fe58623e	24	SINGOSARI	\N	2014-02-09 13:36:51.656	\N	\N
6f56280f-73fa-5a7a-a9da-3faded91d57a	fb37211e-6d16-5a72-a593-04a7fe58623e	25	LAWANG	\N	2014-02-09 13:36:51.656	\N	\N
6e5301ef-2f99-5dfe-ab2f-a8e7e1c64346	fb37211e-6d16-5a72-a593-04a7fe58623e	26	PUJON	\N	2014-02-09 13:36:51.656	\N	\N
872593c2-ea71-54e2-a8af-a83fc3b30614	fb37211e-6d16-5a72-a593-04a7fe58623e	27	NGANTUNG	\N	2014-02-09 13:36:51.656	\N	\N
351fc432-1d1a-586a-a4a0-d1ab65de2f53	fb37211e-6d16-5a72-a593-04a7fe58623e	28	KASEMBON	\N	2014-02-09 13:36:51.656	\N	\N
a119e8f5-2dd9-5ed1-9d3c-93c3ff5cbbcb	fb37211e-6d16-5a72-a593-04a7fe58623e	29	GEDONGAN	\N	2014-02-09 13:36:51.656	\N	\N
3989f737-cd15-5adb-8d58-e3ae9d968af4	fb37211e-6d16-5a72-a593-04a7fe58623e	30	TIRTOYUDO	\N	2014-02-09 13:36:51.656	\N	\N
eccec059-ff8f-5b87-ab30-f65c195bfe13	fb37211e-6d16-5a72-a593-04a7fe58623e	31	KROMENGAN	\N	2014-02-09 13:36:51.656	\N	\N
c579e567-c746-5c63-ad47-33152117e5a8	fb37211e-6d16-5a72-a593-04a7fe58623e	32	WONOSARI	\N	2014-02-09 13:36:51.656	\N	\N
8dba7dd7-4e29-5d5b-84c5-52b2fa15133a	fb37211e-6d16-5a72-a593-04a7fe58623e	33	PAGELARAN	\N	2014-02-09 13:36:51.656	\N	\N
\.


--
-- Data for Name: level_acls; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY level_acls (id, level_id, acl_id) FROM stdin;
\.


--
-- Data for Name: level_menus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY level_menus (id, level_id, menu_id) FROM stdin;
\.


--
-- Data for Name: levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY levels (id, name) FROM stdin;
\.


--
-- Data for Name: logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY logs (id, user_id, logsdate, actions) FROM stdin;
2d1d5fbe-c8a0-5494-b139-fac1f003c751	\N	2014-02-09 23:12:46.252794	create data on pilkada_event table with id 4105e8ef-29a1-5893-8103-cbd2c1e5fbaa
2d886f83-e95a-58b3-8c6f-c81fa0ec9bc2	\N	2014-02-11 21:13:58.91322	create data on calon table with id e88d703d-d9cd-5744-9c90-330bdf09c573
e665d6aa-336b-5111-bda7-b8ae14af1ae1	\N	2014-02-11 21:14:56.138096	create data on calon table with id f850a044-9d39-55ae-a8f5-803107c2fce4
8cdfdc1b-205c-59a9-8ab7-b45461e9b9e5	\N	2014-02-11 21:15:16.345261	create data on calon table with id 9ea1f78e-2cc6-54e6-b45c-02000f00f6e7
578ff715-5990-5fd1-adfb-9251cc7f22be	\N	2014-02-09 13:09:39.89	isi data on propinsi table with id e97b7f4b-679c-581f-9ac6-a2067960f17c
49e069b1-538f-5206-84c4-f5c53d29d006	\N	2014-02-09 13:09:39.89	isi data on propinsi table with id 1f779dfd-a17c-5b35-a5d4-978152323e0d
4f93ddd5-20bd-51e9-9f1c-fcdf42029b36	\N	2014-02-09 13:09:39.89	isi data on propinsi table with id c5d7ced3-40d5-58c3-a093-de9982bb8402
45b9bc17-cd15-5364-9157-a0a63cc5e63c	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id a7119ade-f30b-5c7e-bb50-20e51ab6e924
ac4b1b98-1d0b-51f5-ae4b-efaa7d4847bb	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id fb37211e-6d16-5a72-a593-04a7fe58623e
2972cd0e-6ac2-5736-9388-ee1de0dee07b	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id d3c79744-91e3-5763-8633-591bab308d14
78ab7e48-851a-5974-967d-467b922cf32b	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 47a39ff6-3887-514f-8dae-0480d575d786
75f37cc8-7bbd-5998-b553-0f21ac57f735	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 41bf8d96-d5bd-54b9-acf7-9f5cf98a1728
05f97a4e-a613-5d5e-998b-411357e9a995	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 1edade44-24f6-5fe5-9fce-304bea00fdb7
395ce7e3-ef6d-578a-99f6-f515699c7c0a	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 0ef5a01f-5f33-540e-b314-634529fd6b97
4746337f-ee10-5c35-b017-6541d961f3cc	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id 6690ba99-0394-5203-9664-76b38de382ca
9217381e-c098-58b7-9cde-1f47a765cba8	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id fbd92311-1d31-507d-85b7-6aacc6db5dc1
50c1b2da-4b6c-5d86-89ed-e8d8d72ca9d9	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id 160c9c7f-fb34-5a5c-8604-920ec1f045b4
b884be6c-6674-569e-aef9-80bbdaf8f49e	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id 3202bed8-f512-5bd3-870e-f7cb39761c30
f221f1b6-9969-5156-8791-391b61421d6a	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id b71ed720-4481-5a27-bce4-5185c91f8cc0
22cd65a2-77f5-5acc-82cd-3924854f14c6	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id a0b56612-7ced-5b2e-afa4-a0f2aea44044
1e4def9f-1c39-5702-bed6-45092b0a577e	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id b16deddc-2bd4-5069-9f6b-f9fc4a2c6b5e
1b7d9f74-cdb6-5b86-84ab-07c70c47b88a	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id e9b8e445-2374-512b-b0b3-06da96f52c1b
bd9b476b-4ae4-57ba-8c75-6c03cee1cac0	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 44dcadd6-51b5-5a6a-94ac-a40ccce7a521
fc2b93ed-ae39-55ff-857d-d72a9df43813	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 7da4c747-358e-5449-ae66-b4101fad76aa
3f792454-480a-54cf-aa1b-adeb176a6c9e	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 8a4993ed-bafa-5e0f-8881-1f131bbd77ea
22bd54e3-b40e-59b0-974d-b152dce31b59	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 978062c2-38bb-5a89-9193-928430a879b1
47f9db2d-ea07-5d5e-94e6-e5f7431593f7	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id f9d6625a-0d49-5413-8a7d-2dffbfcb9937
84350ec9-5961-5ddd-acd6-c6dd51bf9c9b	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id bcc750ab-35bd-5783-9006-f2be41cd6821
0d5050ed-ca55-5d3f-86fb-90717e8d038c	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id dcaaa276-cf2d-56ef-982d-f398f3591065
32624979-49ae-5de7-9f2d-8e02a77e3f69	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 4f600460-d043-576b-b72e-7fe0de6f3e08
d62e6c78-3e98-5bcf-9421-1703f9a52d84	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 108ccb6f-0e86-57b6-baf1-ab1c4e4913a1
8deda5c5-d446-5474-b6f3-37b8c31bf9b6	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 57add0bb-b375-5302-9bd2-6deca584f754
569b2962-e19f-576d-84c3-b66d9b8f4431	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 0c179f85-1ccb-5e56-b0f3-7937caf6b7c8
6ca799a2-8ae9-5fc9-ada6-b0b2ca909659	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 0e11a2c6-600a-5ee8-8d42-f3bd8bbf5b02
192e4c7b-f6b7-579e-aad6-7a575380d9d1	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 4575d49b-5baf-526e-a344-a172c72d8dc8
e3e28618-e31f-56d1-9b57-4e2ef9dc3819	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id b8847b9b-e7e8-5d85-a5ba-b20b9b3c32fd
ca5fd28e-b32c-5976-a623-397c38bc189f	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 9ecf17fc-5e10-589e-bd3b-af51ca2a13f1
fc731222-4a91-545d-962d-faf94411b95e	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 9ba28589-9ae9-57e7-af9c-0b7267d4e6d9
fb6ef3da-43f9-5267-a1ae-d873dae76437	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 593f8649-7fd6-59d5-af68-eb60ac72bee5
dc8d2373-ccaf-5389-a341-dedb6000677c	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id a0386026-dfcd-53ed-961e-6203091b86f9
3697fd5e-f48d-5236-b087-e97237978fd0	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 8be3ac27-24b7-5524-a81d-ba8586d60fa6
cdd8018e-60aa-5e45-9266-362298ec758f	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id fcb1f598-ee80-5492-bc02-e3f8c8b46ec5
78f3c02e-38ad-5b4a-bc56-8e2be4c95072	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 6cb9b06f-fe2b-5e9b-9a34-a3c8187349b1
51ad965f-084a-58b0-9afb-ee6749fd10b7	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 6f56280f-73fa-5a7a-a9da-3faded91d57a
1aedcb69-d936-5770-b2c3-4fad8be9dce7	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 6e5301ef-2f99-5dfe-ab2f-a8e7e1c64346
4842c933-2ff8-5f57-8c71-2d49ba1e8d47	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 872593c2-ea71-54e2-a8af-a83fc3b30614
11dd66cc-d087-5979-a7c2-92fb5c3b424c	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 351fc432-1d1a-586a-a4a0-d1ab65de2f53
71acc947-a392-5c99-b59a-2b6465ab4384	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id a119e8f5-2dd9-5ed1-9d3c-93c3ff5cbbcb
d3018c34-01eb-557a-959d-682a2dfbfbdd	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 3989f737-cd15-5adb-8d58-e3ae9d968af4
83279462-182f-52cd-9a79-c70fb8cfe105	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id eccec059-ff8f-5b87-ab30-f65c195bfe13
d31d9fd3-94a7-530c-836c-c950e737fb7c	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id c579e567-c746-5c63-ad47-33152117e5a8
493e8638-5d4b-50fa-90a4-72f8dc3992c4	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 8dba7dd7-4e29-5d5b-84c5-52b2fa15133a
01ed2f8a-6748-53fd-b49f-062cc9303301	\N	2014-02-09 13:54:47.578	create data on desa table with id 73d39be6-63cf-5408-b068-89cb98d806ed
5f57f628-a572-50c7-bc79-47e0efed6240	\N	2014-02-09 13:54:47.578	create data on desa table with id b807caab-26f0-5eca-a9f1-6f0e81d0f6c4
4cdaedab-fac9-5523-a17a-796dad5fc6e1	\N	2014-02-09 13:54:47.578	create data on desa table with id 979273aa-2433-5503-beab-db20fe1c521d
a4155681-c7d8-5960-b440-1cb33c53c726	\N	2014-02-09 13:54:47.578	create data on desa table with id 72b865b2-b818-5be7-951f-eb04d2432e21
3bb0480a-454e-5807-9963-4f5e4c15fa09	\N	2014-02-09 13:54:47.578	create data on desa table with id f0d83204-0372-50b3-abf7-536e2abbd66a
62a26af5-7a84-59a4-9177-de08ad8efec0	\N	2014-02-09 13:54:47.578	create data on desa table with id b621027a-d549-58a3-b29c-ea8f11728d16
1255202e-77d5-5327-a5de-4aec0043665d	\N	2014-02-09 13:54:47.578	create data on desa table with id ab3020d1-37c6-572f-8320-e159391ac2a8
3706ad23-cfc9-54b5-8d93-208f3a0d9c3d	\N	2014-02-09 13:54:47.578	create data on desa table with id 4e1d16ae-fcf6-5a49-894d-398b1b96f777
87703d8c-a0bf-503d-be2f-2f2dee5b1ab1	\N	2014-02-09 13:54:47.578	create data on desa table with id 8447b159-f515-53b4-bcd8-db7b59c87f93
d91d428d-837b-514b-9d29-29a284085bf8	\N	2014-02-09 13:54:47.578	create data on desa table with id 1bf91399-347d-5580-a49e-c16d924125f8
78b64e80-b2db-5a9a-98c2-46abf0dc11aa	\N	2014-02-09 13:54:47.578	create data on desa table with id 3cbd8998-c424-56aa-a773-74c17b176bbf
e7a3f1bf-4cd9-5adf-8f1e-dce4cb243d04	\N	2014-02-09 14:01:20.031	create data on desa table with id cff92b6d-5120-5bd6-ac6f-8819f67feabb
83f4a7a3-f2c9-59a8-b560-898f7e75888b	\N	2014-02-09 14:01:20.031	create data on desa table with id d32bf146-05f8-5588-aaaf-ad0615fca0e2
2af3db35-8c4b-5535-80c7-cbf84819a308	\N	2014-02-09 14:01:20.031	create data on desa table with id e7f8c503-9505-585a-a98f-9ad529e08154
4807493b-d125-5994-a15f-cfa82921362c	\N	2014-02-09 14:01:20.031	create data on desa table with id 9e838bbd-6a5b-5c19-870f-f47926ed1168
6bba6795-cc44-5bf6-8066-645bedb5c2ff	\N	2014-02-09 14:01:20.031	create data on desa table with id 26e4c87c-93e5-5e1d-856b-93f4836177a9
714d4a7f-88ec-5164-89f6-ffe96e47b9ae	\N	2014-02-09 14:01:20.031	create data on desa table with id 04dd178c-a00c-57e2-a0d1-241c545a2dd6
b007e691-e16a-505b-a0f3-72639748822e	\N	2014-02-09 14:01:20.031	create data on desa table with id cfdfd13c-e357-5359-acde-853e538e2455
529adfd3-0ed4-55f8-a0de-7c7fcd24eb44	\N	2014-02-09 14:01:20.031	create data on desa table with id 4f99719b-f66a-569a-b188-7b2cd44315c9
3e8fdaed-4dbe-5949-9299-9e73b1e3a61c	\N	2014-02-09 14:01:20.031	create data on desa table with id 8a7e7e46-b5d8-5f86-adc2-dfbc42898a22
6a27bc7b-dda0-5d55-b26b-f9cf38f46979	\N	2014-02-09 14:01:20.031	create data on desa table with id 928c7824-6116-5f8d-97a7-69cde1d72f92
08b99e35-bc76-5364-a289-4865f9008d1a	\N	2014-02-09 14:01:20.031	create data on desa table with id da909ac4-ad14-5d4d-9586-61ae468a9800
e39ad947-6245-5736-9e27-80436d9eaed2	\N	2014-02-09 14:07:48.64	create data on desa table with id f828604d-2010-5218-87e2-ae3e7f957cf0
777ad491-14ef-5c5f-87cc-0d7c34431d85	\N	2014-02-09 14:07:48.64	create data on desa table with id e75e0f3a-24f7-5960-97d9-cfdec9dfc487
72ff2eff-c958-54bb-ac8c-a8e0d90df67d	\N	2014-02-09 14:07:48.64	create data on desa table with id 0dfd5d6e-5fc5-5717-b99f-5d60ca97a7cc
05b31332-366b-5c73-b02c-c06996a10c94	\N	2014-02-09 14:07:48.64	create data on desa table with id d4afbb5d-6a15-56a4-9875-c66c6f0b34f9
23789a24-35ff-5031-b920-c8f428446554	\N	2014-02-09 14:07:48.64	create data on desa table with id 18fb4c09-ea9f-597c-a84d-ae3c7c24e7ba
91c2059a-b45b-5237-8152-496307302eb8	\N	2014-02-09 14:07:48.64	create data on desa table with id b7353ef1-07b1-59a3-a463-e9ed78a8edeb
6e8c9b66-4bb6-55a6-afd2-da071b4f3d6c	\N	2014-02-09 14:07:48.64	create data on desa table with id d234ab1a-2cf2-5857-b8b6-d8512500b304
6e24e788-e57d-5352-acb2-d0aedfebf602	\N	2014-02-09 14:07:48.64	create data on desa table with id 870e77c5-7f5f-595e-a7f1-11f28ed51982
ec595f9b-a8c9-5008-ad64-1ab203b0443b	\N	2014-02-09 14:07:48.64	create data on desa table with id 9b100053-b809-5cca-836a-d12ce14aca84
ca5a84bb-7b2f-5a3e-ab72-9939bac89529	\N	2014-02-09 14:07:48.64	create data on desa table with id 25ff1ca0-9e6a-58f6-8dc2-fad72e0cc581
96a65f63-6a2f-5448-9230-b8df3b869593	\N	2014-02-09 14:07:48.64	create data on desa table with id acbc14d0-5d4a-5540-bc59-457591795af5
05e59c07-cbd9-5aad-85d8-2baeb120703c	\N	2014-02-09 14:07:48.64	create data on desa table with id bf3c3b68-5586-517d-9280-bd50f49352d8
e52114a0-ab22-5aee-83a8-6f1b0239c35a	\N	2014-02-09 14:17:57.25	create data on desa table with id 2a2ebca2-63e4-56ef-abfa-8a57e35cf454
2463c38b-f79c-506f-8fda-67eee32fc3eb	\N	2014-02-09 14:17:57.25	create data on desa table with id e1b28d35-ee2c-5cb0-82b1-c9ebb48fb5e8
6356d17e-9490-54c7-847c-1e2bad2cc85c	\N	2014-02-09 14:17:57.25	create data on desa table with id 44c89a8e-9451-5cac-9384-de9f458cf68e
fbd1e0a3-71dd-5f55-8b27-23fb7eda1f45	\N	2014-02-09 14:17:57.25	create data on desa table with id a4a80b21-0d10-5017-869d-a2e14ca09225
217b6c4b-3d13-5fc0-bd4c-d395ba2e97d3	\N	2014-02-09 14:17:57.25	create data on desa table with id f5fe215e-1eaf-55f2-a141-5ad8c9686af1
535a1a90-81ee-5521-bbff-9df4622d8459	\N	2014-02-09 14:17:57.25	create data on desa table with id 73a54677-5bff-513f-a154-20d2517c94bf
8df1bbe8-46dc-53c1-9013-3ef4119a41f3	\N	2014-02-09 14:17:57.25	create data on desa table with id 0ee44675-a474-5fde-bfde-a505a7a75331
58a0cee4-b567-57e1-ac6f-34560e104135	\N	2014-02-09 14:17:57.25	create data on desa table with id 79e63a25-93d1-5aba-b771-d6288768641d
b0fab4fd-792e-5532-85d3-a538221f0fc0	\N	2014-02-09 14:17:57.25	create data on desa table with id 71a28213-685f-5746-8349-8f0a35f3f599
345a392e-30c2-5644-af64-cf6a5bacca78	\N	2014-02-09 14:17:57.25	create data on desa table with id 3f9526e6-42ac-572d-9ecc-129e8194d865
a4c619bc-ff45-5f1a-87cb-1b2a8196ebdb	\N	2014-02-09 14:17:57.25	create data on desa table with id 768ef350-5fc3-575a-afc5-42a0b5dc064e
3347e82a-de90-556e-a099-246cf49dd2de	\N	2014-02-09 14:22:07.5	create data on desa table with id 9746f9bf-b155-5976-9e30-753f6dd05b31
7040fdad-4e22-584e-9c53-8deb9263389b	\N	2014-02-09 14:22:07.5	create data on desa table with id b3b02c61-851c-5065-b577-09f6bfb9a4a1
82323a3f-2261-59d3-a0d6-00826d55d424	\N	2014-02-09 14:22:07.5	create data on desa table with id 4fd907f1-2e04-5d6c-aae1-b2fdb3e50a97
462ac7a2-979c-55ca-aa7a-59e83e71258b	\N	2014-02-09 14:22:07.5	create data on desa table with id 6b24f3ea-ea14-5db4-9c59-40cda635ebce
4b20c51c-4e1a-5787-9bbc-3cffcb2cc2be	\N	2014-02-09 14:22:07.5	create data on desa table with id a078c020-7c4e-57e2-bed9-ad06c93eca92
8065845b-1783-5039-a66f-60cc00cd7df5	\N	2014-02-09 14:22:07.5	create data on desa table with id 4fa63681-22ae-56f3-9688-d3f6532b42ce
2c0fa058-56db-53d4-9dd6-f761cf9abcd4	\N	2014-02-09 14:22:07.5	create data on desa table with id 39a238d2-ec7c-5d17-83c1-5bc399101720
cab39403-70c1-5a49-95b9-daea689b9bdb	\N	2014-02-09 14:22:07.5	create data on desa table with id 1833da32-04cb-596c-8293-a2b73f4db663
82556b35-bfe4-5729-93d5-582a7e9b6b40	\N	2014-02-09 14:22:07.5	create data on desa table with id 88798e68-e574-5794-adde-0af2740f836d
2137cb0f-1788-52f1-8d9e-763fb5f10512	\N	2014-02-09 14:22:07.5	create data on desa table with id adc79868-75c9-510b-b27a-206427ec0e2e
af4870fc-0c2b-5c7d-9cd2-820424fea4cf	\N	2014-02-09 14:22:07.5	create data on desa table with id 7b8a4f81-c010-582c-aaf0-92253ff1f138
18fa0638-2124-57b4-96e4-5d438f96285e	\N	2014-02-09 14:22:07.5	create data on desa table with id 461e10c9-7041-593e-8b78-01843dbfd9bb
e25ade8d-4b9e-599e-8b91-807cecf55b0b	\N	2014-02-09 13:09:39.89	isi data on propinsi table with id e97b7f4b-679c-581f-9ac6-a2067960f17c
e4c08430-75a8-5a24-a21c-dc5ed6502e6f	\N	2014-02-09 13:09:39.89	isi data on propinsi table with id 1f779dfd-a17c-5b35-a5d4-978152323e0d
b5d247be-bc92-5412-929a-f25b67739918	\N	2014-02-09 13:09:39.89	isi data on propinsi table with id c5d7ced3-40d5-58c3-a093-de9982bb8402
3cd428eb-d19b-5d25-aefa-40769063c88a	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id a7119ade-f30b-5c7e-bb50-20e51ab6e924
1d39c816-acbf-5d70-b401-ba449fe6eb15	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id fb37211e-6d16-5a72-a593-04a7fe58623e
7ddfcbcb-d2e9-57e7-ab80-df44e4984012	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id d3c79744-91e3-5763-8633-591bab308d14
a9c2c592-4fc7-5b08-867b-0dc7b6513273	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 47a39ff6-3887-514f-8dae-0480d575d786
bedf45a2-b0d2-5fa2-841f-6b289e290612	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 41bf8d96-d5bd-54b9-acf7-9f5cf98a1728
34528b97-bcd8-5f8c-894f-f2d840dfe6cb	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 1edade44-24f6-5fe5-9fce-304bea00fdb7
ae573cee-0aea-52e8-91d9-c860d00e2617	\N	2014-02-09 13:14:55.703	create data on kabupaten table with id 0ef5a01f-5f33-540e-b314-634529fd6b97
3fb45f4c-a35c-5138-9a81-1d96119489fa	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id 6690ba99-0394-5203-9664-76b38de382ca
a81b9721-f165-599a-9bbc-7f358427ff95	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id fbd92311-1d31-507d-85b7-6aacc6db5dc1
76b413f7-930e-558e-a131-505dbcb51c78	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id 160c9c7f-fb34-5a5c-8604-920ec1f045b4
e1f98d12-5825-5943-a035-af548ae1b606	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id 3202bed8-f512-5bd3-870e-f7cb39761c30
2772c40e-d044-5ad7-9049-b8329d9e7aa0	\N	2014-02-09 13:21:43.984	create data on kecamatan table with id b71ed720-4481-5a27-bce4-5185c91f8cc0
756b5b2a-fccd-5e7a-a639-70558f38ec4c	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id a0b56612-7ced-5b2e-afa4-a0f2aea44044
735c4d0d-8de2-5083-af37-e3b4475fd73b	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id b16deddc-2bd4-5069-9f6b-f9fc4a2c6b5e
f2b832e5-3a58-5ac0-9a92-e490ee85fe41	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id e9b8e445-2374-512b-b0b3-06da96f52c1b
f323be95-33d2-561c-99f8-2f3ea198d712	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 44dcadd6-51b5-5a6a-94ac-a40ccce7a521
8991384b-c6a7-59a6-a2cd-0c1cc03cdced	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 7da4c747-358e-5449-ae66-b4101fad76aa
caf781ad-993f-582a-a79e-ee291fce6b13	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 8a4993ed-bafa-5e0f-8881-1f131bbd77ea
24dad0ca-b257-5d2a-9a30-b70b33a4730a	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 978062c2-38bb-5a89-9193-928430a879b1
27c42517-1f08-51ca-8875-1942a3ec03f8	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id f9d6625a-0d49-5413-8a7d-2dffbfcb9937
bf819ac3-37eb-5e8a-a1c4-01c3f12e39b4	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id bcc750ab-35bd-5783-9006-f2be41cd6821
85c789a8-d5f6-52f9-83b6-4ba8fa69eff8	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id dcaaa276-cf2d-56ef-982d-f398f3591065
ce9039b6-64b4-53c0-b7b4-54a3b5e6b8f3	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 4f600460-d043-576b-b72e-7fe0de6f3e08
ea92b858-9133-5b99-8bba-9d3c4a21d836	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 108ccb6f-0e86-57b6-baf1-ab1c4e4913a1
31ebb5d8-b090-551f-a24c-801798727de6	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 57add0bb-b375-5302-9bd2-6deca584f754
04c5fcae-8395-5b9d-9de1-1e97b791b7b6	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 0c179f85-1ccb-5e56-b0f3-7937caf6b7c8
24e9a53a-4bd8-5049-b78d-7cbcdb232c55	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 0e11a2c6-600a-5ee8-8d42-f3bd8bbf5b02
567fc95f-6d66-5c76-af05-89332724d8c9	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 4575d49b-5baf-526e-a344-a172c72d8dc8
fc217fe9-29cc-55ba-a5bb-c30f8b2fbd4f	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id b8847b9b-e7e8-5d85-a5ba-b20b9b3c32fd
0d04c712-7641-5fde-ab7f-259f4bd2214f	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 9ecf17fc-5e10-589e-bd3b-af51ca2a13f1
241154d8-f6ee-5a82-9d55-af3e5071951d	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 9ba28589-9ae9-57e7-af9c-0b7267d4e6d9
2d61716a-cbbb-5272-ab78-17d4b265182f	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 593f8649-7fd6-59d5-af68-eb60ac72bee5
49bc857b-5b2f-51b0-b244-44995608d5a7	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id a0386026-dfcd-53ed-961e-6203091b86f9
5ee8cdbe-51f0-5849-86ec-80eb1a7870eb	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 8be3ac27-24b7-5524-a81d-ba8586d60fa6
826b33ed-5fad-5789-81dd-ea64cb695d14	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id fcb1f598-ee80-5492-bc02-e3f8c8b46ec5
67ecd68d-034b-5509-8b3a-c6e7134b46de	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 6cb9b06f-fe2b-5e9b-9a34-a3c8187349b1
ef298c99-90ed-555a-8599-857e10f60992	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 6f56280f-73fa-5a7a-a9da-3faded91d57a
9d3d4c31-2c70-595d-a373-cdc5bceb4a90	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 6e5301ef-2f99-5dfe-ab2f-a8e7e1c64346
340c844f-5ccc-5d95-a94a-4129b56000bf	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 872593c2-ea71-54e2-a8af-a83fc3b30614
1a7af61f-1276-5d8a-8ef4-f41d58b1e095	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 351fc432-1d1a-586a-a4a0-d1ab65de2f53
27fafd00-55af-5e1d-bbe0-146ca7e5474d	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id a119e8f5-2dd9-5ed1-9d3c-93c3ff5cbbcb
4cf13013-bd56-5955-836d-7de2057c44bc	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 3989f737-cd15-5adb-8d58-e3ae9d968af4
4b957b93-48a5-5d75-aa02-91a7486291be	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id eccec059-ff8f-5b87-ab30-f65c195bfe13
0fd1ac2d-6cf5-5fa0-bbdd-b5e52efbfa49	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id c579e567-c746-5c63-ad47-33152117e5a8
be5ec405-0ce8-5432-bd1e-7bdd73737559	\N	2014-02-09 13:36:51.656	create data on kecamatan table with id 8dba7dd7-4e29-5d5b-84c5-52b2fa15133a
576b9b47-0af5-54ad-9037-8a116d69cf36	\N	2014-02-09 13:54:47.578	create data on desa table with id 73d39be6-63cf-5408-b068-89cb98d806ed
44e1ae6b-7a31-54b9-9bfe-065f185aacfa	\N	2014-02-09 13:54:47.578	create data on desa table with id b807caab-26f0-5eca-a9f1-6f0e81d0f6c4
9e8e4a7b-2680-5d7b-b9cb-93a257c14400	\N	2014-02-09 13:54:47.578	create data on desa table with id 979273aa-2433-5503-beab-db20fe1c521d
f83e37c1-2554-5d9c-8d90-5be5a027ebad	\N	2014-02-09 13:54:47.578	create data on desa table with id 72b865b2-b818-5be7-951f-eb04d2432e21
75ef0b0c-9494-51db-9a8f-85d5c6dba69b	\N	2014-02-09 13:54:47.578	create data on desa table with id f0d83204-0372-50b3-abf7-536e2abbd66a
665b5d92-8b5b-50aa-b7a7-3fffb6d72571	\N	2014-02-09 13:54:47.578	create data on desa table with id b621027a-d549-58a3-b29c-ea8f11728d16
901a9a2d-5a0a-5904-aced-4d6c03fce653	\N	2014-02-09 13:54:47.578	create data on desa table with id ab3020d1-37c6-572f-8320-e159391ac2a8
ebb97bac-f7b1-59ee-a29b-bd90881758b1	\N	2014-02-09 13:54:47.578	create data on desa table with id 4e1d16ae-fcf6-5a49-894d-398b1b96f777
1cb8a8eb-3c3b-52ed-90c9-552bea8b4859	\N	2014-02-09 13:54:47.578	create data on desa table with id 8447b159-f515-53b4-bcd8-db7b59c87f93
51938424-4260-5a05-ab52-7db72a1f4410	\N	2014-02-09 13:54:47.578	create data on desa table with id 1bf91399-347d-5580-a49e-c16d924125f8
4570372b-aef7-558f-9ada-0fefc915df65	\N	2014-02-09 13:54:47.578	create data on desa table with id 3cbd8998-c424-56aa-a773-74c17b176bbf
82a91f67-32eb-5184-9e5e-d9b660507447	\N	2014-02-09 14:01:20.031	create data on desa table with id cff92b6d-5120-5bd6-ac6f-8819f67feabb
fce4d53e-3686-548f-aa43-191f85a372ef	\N	2014-02-09 14:01:20.031	create data on desa table with id d32bf146-05f8-5588-aaaf-ad0615fca0e2
3ba2790d-55d0-56ce-81bb-ac788e433d64	\N	2014-02-09 14:01:20.031	create data on desa table with id e7f8c503-9505-585a-a98f-9ad529e08154
ae566abc-44fe-5e36-8a0d-0cff1c91f960	\N	2014-02-09 14:01:20.031	create data on desa table with id 9e838bbd-6a5b-5c19-870f-f47926ed1168
eea40fc8-0382-5dd8-815d-d15436707523	\N	2014-02-09 14:01:20.031	create data on desa table with id 26e4c87c-93e5-5e1d-856b-93f4836177a9
e8df2ab1-cdf2-5eb0-afe3-43beba0f3313	\N	2014-02-09 14:01:20.031	create data on desa table with id 04dd178c-a00c-57e2-a0d1-241c545a2dd6
121b1a9a-e4fe-5399-9250-bfc801ee98b6	\N	2014-02-09 14:01:20.031	create data on desa table with id cfdfd13c-e357-5359-acde-853e538e2455
808c9389-7b01-5691-aeb3-3ea15f422121	\N	2014-02-09 14:01:20.031	create data on desa table with id 4f99719b-f66a-569a-b188-7b2cd44315c9
1d24e4a0-da14-5a17-bdc2-ae2b9861e0e3	\N	2014-02-09 14:01:20.031	create data on desa table with id 8a7e7e46-b5d8-5f86-adc2-dfbc42898a22
cfdc03e8-1546-5ebc-b22b-27b05210aad5	\N	2014-02-09 14:01:20.031	create data on desa table with id 928c7824-6116-5f8d-97a7-69cde1d72f92
7a3dbeee-3341-54cb-a50d-d875ad185689	\N	2014-02-09 14:01:20.031	create data on desa table with id da909ac4-ad14-5d4d-9586-61ae468a9800
17bbfc7f-64e0-549e-9ab7-9a9d3752f782	\N	2014-02-09 14:07:48.64	create data on desa table with id f828604d-2010-5218-87e2-ae3e7f957cf0
33bfab45-0646-5f9a-af45-2e2b6159abba	\N	2014-02-09 14:07:48.64	create data on desa table with id e75e0f3a-24f7-5960-97d9-cfdec9dfc487
188948bb-5160-5041-a937-9786149af740	\N	2014-02-09 14:07:48.64	create data on desa table with id 0dfd5d6e-5fc5-5717-b99f-5d60ca97a7cc
6b3a71f4-fe07-559a-84c7-127b2f2fc716	\N	2014-02-09 14:07:48.64	create data on desa table with id d4afbb5d-6a15-56a4-9875-c66c6f0b34f9
2e8e45c0-e8f4-5e53-8c0f-b57e02afb5e6	\N	2014-02-09 14:07:48.64	create data on desa table with id 18fb4c09-ea9f-597c-a84d-ae3c7c24e7ba
ed3eb7b3-8115-5276-b7b5-64dba24822bd	\N	2014-02-09 14:07:48.64	create data on desa table with id b7353ef1-07b1-59a3-a463-e9ed78a8edeb
3a7b4475-7f98-514a-bee4-cff048e1430f	\N	2014-02-09 14:07:48.64	create data on desa table with id d234ab1a-2cf2-5857-b8b6-d8512500b304
392fe1e9-c23c-5dd5-9f64-c0f13d7d004a	\N	2014-02-09 14:07:48.64	create data on desa table with id 870e77c5-7f5f-595e-a7f1-11f28ed51982
1cd66de3-d15f-512c-a81c-7b3fc0af9e99	\N	2014-02-09 14:07:48.64	create data on desa table with id 9b100053-b809-5cca-836a-d12ce14aca84
16729fbd-b2cc-5cf6-afa3-88b06e2db355	\N	2014-02-09 14:07:48.64	create data on desa table with id 25ff1ca0-9e6a-58f6-8dc2-fad72e0cc581
54cc8096-f32f-5b08-b43e-6b774a870dba	\N	2014-02-09 14:07:48.64	create data on desa table with id acbc14d0-5d4a-5540-bc59-457591795af5
1b788e71-a460-59ed-89af-8de09b5b96ae	\N	2014-02-09 14:07:48.64	create data on desa table with id bf3c3b68-5586-517d-9280-bd50f49352d8
e4ba8c17-96d6-5814-995f-acc11c5c4e84	\N	2014-02-09 14:17:57.25	create data on desa table with id 2a2ebca2-63e4-56ef-abfa-8a57e35cf454
fcfd8563-f0fe-5069-af85-fdc230581aa2	\N	2014-02-09 14:17:57.25	create data on desa table with id e1b28d35-ee2c-5cb0-82b1-c9ebb48fb5e8
607d3ca5-b3a6-5906-956b-22b14397ac31	\N	2014-02-09 14:17:57.25	create data on desa table with id 44c89a8e-9451-5cac-9384-de9f458cf68e
c0ff11f2-3244-5730-b5ca-728ffc1b2c4e	\N	2014-02-09 14:17:57.25	create data on desa table with id a4a80b21-0d10-5017-869d-a2e14ca09225
6d8aff41-13bb-54f8-b562-42a93d56cad8	\N	2014-02-09 14:17:57.25	create data on desa table with id f5fe215e-1eaf-55f2-a141-5ad8c9686af1
5fe6bf60-c04a-57e5-a866-257e5bb0ae9f	\N	2014-02-09 14:17:57.25	create data on desa table with id 73a54677-5bff-513f-a154-20d2517c94bf
33fd6fc7-824b-5789-bd94-98b6c4b0ac3e	\N	2014-02-09 14:17:57.25	create data on desa table with id 0ee44675-a474-5fde-bfde-a505a7a75331
b460c5e7-c5a1-5c95-9253-22c9251a73ac	\N	2014-02-09 14:17:57.25	create data on desa table with id 79e63a25-93d1-5aba-b771-d6288768641d
bf21b539-49c0-5d46-a655-f3dec735f1e3	\N	2014-02-09 14:17:57.25	create data on desa table with id 71a28213-685f-5746-8349-8f0a35f3f599
6aa9782a-7b13-5fbb-bb2c-5a255bc3294c	\N	2014-02-09 14:17:57.25	create data on desa table with id 3f9526e6-42ac-572d-9ecc-129e8194d865
fa0a792d-42ea-59c6-a3b0-81567c9ff2cf	\N	2014-02-09 14:17:57.25	create data on desa table with id 768ef350-5fc3-575a-afc5-42a0b5dc064e
e2e1c332-1910-5455-b977-5e0065b9e6d7	\N	2014-02-09 14:22:07.5	create data on desa table with id 9746f9bf-b155-5976-9e30-753f6dd05b31
50d521c2-b120-53ff-a281-31c72041ce11	\N	2014-02-09 14:22:07.5	create data on desa table with id b3b02c61-851c-5065-b577-09f6bfb9a4a1
3927b49a-a0e6-52d9-8ed4-3f6945a4d533	\N	2014-02-09 14:22:07.5	create data on desa table with id 4fd907f1-2e04-5d6c-aae1-b2fdb3e50a97
b7dd2024-8721-571b-9a66-0f9039cb31ff	\N	2014-02-09 14:22:07.5	create data on desa table with id 6b24f3ea-ea14-5db4-9c59-40cda635ebce
215023f9-ca48-5065-b172-097f1fd5fbe2	\N	2014-02-09 14:22:07.5	create data on desa table with id a078c020-7c4e-57e2-bed9-ad06c93eca92
95a2e9bd-7ef8-58b2-9ad7-fcb407552a9d	\N	2014-02-09 14:22:07.5	create data on desa table with id 4fa63681-22ae-56f3-9688-d3f6532b42ce
979e9473-c456-54e5-aa18-86af6eec94ee	\N	2014-02-09 14:22:07.5	create data on desa table with id 39a238d2-ec7c-5d17-83c1-5bc399101720
81ccc28f-02b6-59ba-8944-8075255ad294	\N	2014-02-09 14:22:07.5	create data on desa table with id 1833da32-04cb-596c-8293-a2b73f4db663
e0dadb99-a361-5fd7-b6ef-7d279306808d	\N	2014-02-09 14:22:07.5	create data on desa table with id 88798e68-e574-5794-adde-0af2740f836d
8815fafb-9092-5c00-8fbf-6eb436a65810	\N	2014-02-09 14:22:07.5	create data on desa table with id adc79868-75c9-510b-b27a-206427ec0e2e
2bed43cd-9ab0-50e4-9989-999f48a40ce0	\N	2014-02-09 14:22:07.5	create data on desa table with id 7b8a4f81-c010-582c-aaf0-92253ff1f138
f819004c-2808-5d17-8e25-0225e120ea57	\N	2014-02-09 14:22:07.5	create data on desa table with id 461e10c9-7041-593e-8b78-01843dbfd9bb
2ba0b2ee-5931-5854-96a9-dddeb1342b9d	\N	2014-02-09 23:12:46.252794	create data on pilkada_event table with id 4105e8ef-29a1-5893-8103-cbd2c1e5fbaa
3e52a767-0191-584b-b086-fd48a7cb1f9a	\N	2014-02-10 10:09:30.447586	create data on tps table with id fe1487a8-9ef1-5dfa-b268-46db37e2d562
6a652571-3cec-5037-a649-0960f913589c	\N	2014-02-10 10:09:30.447586	create data on tps table with id aa2e1406-3081-5108-9168-e4a6e01c2a57
4d22769a-c0c4-5268-af7e-a330453d49ff	\N	2014-02-10 10:09:30.447586	create data on tps table with id bf3a4e97-7ca1-5248-9a12-5345a70907be
9a54a54e-4e31-585c-a472-e34927a5f39a	\N	2014-02-10 10:09:30.447586	create data on tps table with id 2ec4286a-2c9f-5307-a8e1-0cac31a30b9d
3e89ff44-07b0-57ee-801f-68590e5cfc74	\N	2014-02-10 10:09:30.447586	create data on tps table with id 49d1abb9-e62e-5bfd-af35-970be32c8b75
6310b478-f9a5-5bf4-8390-8d8237a79f65	\N	2014-02-10 10:09:30.447586	create data on tps table with id 590eabe9-c2bf-5ad2-ac37-e5b81ac4d91f
6c63a656-aa27-56f8-a5ac-c2ff122839a5	\N	2014-02-10 10:09:30.447586	create data on tps table with id 29ba6d97-6205-575a-89a3-36cb497b007a
85d87948-3421-5634-9e62-33f997592579	\N	2014-02-10 10:09:30.447586	create data on tps table with id 9d5e18b9-1db8-51da-bfe4-ed8f11b0ad22
f1f64308-3061-5943-94f9-c1f37be1a6f4	\N	2014-02-10 10:09:30.447586	create data on tps table with id a8a31cfa-999a-5a60-8edc-250bfef2fa38
c68f08aa-0f0f-5d2a-8597-d343ab96991c	\N	2014-02-10 10:09:30.447586	create data on tps table with id 369d1ae2-7e85-5dd3-ba30-33f5ef2ebab8
b66d4446-8559-57f2-ac28-c5ac823b7a01	\N	2014-02-10 10:09:30.447586	create data on tps table with id 4260e08b-9afb-540f-8092-e04b2ff97518
d9fdc706-d778-50f8-bf34-66870d0087e2	\N	2014-02-10 10:09:30.447586	create data on tps table with id d2c7e16d-cf65-5e8b-ab9e-00f568a2432b
0fd83990-0b9c-5553-add7-eedb501983e5	\N	2014-02-10 10:09:30.447586	create data on tps table with id 914d5787-56cc-5c82-8476-535ef5e16c99
37f2b396-ec9f-5b30-a559-181a52bc4946	\N	2014-02-10 10:09:30.447586	create data on tps table with id c47f1cc6-f103-54bf-b2f0-abe6972a76bd
39f67f3b-2064-5c3b-bcd6-2dfb635410a9	\N	2014-02-10 10:09:30.447586	create data on tps table with id 5935ba62-23c0-5cf5-bc1e-dedd1362b032
332b3481-39f2-5c41-935a-ceb463480c7a	\N	2014-02-10 10:09:30.447586	create data on tps table with id 16bdd40a-575f-55e2-a4dd-dfbd6bd747a1
259dd5d3-cca7-5388-a45f-c74edd1e2d5c	\N	2014-02-10 10:09:30.447586	create data on tps table with id 3100369d-bfc4-57be-9c7a-9d37d9253565
d90abf29-091a-54df-885d-536ea7aeb4bf	\N	2014-02-10 10:09:30.447586	create data on tps table with id 8ddbe9f8-64c9-59d5-9c35-c20993b4d420
ad15e89b-d8d0-5718-ac59-f0ecc6517a14	\N	2014-02-10 10:09:30.447586	create data on tps table with id b1261d02-1bae-5443-83a3-f0fc99ecdcb3
69acb7cc-99e5-575a-8b98-99588b8857b3	\N	2014-02-10 10:09:30.447586	create data on tps table with id bd6bf075-5f54-5c6d-b5fc-c0ea051e2dfc
9791d4d2-012d-54d5-b594-e9b25d532876	\N	2014-02-10 10:09:30.447586	create data on tps table with id f4fe392d-7ff4-5d4f-91ee-18017e98f454
6a7a5a4e-56bf-5a9a-a0d1-f30e24683919	\N	2014-02-10 10:09:30.447586	create data on tps table with id 530a7ef0-e308-56d3-ad29-aa20c86ad2b6
c67169dd-82d5-55da-8aac-c531c29ff39b	\N	2014-02-10 10:09:30.447586	create data on tps table with id fb6443fb-f2dd-5f08-a75b-a12d839606a3
2238604f-db18-578c-b00c-21c6a7fa7aee	\N	2014-02-10 10:09:30.447586	create data on tps table with id e2915db2-a344-5f7f-8c74-97a4d6bc6824
24fabf75-1c17-5086-a0dd-1ed57e399b3c	\N	2014-02-10 10:09:30.447586	create data on tps table with id 961f68c1-eabc-5871-bf12-c6f55cb2ad40
854b6337-94b0-5a02-b248-8d2c793cbe8d	\N	2014-02-10 10:09:30.447586	create data on tps table with id dd29b256-0516-548c-b934-a9b2650b0c07
43708e38-13c2-5b44-acd8-b6714d5205d3	\N	2014-02-10 10:09:30.447586	create data on tps table with id 1b4bfe55-23cb-5cb1-809d-d3fb1a1b8454
9b768dba-d199-5937-8688-2765ee762c90	\N	2014-02-10 10:09:30.447586	create data on tps table with id 0752520c-e1ca-530c-b9d2-a1dc34f5fa47
7e5b352d-0721-512a-9141-e9563b6fa307	\N	2014-02-10 10:09:30.447586	create data on tps table with id a4290489-6d12-52bd-90d2-729faed8d3f5
55d395a1-2876-567e-b1ee-c90db8d3653e	\N	2014-02-10 10:09:30.447586	create data on tps table with id 35078935-7d83-5e57-bb58-44761cee1dd4
cfb2217d-4280-50d5-bd20-1496a6dad41a	\N	2014-02-10 10:09:30.447586	create data on tps table with id fd27feb1-f1b1-59db-ad24-a557e233e553
5a2c9cc6-f9c9-54f8-89a7-a5a052bd972f	\N	2014-02-10 10:09:30.447586	create data on tps table with id 51fad67b-4803-58c6-a077-cc96874182b0
5bd08ea2-3b15-5cdf-9207-e7403eb4ea92	\N	2014-02-10 10:09:30.447586	create data on tps table with id 308bef5d-a40b-5700-92a9-818eba915802
9deeb9a2-bc09-5ba0-87cc-923198189126	\N	2014-02-10 10:09:30.447586	create data on tps table with id c3503e99-b122-5951-b6da-83fd77e55d19
c370b57b-3ca2-58d2-8b8a-2fbad8cae622	\N	2014-02-10 10:09:30.447586	create data on tps table with id 846da618-0f41-5f3a-8527-ff268c3f0af3
def2ba00-163b-5106-a5a6-8b00e6493b10	\N	2014-02-10 10:09:30.447586	create data on tps table with id 0d7b14ad-2947-598d-91d1-d38f18f8b5e3
fdf704c6-9f92-5300-8957-28719939a2fd	\N	2014-02-10 10:09:30.447586	create data on tps table with id 47dc3078-099c-50f3-b9c4-9bbc2c3aec76
74dbdff1-6d5d-562e-b6f0-d9671347f187	\N	2014-02-10 10:09:30.447586	create data on tps table with id 7401caa6-c84d-5220-90af-0ac85ff6da19
b62fcdc9-40ba-5fa1-9719-cf0b72191870	\N	2014-02-10 10:09:30.447586	create data on tps table with id 4e99fc06-3e21-55c3-abda-d5b6b4eeb17b
02c7c4d7-c7d5-5806-b030-2da43f5f8bd7	\N	2014-02-10 10:09:30.447586	create data on tps table with id b62ee47e-7873-5787-b6a6-51b61f77d2a0
f9e0a97c-2e5e-543d-9a34-008121ba20c8	\N	2014-02-10 10:09:30.447586	create data on tps table with id 293f1da3-5159-5174-9122-a5b3ab399ebc
217c86a9-e327-5775-bb0d-93e78bb82e46	\N	2014-02-10 10:09:30.447586	create data on tps table with id b2ae3ff0-0421-5574-a1b4-1130f99e85a3
ecf6bb69-b9e6-5f33-b0e8-7dd6393cd349	\N	2014-02-10 10:09:30.447586	create data on tps table with id 3433a3bd-e332-5e9f-b5a1-38390c1b10a8
2778eecd-0e87-591b-81de-dd36896bf876	\N	2014-02-10 10:09:30.447586	create data on tps table with id 5b4cdebf-524f-5bcd-bcea-e4cbac164bdb
7caa9969-b7f1-5d69-b47b-a5ccc8ff2647	\N	2014-02-10 10:09:30.447586	create data on tps table with id 56e4c5f5-89c3-5afe-9da9-774412a29997
b04a1f5a-d8ae-5459-8037-2cc190d64c72	\N	2014-02-10 10:09:30.447586	create data on tps table with id 3ee57430-6c15-5b00-a0ab-bdcdec61e46d
8d3e1529-c442-5f5d-8a4f-c0c60493652d	\N	2014-02-10 10:09:30.447586	create data on tps table with id 31a3ccfd-d68e-5c32-92eb-4f7498c1deab
9b01b535-dfc1-5a5c-bd54-1feec2d74cb6	\N	2014-02-10 10:09:30.447586	create data on tps table with id f92f3c70-d1f6-5f2c-89aa-f66b00c2461d
72fceb41-66dd-5fef-92f4-d3b7cfaaf303	\N	2014-02-10 10:09:30.447586	create data on tps table with id fa6e6d6b-3bdc-5794-9f86-49b9b547ca49
843d1fad-54f5-5584-a2a7-18ef40ed1a45	\N	2014-02-10 10:09:30.447586	create data on tps table with id 19af0df7-ce32-5900-82cb-e69fb35ba58a
d6ff7b29-a699-5e16-8077-046bb0e38e2e	\N	2014-02-10 10:09:30.447586	create data on tps table with id 695e36f7-ba63-5b2c-a1f1-0380d33dbe4d
a9dcf02e-d333-545f-a96e-2268563396f9	\N	2014-02-10 10:09:30.447586	create data on tps table with id 7c280575-e124-58fd-bdc8-200df2238e12
27a8d4dc-bf6a-5ffd-a6e9-29cd34042041	\N	2014-02-10 10:09:30.447586	create data on tps table with id 4089dacf-1889-5ebc-8ee0-ee69559b2b87
cb624dfb-3b5a-568f-be2f-a8c19e9235f4	\N	2014-02-10 10:09:30.447586	create data on tps table with id 7f071e9d-c5cd-55e0-a9da-f6efb9eec883
745ee433-e353-5671-9af4-7d0730e926b9	\N	2014-02-10 10:09:30.447586	create data on tps table with id ef84c611-42f1-54f2-aecd-583f51d9b850
147b368b-1c59-5e54-9ccb-6f7db02d5f8c	\N	2014-02-10 10:09:30.447586	create data on tps table with id a3e8dd72-a7d4-5416-9d40-17bd500140fb
4caa520c-1429-5b17-b206-d6b780649bb8	\N	2014-02-10 10:09:30.447586	create data on tps table with id c690e47c-f4d0-5ab4-9e9c-9cde1b630bd1
ec6b591e-0968-54e8-8e77-2a671c5068ec	\N	2014-02-10 13:05:13.645511	update data on pilkada_event table with id 4105e8ef-29a1-5893-8103-cbd2c1e5fbaa
fd79342d-f1cf-5a2d-9672-6bb7cc4feb16	\N	2014-02-11 21:13:58.91322	create data on calon table with id e88d703d-d9cd-5744-9c90-330bdf09c573
d0a509c4-f7eb-5ec1-ad92-eb943e0e5868	\N	2014-02-11 21:14:56.138096	create data on calon table with id f850a044-9d39-55ae-a8f5-803107c2fce4
5022a7a1-8d69-5790-994d-a10e16eef7e7	\N	2014-02-11 21:15:16.345261	create data on calon table with id 9ea1f78e-2cc6-54e6-b45c-02000f00f6e7
359bd0da-4cb2-5570-adff-1a26670af46c	\N	2014-02-11 21:16:33.114754	create data on tps_surveyor table with id 23392589-fde8-5f1d-81b4-25f97468a6ca
33bc9df9-8e7c-570d-8b28-b210a37f7dd6	\N	2014-02-13 01:34:11.100942	create data on tps table with id 43b56094-0454-5417-86f6-1db9e6606bde
eefe2573-0df9-5bf4-b80a-90d9361d92b0	\N	2014-02-13 01:34:11.100942	create data on tps table with id da1e5a7f-efcc-593e-8afb-244563de1208
b162e6cd-a477-5772-a1c6-11b1ceeb6eb9	\N	2014-02-13 01:34:11.100942	create data on tps table with id 7c263d4d-81dd-5e21-8bb7-2d93a2aca5d1
0e800802-2414-53a0-9072-d16cc7530e21	\N	2014-02-13 01:34:11.100942	create data on tps table with id 2e4dce84-e741-5092-8372-2652f0e3071d
8c30085b-9e6e-50d3-ac25-bd75182bb1ee	\N	2014-02-13 01:34:11.100942	create data on tps table with id 66f745a9-9201-50a3-8f7a-98f834c89756
52ceb68d-eba1-51f4-8ca9-34c9cecbbc25	\N	2014-02-13 01:34:11.100942	create data on tps table with id 29cd3ef5-5889-5798-a8ea-236aee068ec8
43dd3c64-0004-5d21-a9b1-45d78980941a	\N	2014-02-13 01:34:11.100942	create data on tps table with id 7fa42f87-8305-5f84-889a-b8d10869eceb
d50d2a32-b439-5c87-bbf5-ca93cc7a7da9	\N	2014-02-13 01:34:11.100942	create data on tps table with id 7b579608-0e8d-55c0-a012-2a8f2c3af569
904b4bff-1755-588e-8579-d3ad712e8303	\N	2014-02-13 01:34:11.100942	create data on tps table with id fbea8d31-1435-5246-94c1-fe518d19e6cb
8a389227-2bf7-544b-915a-bb83770d1e3b	\N	2014-02-13 01:34:11.100942	create data on tps table with id 85827612-eee8-5bcb-9ff9-80823da62de1
ee2e404b-b105-5830-9827-0069a25358f7	\N	2014-02-13 01:34:11.100942	create data on tps table with id 4c10802c-bd57-5606-8cfd-45cda519017c
e4e7e30a-12ec-5e8b-845d-98308ac6d9ed	\N	2014-02-13 01:34:11.100942	create data on tps table with id 506e94c9-8fbb-5158-9d87-696800ad5e6a
1bfa40bb-f703-521d-bf36-daf722e7dfcb	\N	2014-02-13 01:34:11.100942	create data on tps table with id d872fb45-33c8-500a-b945-dc56313f558b
55f84e5d-38de-5573-b286-498838a59a0b	\N	2014-02-13 01:34:11.100942	create data on tps table with id c46f9172-bb71-5fc5-ba8d-ea3f725ff6bf
f3cd428e-5c9f-5bb9-9bf3-4c19188bbdd7	\N	2014-02-13 01:34:11.100942	create data on tps table with id 6c2b683e-a27b-52da-b455-ad10e0afb2b2
2541eb5e-d71e-592b-ad97-cb642a2031a9	\N	2014-02-13 01:34:11.100942	create data on tps table with id 51f46dbc-653c-51f9-9086-abe113106094
a75edc6c-5067-583b-b7a0-e5b232134970	\N	2014-02-13 01:34:11.100942	create data on tps table with id 4ad280bd-2fda-5342-9f18-39a6af0116f2
a4adb530-9607-5af1-9341-6d1025d8bca6	\N	2014-02-13 01:34:11.100942	create data on tps table with id b550941c-d883-5c7d-8501-3f66ae8f486b
08c2079f-3ae0-5214-a352-6fb220b2ef55	\N	2014-02-13 01:34:11.100942	create data on tps table with id 377f3da5-55b2-5ae9-930f-8953b4826e2e
19b50d4d-b8eb-5347-9dac-2dc50b89455c	\N	2014-02-13 01:34:11.100942	create data on tps table with id 6965052b-48f4-5e7f-b9a2-5d7a3dad22c1
b29ddad6-8e6a-5a95-84a9-d96d435b0155	\N	2014-02-13 01:34:11.100942	create data on tps table with id dda33a9d-f090-560b-97bd-da5ed7436bab
ce55a2d6-aa19-5ae5-ad45-06ae88621381	\N	2014-02-13 01:34:11.100942	create data on tps table with id 8e507b77-f601-575b-b2c8-06c2b81b7bfb
bad3e814-da1d-5e0a-bb6e-887cb9c197ff	\N	2014-02-13 01:34:11.100942	create data on tps table with id f718db89-945f-50bf-8778-9fbd45ea310f
4f4acb4d-f49d-5602-9d9a-da6e28e64126	\N	2014-02-13 01:34:11.100942	create data on tps table with id e067a4ba-b287-57e4-b105-c00ebe5e89f8
7a7be491-618a-51c6-a7d4-205b859b190a	\N	2014-02-13 01:34:11.100942	create data on tps table with id 9f25355c-9fd4-5ae6-a60d-c40e6bedd267
7e42bae3-971d-5bc2-981a-6fe1c80f7824	\N	2014-02-13 01:34:11.100942	create data on tps table with id 6c17d528-de79-582f-be60-de09966287ec
c7483964-751d-563b-87c4-79c724808418	\N	2014-02-13 01:34:11.100942	create data on tps table with id de409d1e-235e-5800-b3a0-b7b809dbeed6
dd3c605e-0154-56ce-b0d7-8f20dee2d0f5	\N	2014-02-13 01:34:11.100942	create data on tps table with id 33434406-b879-5168-9c3d-0dd6096bc564
885d423b-1919-54f7-8d88-fa49d36766c4	\N	2014-02-13 01:34:11.100942	create data on tps table with id 9b0d8506-9178-5d7a-85d3-54eabd99f6aa
1f7a9e58-5f8e-5b83-b812-54ccf616e9ef	\N	2014-02-13 01:34:11.100942	create data on tps table with id f5305652-bac1-5795-8a3f-42fc3a558b90
6a6ea407-248a-50d5-8fe8-c6a0735e4834	\N	2014-02-13 01:34:11.100942	create data on tps table with id 5d2bf817-014c-58c7-a77a-d6e2d6782279
db8ebcf7-a4f6-513b-b069-fa0c5890d28e	\N	2014-02-13 01:34:11.100942	create data on tps table with id 55e13f8e-0fdc-5300-9a66-84cd8740c4be
c8b615cd-dbd6-5ea3-a5bf-a4af55ca97e1	\N	2014-02-13 01:34:11.100942	create data on tps table with id 61c339b9-4d90-5e1a-8ec9-c3f9442ced74
8a9f5746-e9d0-52eb-9c23-c6b8b3198e9e	\N	2014-02-13 01:34:11.100942	create data on tps table with id 922cb925-26c6-58e8-929f-f60e07b54171
37bef4ee-9c8d-5cd0-a27d-7ba6236cdac8	\N	2014-02-13 01:34:11.100942	create data on tps table with id f522ee15-ef1d-5f4c-822c-14606bbfaeb9
9563315e-5d58-5893-b287-732e31645db4	\N	2014-02-13 01:34:11.100942	create data on tps table with id fb9cd5ad-1999-587a-bb65-f01f1c4f6653
eef13e93-118b-5ec4-b535-affa6e3f08c9	\N	2014-02-13 01:34:11.100942	create data on tps table with id 43f92117-f4dd-5653-aa9d-98b7a9c96759
96dca67d-5f34-532b-bb6d-6e2faa593fcc	\N	2014-02-13 01:34:11.100942	create data on tps table with id a26a5639-7ce1-5fac-ac45-ad31ffc65d77
67eb1dba-eb8a-5c28-89f1-2ebae11e1878	\N	2014-02-13 01:34:11.100942	create data on tps table with id 16dfbc8b-e69c-5b6a-a230-ec8299c498a8
21495d9c-bcff-5a82-a8fb-f09ec11eb444	\N	2014-02-13 01:34:11.100942	create data on tps table with id 680b0999-d3af-5efe-a942-231e891b8455
a5477351-6f96-516b-80b5-396e827ef7c6	\N	2014-02-13 01:34:11.100942	create data on tps table with id bf216dd8-0f8b-5df4-9b2b-8e3672b9e25d
80994871-12d7-5c1f-8fe6-5748822dbba9	\N	2014-02-13 01:34:11.100942	create data on tps table with id 96fa7b7f-f04d-5386-89f6-edd1bed2b7f3
e2fc7bfd-b7bc-5dd0-9f27-3e734eba8cde	\N	2014-02-13 01:34:11.100942	create data on tps table with id 248fd051-011b-5f41-bdca-b5e4c4a8dd15
63c6fdeb-41e7-50bd-a622-d7b4bc5e0a95	\N	2014-02-13 01:34:11.100942	create data on tps table with id 6edadeac-3a44-5704-a6b6-26d8e0c2bdb0
4e423f91-56d3-5091-a8f0-4dd9d91c3d7d	\N	2014-02-13 01:34:11.100942	create data on tps table with id 3f04c00b-fa04-5284-bba4-f836c198717d
58e4b248-3342-512c-b111-1df2cb030061	\N	2014-02-13 01:34:11.100942	create data on tps table with id 6f16b2c2-38dc-5f49-b05a-e5bccb8f1ac2
5e4e59f5-bf69-563f-9a66-87651e0c196b	\N	2014-02-13 01:34:11.100942	create data on tps table with id cb7b1e63-4fe0-5e81-9c47-a25cb83bc4f9
9356a035-2888-5264-8c7a-b7df32425d3e	\N	2014-02-13 01:34:11.100942	create data on tps table with id c4f95643-a886-5bc8-910b-2553efbffebe
126c8d40-61e8-5730-ae39-e957cc6647de	\N	2014-02-13 01:34:11.100942	create data on tps table with id bc1699d6-89e8-53bb-9dd0-eec582c7d943
92cd2e2b-48ec-5ede-8ad0-3f1852537ece	\N	2014-02-13 01:34:11.100942	create data on tps table with id c8032475-1b2a-5eb5-a599-40bfba2ebd7b
b1612187-585a-55fd-b291-5651f29d19fa	\N	2014-02-13 01:34:11.100942	create data on tps table with id 33da8b78-4f90-51a6-a480-be2d2ff3b776
ffd19f20-07e3-5653-aefe-521279e520c3	\N	2014-02-13 01:34:11.100942	create data on tps table with id 6d9f61f8-115b-5727-b9ff-fc5850483444
3bca80be-94db-5e07-9f64-c0e07b7167db	\N	2014-02-13 01:34:11.100942	create data on tps table with id 5a89de6c-7461-5ba5-91b9-261ce2998c84
1d428bdd-23d5-5040-8dd3-2774c328eb7e	\N	2014-02-13 01:34:11.100942	create data on tps table with id 9405399b-d2f0-573e-918b-56c6f6df7748
41eb5e8f-1801-5afb-9ee2-919a4e1090db	\N	2014-02-13 01:34:11.100942	create data on tps table with id cc85ea35-87da-5b85-9e20-9a9417693a85
71270e1d-5231-5515-a97f-0f8ea36e1282	\N	2014-02-13 01:34:11.100942	create data on tps table with id a2b02555-01e6-559b-a4f6-5ea949bc8436
0c0cdf9b-5bdc-5a9b-9ef6-5782bd39a279	\N	2014-02-13 01:34:11.100942	create data on tps table with id 84665519-f9e0-5d77-bf0f-fc6eb18ac389
723eb253-f01d-597c-882a-ff107af99344	\N	2014-02-11 21:16:33.114754	create data on tps_surveyor table with id 23392589-fde8-5f1d-81b4-25f97468a6ca
552f1550-f783-5881-98c8-cc0b31196d94	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 86d13a98-277c-5029-a5e0-cb279bed870a
b1b1ebcc-a68a-55e9-8776-eeca47dc2713	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3504ff10-18cc-5dcf-b6d7-51b9a3ed70c1
77cfd65c-f4de-5966-a9e8-cc36cceb97d7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id cb3df3ae-02b0-58c3-972f-8f79d657bdf5
1a304ed7-b5e0-578f-82d6-88e239018897	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 590f9cae-c4f1-5d90-87dd-cc9fa3f3a48b
24368386-6431-5a9d-b539-0285af0d0144	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id bd9eeddb-c4f0-5917-9a92-dc419332edca
6b586d6c-d615-50a1-a503-1104ae8215e3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 82a8f8cf-2ada-5593-a145-2405db5d16f4
9d95be93-a660-57a2-90a6-c51b5e560811	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 8410649d-8cdd-55f3-bba8-613f231030d0
ac2ea020-2806-5602-ae57-763c8dfaf92e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3d8bcfde-d147-5d51-924b-14447a6c66fd
75cd853d-9ad0-5ffc-aa23-1c5660c4e5fa	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 39b41a0f-80fc-58e3-929a-a00ea54a32a6
2601e440-ae70-5d71-a12c-b91d514d4089	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 61e70aa8-06d1-5821-85e8-d11181f8093d
75f1e2cf-abac-5aa0-8fc8-fd3af3ce1458	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id a75266b6-b348-5aa0-8785-b1f430862234
6f9dbafb-aee4-5f16-8b34-bcee9fd91d15	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5ba8a345-12d1-57c4-b35b-e0c929c50450
de5119e1-4466-5b96-b40b-e8ca605f6f5d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1a008278-9295-5794-b276-0045a4ce406f
5f886633-260b-5f82-bbb3-7346d2fb4cb9	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 31c4f9da-59ae-55c5-9dfa-8c7ecafb9253
02d5ada6-5015-5e1b-b2ee-7255e878ee60	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3a42fd4c-b45f-5362-a40c-aeeb66dfb6ea
765ade68-6af8-50a7-affd-ed9b11549680	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b99b9557-0481-556b-a5c2-b5807337dd88
83c4de27-da59-50cd-869a-714f52ff4bb8	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 576b6b72-648b-5652-9003-24099813d445
6171ba01-9dda-536e-8222-8f7cf1143a52	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id c54ac723-9023-5a24-89f2-4d9ec9cc6a41
a4fc6957-9378-5708-996e-fd43c07b06c5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 166086f3-0180-5e93-8386-aedfdb37d9fc
68af408d-275a-5b90-adc8-4c5451753f08	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 03c4fa47-6d01-5bf9-83b4-ce09693646a8
49a1cf7d-01ac-5abc-9dab-4ab1d569aabc	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 714f1147-e3cc-5c87-8e3c-4bd4774c728f
1cad175c-48a6-5385-bb77-f1c64ea8ee16	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 43797aaf-c40e-58d9-87ba-f63dc904763e
f185969e-c044-549e-a7f3-4946bcbb7258	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 2ea14652-4c96-5156-aa76-857223bc70d9
e3ebba64-9203-5285-8399-9c2f5723fbf8	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3cbbda5c-d8e4-5ac8-911f-50d5f2cda1b9
ef1a941d-bfaf-5196-bb53-d9f7f3360cf4	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 27ca348c-2af6-5564-94ad-8c945f968362
394a01b3-7202-5e96-b103-0372755706ca	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5b8f01e3-41e2-574c-90fb-510ca1716825
442adb8d-8864-5c22-82e0-ed66d5df05a1	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id f318f842-d757-5ef1-b359-ec10848118bf
9b2913fb-c125-5ff9-a89e-cf1f1ad426b1	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e9e6f91c-1ea7-526b-b2d8-99a61d64dce0
94c87b7e-2ec8-55e7-baa3-ebadd28fe49b	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 88bb805a-1c9c-5231-b3f5-d87d586f6ec9
3c2799d9-f7d2-5e43-9101-2f9f5d4e0307	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 01588caf-f73b-5aa2-b825-d4fb18807e61
7645d990-6e1e-5ab0-b804-9a56daf5bf5d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b84fb53c-642c-5e69-81b4-3720b85599a1
de4a21fb-86fd-561a-afad-d36c3e5b6991	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e924e33e-acc9-5811-81d2-0dc599344dda
94bd7b53-c95d-5c51-bb98-f57eabf612ce	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 33ac51cc-d861-5954-852c-411799bdd0b8
702ad798-9f89-5f46-8184-60773c2ec2f7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3f46b0dd-c3b1-564c-81ca-db79743595f5
ee586ab6-c0ad-5f02-bff3-8697b580a171	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 0ce541d1-6182-565c-9f4c-95fe85ec4cdd
644a5ecf-4dd7-5a92-9431-2bd70af582e0	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e852f094-bdd6-5bc3-a912-3149e59b3056
66fba999-587a-5596-9a4b-251eb88026ed	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3c1eb231-0883-550e-b470-d8be7fcb80cf
f194fb9e-8819-53d1-9c8f-c3bf14740118	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 7072e657-f143-5239-a7d1-0e3257b931b5
87f80d41-a726-504d-a70c-79c6a3b4a416	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id fe8b1356-24ff-54e9-a2e7-e472939015c1
7636564d-85cb-5d27-832e-70173d35bc3a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 89f7e4b5-5559-5c3e-9582-19eaf81eb879
5a7a9d7f-2598-577b-a0c8-f2bae4b9f855	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 413d29af-1f2a-5151-9853-0d9ec54f3eb8
7f75b11f-2cdc-54fc-8e9d-cbc1973dc2b7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1ca24479-925e-5696-9f07-16c0f001ef01
d7f63d06-a88d-569c-9c14-5af85c96d490	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3f050918-01d5-570b-ba35-62ecab6c37dc
89c88eaf-f2bb-56a4-9b91-55aca6eefa1f	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id a964045f-f885-5f89-8310-228d49bbc1c4
0ae93c03-8b95-5254-ba37-02c6cefea189	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 002782df-7858-50e5-9612-54cb4ca08de3
52c13bef-d7a9-5e0f-859a-d724d3adc4db	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5faf61dc-456c-5582-af7c-e00461b5ecf5
38ffcda8-ab75-51ea-8306-4c3830bd3a98	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 44427045-b855-56ae-bca1-20d5f2ef991e
c50bab52-1094-5e88-bfed-0e46c694e98d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id fb761508-58e7-58c4-bc95-d4b63a057a43
b2bfd642-271a-5bc7-a822-055768d3164d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 62255842-ac8a-55ad-9ff0-74c29fa53413
f9b5f840-1f4f-5336-a51b-61fd8155a1f3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 0519b9c3-b1bf-5d8b-b025-aaa1d2ffec67
e8b845e1-e240-50ca-9a04-0df0d0445a29	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 071be393-107a-56fe-a932-536513f77296
ff459548-6cee-51d6-99a0-a9dbd6f048bf	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5b0b638a-2db0-51e9-bb6e-3318843bf435
4c455639-4f8a-56b4-94de-16272f9fcfec	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1b87d1fc-43df-5623-acea-e3efb98785d6
b9a5b351-cf02-526f-b367-4f8a12e200dd	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5699fbbe-7c9b-515c-8df4-8a8bdcfe638b
01a77e10-c978-5148-851c-62094ecdc17a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 91924471-8213-5cb3-8c6e-b02f91d6c6cf
e712b9b9-3595-50c1-a038-514ae1785643	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 98cfefa5-4760-593c-8496-c91abe8fc278
e4f49bc6-c4ef-5b87-9a82-9cc29fa231de	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 35b36d94-7bf3-51a0-a920-b2878e1e3cd9
896f61ea-5f3b-5d2a-9474-81c6557e931d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 14716e48-1862-522b-a564-11051beaaa08
9125687a-a08b-539e-aca1-1e9b693c517e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 72b51198-518e-5636-9c3f-387d78e18272
d359e6bc-6327-5cf0-a3ef-ac27551f0a10	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id aa3207ac-6ca8-5fa2-8492-d628c6669a7b
ea6c5bef-4c6a-5010-add2-1335ed636035	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5214bdd3-103b-5a22-87e7-785f60955a31
b6ae15ab-f2fb-5f72-895f-f7833242feb4	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 01a8252d-6ea8-52df-a1ad-735cf17d6f50
6c32dd19-74c9-578e-8f78-c5bedc2a6898	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 66966a9d-5e3f-50bf-a613-846b467fe0cb
55da69c6-bb69-5f76-8815-e17881b2c01c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b6ec62fd-95de-5725-a60c-f6bb6c889cdc
71d231d0-cfc8-504a-9372-cf2ab4bb49a5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 8a7a38f2-561e-5191-b2be-a290940b142d
53e299c4-d175-5dfb-bde0-0841403f38c3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5e53e2cc-7f36-5d3f-b5b5-2e71c4edb120
102962cc-2b0e-56ab-9ff4-09cf722bba2e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 36d44ef8-f89b-5de9-a85d-aad609c4f239
0b435dd7-77c5-5733-817d-c06d9656e8da	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e98c15f4-c57e-5c24-badc-98c97ee0dee8
f08a5468-1ce5-5e7a-af67-c87d7475338d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id dbb750b5-0872-526e-8da9-ed92daca74af
a13a08f3-ff4c-54fa-a1c0-cad553eb132b	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id f50aa319-25e1-5121-9ed0-d1f66574328a
ea901072-a9a8-5021-9cce-d326b59d4504	\N	2014-02-11 21:16:33.114754	create data on tps_surveyor table with id 23392589-fde8-5f1d-81b4-25f97468a6ca
57aa03f3-1fbd-534c-973f-c5860d31ecbc	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 86d13a98-277c-5029-a5e0-cb279bed870a
b50b0eb2-1a32-5636-b70d-5054f017d48e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3504ff10-18cc-5dcf-b6d7-51b9a3ed70c1
fd363425-1244-5342-92aa-08dfc619d87e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id cb3df3ae-02b0-58c3-972f-8f79d657bdf5
c46974a6-960f-508a-b702-549ea817181b	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 590f9cae-c4f1-5d90-87dd-cc9fa3f3a48b
69ceec32-4a7c-5df6-bafc-5b43254a2650	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id bd9eeddb-c4f0-5917-9a92-dc419332edca
340fec53-6d0b-5ab3-9b9a-4ef62245bdea	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 82a8f8cf-2ada-5593-a145-2405db5d16f4
b140d394-f43b-5e42-ba89-790ac133b334	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 8410649d-8cdd-55f3-bba8-613f231030d0
b6d9c331-f68a-5db0-bc95-fa14b4ec0e55	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3d8bcfde-d147-5d51-924b-14447a6c66fd
05b52918-7817-52e1-967a-30b367b9570b	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 39b41a0f-80fc-58e3-929a-a00ea54a32a6
6a4cab43-f75f-53b1-b5ec-0aab117d9f74	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 61e70aa8-06d1-5821-85e8-d11181f8093d
fee946c1-47c9-5af3-80ab-b89849306aff	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id a75266b6-b348-5aa0-8785-b1f430862234
2a8f8a4c-3d03-5509-a0fc-c7226972d0fa	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5ba8a345-12d1-57c4-b35b-e0c929c50450
bdfde96d-5797-5375-b83c-abbda6a33e79	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1a008278-9295-5794-b276-0045a4ce406f
94a3d3fc-2c6a-5925-8bbc-468c59674cb7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 31c4f9da-59ae-55c5-9dfa-8c7ecafb9253
fca30838-b134-5b28-b20d-7884bb8525d0	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3a42fd4c-b45f-5362-a40c-aeeb66dfb6ea
37a734d8-9959-59d5-858c-13391587d82e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b99b9557-0481-556b-a5c2-b5807337dd88
651767c1-5498-5d67-8036-562d1ec20b8c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 576b6b72-648b-5652-9003-24099813d445
fcb2acd2-8382-58d7-908a-9a916ab85b74	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id c54ac723-9023-5a24-89f2-4d9ec9cc6a41
8aa28c7d-a8ef-5bcd-b295-5b514faaf626	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 166086f3-0180-5e93-8386-aedfdb37d9fc
b48c215a-bed8-5709-a890-6b323559ff7a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 03c4fa47-6d01-5bf9-83b4-ce09693646a8
9c8982ae-26fe-5f46-9a23-008cdaedfe35	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 714f1147-e3cc-5c87-8e3c-4bd4774c728f
d886dd68-32e5-540b-bf9d-7d36537e471d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 43797aaf-c40e-58d9-87ba-f63dc904763e
29acacbf-03dd-520e-85ab-e3c0f10366dd	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 2ea14652-4c96-5156-aa76-857223bc70d9
359e1b31-d521-5804-ab9c-daff50ee9463	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3cbbda5c-d8e4-5ac8-911f-50d5f2cda1b9
066ee9fb-d23e-507f-b88a-78f28be53729	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 27ca348c-2af6-5564-94ad-8c945f968362
c8f265a9-04c8-567a-85ba-45d784e3a5e4	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5b8f01e3-41e2-574c-90fb-510ca1716825
9f1d8d70-cdc8-57bc-b2c1-56259eff362e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id f318f842-d757-5ef1-b359-ec10848118bf
fea6360b-d056-55ff-adf6-d470d34ceef4	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e9e6f91c-1ea7-526b-b2d8-99a61d64dce0
856f9aa7-86bd-55a1-8745-e3e56f7ec144	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 88bb805a-1c9c-5231-b3f5-d87d586f6ec9
8e1f9851-38f7-5783-acbb-4e0b14ddcf36	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 01588caf-f73b-5aa2-b825-d4fb18807e61
3612fb60-8902-5d10-82b4-0142588410d7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b84fb53c-642c-5e69-81b4-3720b85599a1
a274d41c-0fbb-569b-9096-1802eab6680a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e924e33e-acc9-5811-81d2-0dc599344dda
c499bd5f-e3b4-5136-b83a-6ebfe20afe15	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 33ac51cc-d861-5954-852c-411799bdd0b8
3d4d3fb4-adba-5053-aa49-340fc612e3d3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3f46b0dd-c3b1-564c-81ca-db79743595f5
a44ed428-aa33-5658-906c-8515673479e3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 0ce541d1-6182-565c-9f4c-95fe85ec4cdd
c0597353-c4f7-5553-bb67-414bf6595825	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e852f094-bdd6-5bc3-a912-3149e59b3056
d917794b-2d1e-58b6-8799-c3fe665736dc	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3c1eb231-0883-550e-b470-d8be7fcb80cf
ab800e41-71ef-5a28-97a3-d1f282c98eed	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 7072e657-f143-5239-a7d1-0e3257b931b5
97fc1e78-e2c6-5b30-8649-d4cd1d807c7c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id fe8b1356-24ff-54e9-a2e7-e472939015c1
9de5a07b-d6ed-51e1-a00b-4a9852a3da4d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 89f7e4b5-5559-5c3e-9582-19eaf81eb879
ced2a3bf-c55a-5a7c-9f7c-0204da0f2a45	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 413d29af-1f2a-5151-9853-0d9ec54f3eb8
d2f8750c-7477-5a8c-8038-357062178c09	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1ca24479-925e-5696-9f07-16c0f001ef01
499eb4d0-165a-5b0e-9272-699027dc16fa	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3f050918-01d5-570b-ba35-62ecab6c37dc
6344dfde-0cbc-5260-857c-63ef7a4a915c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id a964045f-f885-5f89-8310-228d49bbc1c4
587d18ca-807f-5a6e-8549-028fd9ff2732	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 002782df-7858-50e5-9612-54cb4ca08de3
b409b35f-8c62-5d06-9ade-09bda152a00d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5faf61dc-456c-5582-af7c-e00461b5ecf5
8c2e5817-5e85-5da8-bf5d-7b52c3d0a6a6	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 44427045-b855-56ae-bca1-20d5f2ef991e
2029a3ca-c236-5e40-9164-007360bfaadf	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id fb761508-58e7-58c4-bc95-d4b63a057a43
1cc78d61-55f3-576b-b7d5-d3fcf8c14270	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 62255842-ac8a-55ad-9ff0-74c29fa53413
a0c35e5f-8af2-5bb0-b168-04e3a3a86de5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 0519b9c3-b1bf-5d8b-b025-aaa1d2ffec67
48aa2680-1581-5388-a166-43c692fd3c97	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 071be393-107a-56fe-a932-536513f77296
c9a8c758-11ee-5b63-bf9c-93bc1a54a364	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5b0b638a-2db0-51e9-bb6e-3318843bf435
82fa21b6-8df3-5cb3-b5fb-8e58e6b462ad	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1b87d1fc-43df-5623-acea-e3efb98785d6
c4e2307d-754d-5a87-81cc-c9392a724f0d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5699fbbe-7c9b-515c-8df4-8a8bdcfe638b
f46bf2f2-d2df-56ff-988a-0de120606bfb	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 91924471-8213-5cb3-8c6e-b02f91d6c6cf
3bcf0a0d-792a-52a6-9adf-7d28d93dff38	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 98cfefa5-4760-593c-8496-c91abe8fc278
27cfc8d2-8400-5215-8b5c-4c97c7b90eed	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 35b36d94-7bf3-51a0-a920-b2878e1e3cd9
9d8e4a36-0790-5919-b6ed-9715007ced77	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 14716e48-1862-522b-a564-11051beaaa08
ede365b8-4dd1-59fa-a3d9-b539516ba733	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 72b51198-518e-5636-9c3f-387d78e18272
d4b9ac71-ef2a-5e9c-9dac-478615e4bab0	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id aa3207ac-6ca8-5fa2-8492-d628c6669a7b
716e5584-7a80-5dc7-9342-4a3f6ce5c2d9	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5214bdd3-103b-5a22-87e7-785f60955a31
38286525-eb17-5815-8447-7897e86dd70b	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 01a8252d-6ea8-52df-a1ad-735cf17d6f50
70877998-7a0e-5f94-bcf5-f930d4a1de8a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 66966a9d-5e3f-50bf-a613-846b467fe0cb
7783b2be-1e2a-545a-bbb4-2672568ddef3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b6ec62fd-95de-5725-a60c-f6bb6c889cdc
a45afa5a-7c6f-57d5-bca1-25d459c9c373	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 8a7a38f2-561e-5191-b2be-a290940b142d
84884ab9-67e4-59e9-ae38-e720130d1570	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5e53e2cc-7f36-5d3f-b5b5-2e71c4edb120
b988b6a5-b54d-5501-8cce-9465c8f2b178	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 36d44ef8-f89b-5de9-a85d-aad609c4f239
f090547e-4d80-56a3-b9fa-8fc8e8e00d45	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e98c15f4-c57e-5c24-badc-98c97ee0dee8
d63b0b0d-8c7c-5dc1-b61a-a8d62d9191e5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id dbb750b5-0872-526e-8da9-ed92daca74af
b3f074e4-6b0c-5ae4-ae81-49029dbcfbc2	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id f50aa319-25e1-5121-9ed0-d1f66574328a
3a805e43-edee-5962-a629-c2cfdf7bf3dc	\N	2014-02-13 15:46:38.470193	create data on tps table with id a44d9a1c-69f6-58fb-ac90-c2378b56dd67
a98dbb65-b58d-5577-9565-9ef4ffa2a63e	\N	2014-02-13 15:46:38.470193	create data on tps table with id 48d23cea-4061-5878-8c95-e539daffebfd
fe295940-8869-5850-babb-e1c897a26c87	\N	2014-02-13 15:46:38.470193	create data on tps table with id 0d97ac42-a2aa-5159-ab49-226ae9fd8ae2
5159d773-a217-5ee2-918e-4d5265a728d3	\N	2014-02-13 15:46:38.470193	create data on tps table with id f3932ce3-ddb3-58a7-85ca-0839ac68484b
3bc5f532-d80a-589a-a939-d1b61c4546e3	\N	2014-02-13 15:46:38.470193	create data on tps table with id fccfdb3b-e06a-58a6-a69b-eaf7781b7366
cba6a5b1-35e6-553d-96a8-04072a09fcfb	\N	2014-02-13 15:46:38.470193	create data on tps table with id 69938d98-467a-5067-adeb-5ba5bf64c4aa
cbd30ef9-d6b9-5e6c-8398-239f00663f2b	\N	2014-02-13 15:46:38.470193	create data on tps table with id 44b402ec-8a47-589b-9536-5a7255ab05ff
d3341c9e-49cc-5f3d-bfa4-99f5dc32a552	\N	2014-02-13 15:46:38.470193	create data on tps table with id 896df16a-6eac-5b34-bfac-81eeed64b81c
6e6069a8-b89f-5705-8a09-75dbd8eaa24c	\N	2014-02-13 15:46:38.470193	create data on tps table with id 52fcbf94-9832-5c83-acb1-2c2c64550366
56450e21-7727-5b84-aad4-178c1b11ecf1	\N	2014-02-13 15:46:38.470193	create data on tps table with id f2279e6c-c863-5142-bc32-ff1f92f95f2c
b214f23c-aa0b-5e81-97a8-c40677e68817	\N	2014-02-13 15:46:38.470193	create data on tps table with id 7d1cad70-8fa4-5571-8c4b-c895b1f02308
b0cc5437-d97e-5d5e-a618-1e369b825197	\N	2014-02-13 15:46:38.470193	create data on tps table with id 5023dc90-7f15-5ea3-b6bc-9ee2b170a3e1
b0319e5b-dc8b-542c-8e2d-d3791836884b	\N	2014-02-13 15:46:38.470193	create data on tps table with id f2e9233a-55dd-543a-a8bf-5cdd0cfbb74a
c6d639da-0f2d-5c7b-a14d-8cb7c1d3517c	\N	2014-02-13 15:46:38.470193	create data on tps table with id 40944e3d-5b96-52ec-8983-e08ca3db3fa9
181a0bd2-c8d4-5fe7-8029-b830b69293b4	\N	2014-02-13 15:46:38.470193	create data on tps table with id 243e6df2-8a7c-5b05-8d26-29d5e36bd673
89b141e8-4832-58b3-85fd-9d2bbe57467a	\N	2014-02-13 15:46:38.470193	create data on tps table with id ab513a59-38ab-5685-b75c-5116953a95c9
1c1e2632-dc1e-587b-a9f8-2a44b89d4a9a	\N	2014-02-13 15:46:38.470193	create data on tps table with id d2577e03-66ba-5606-9d2e-7d5f0b53db66
8294d625-4e2f-5219-b33c-6e8ae03b1b8c	\N	2014-02-13 15:46:38.470193	create data on tps table with id efa0ada0-fc3e-54da-b2a4-699b1bf8afac
8fe351dc-21e3-5a5a-8e99-2205245dbff1	\N	2014-02-13 15:46:38.470193	create data on tps table with id 60d64ae1-8ead-51b2-9c81-ce40ce65a980
e93dcb11-ca71-5ebb-a850-7c899faf1f21	\N	2014-02-13 15:46:38.470193	create data on tps table with id d86839f3-95ad-5da9-8aa4-da86d7614cef
baaf81b7-505f-5e0b-8f26-e15b368bd898	\N	2014-02-13 15:46:38.470193	create data on tps table with id 95f4f7c2-c3e9-582a-b7b2-4ef04ad2b38e
e2e59c06-90f7-51af-9df2-8190e9b3e719	\N	2014-02-13 15:46:38.470193	create data on tps table with id 66201c98-8808-55d9-81ee-e1dc2e795a37
05b55d13-53c6-5237-9821-b417915d9b10	\N	2014-02-13 15:46:38.470193	create data on tps table with id f01463e2-5741-5c6c-8df2-f86ef722af01
e2a28c37-5293-5494-9fa5-3adffd9bc78a	\N	2014-02-13 15:46:38.470193	create data on tps table with id f702eae1-2408-5b91-8a94-a416aedcdb12
a29715da-fc34-5e9c-8b2f-e0f4df9b4632	\N	2014-02-13 15:46:38.470193	create data on tps table with id af614633-c97e-50c0-ba36-6ddbcaf6da42
348afdb5-85b2-55d1-b627-6950c736e6c8	\N	2014-02-13 15:46:38.470193	create data on tps table with id 484c00ec-a0ed-593f-8c72-707037be8adb
4c85ffac-830a-56cf-9def-37690afda4ce	\N	2014-02-13 15:46:38.470193	create data on tps table with id a0187f0a-5e88-50c6-adaa-d72495d1db7e
767f5144-d18f-5957-900d-56cb8d5d6340	\N	2014-02-13 15:46:38.470193	create data on tps table with id 9c669fb1-797e-5741-a6f3-55a02897090b
db974fd7-a87b-5950-a48f-881db0131676	\N	2014-02-13 15:46:38.470193	create data on tps table with id fefd9671-10c1-5c09-bc16-35dd015f8d93
1fca8c6c-2728-5e0e-8368-ec48d665258d	\N	2014-02-13 15:46:38.470193	create data on tps table with id 81d48815-1159-55b4-820e-32508b256c0d
1a573f67-0ba7-549b-83be-e1970f9e52a5	\N	2014-02-13 15:46:38.470193	create data on tps table with id 9df1c5f4-b52d-59d1-a3d6-762974578a96
71a28c3b-4b8d-5282-9928-c97cf587de97	\N	2014-02-13 15:46:38.470193	create data on tps table with id b1f11737-2f4a-5c81-84ca-e6702a440ecb
20c73fb8-e0f7-5824-8fdb-07d5555347db	\N	2014-02-13 15:46:38.470193	create data on tps table with id 29ac3758-1a0a-5d67-9b18-fb63b3edda34
bcd7d0df-21f5-586e-8634-05fc463f3763	\N	2014-02-13 15:46:38.470193	create data on tps table with id e1adafaf-fffd-5b9c-9a77-64fa3c4b9289
dcf2dc2f-a1ab-517d-8486-a22ca03a4acf	\N	2014-02-13 15:46:38.470193	create data on tps table with id 11f5a0f2-fe57-58a2-89cc-139f47ef6ae5
6c0a8d25-786d-5031-aaa9-7d9392be6cc7	\N	2014-02-13 15:46:38.470193	create data on tps table with id d4bd8c17-0f14-513e-9f35-f316832a91d7
0cf3c81c-5c4b-5a37-ae46-986a39eb5bbd	\N	2014-02-13 15:46:38.470193	create data on tps table with id fc3fbf83-b5b2-5454-8376-97e0ac073702
21fdc1f5-db0c-5709-b2a6-1cb611f659a5	\N	2014-02-13 15:46:38.470193	create data on tps table with id 2451c698-750d-5019-9c49-93f20a72aab5
650c6e05-b5d2-54c9-ab9e-0c7b72356a34	\N	2014-02-13 15:46:38.470193	create data on tps table with id 6ad50776-b8c9-5f11-ac01-b9e4cbfbab1d
5584f555-e30f-5c4b-9128-edc0774554d2	\N	2014-02-13 15:46:38.470193	create data on tps table with id 4ca10400-b585-5c21-8f28-c8b95e17969f
5dfef5e9-ac4f-5054-9951-4eb16d2c17fd	\N	2014-02-13 15:46:38.470193	create data on tps table with id b307f96d-5d87-5b79-8b72-0813fb1afb5e
1d6f95f8-68b1-5f7b-aa5e-033896514e1a	\N	2014-02-13 15:46:38.470193	create data on tps table with id 92c01e8c-6194-5086-98c7-0a0ea533a6be
d1f06a1b-6553-5bdb-ae9c-18df1a61c1a2	\N	2014-02-13 15:46:38.470193	create data on tps table with id cd6d0929-821c-5119-a344-356b40605366
fb150b69-763e-5b58-b32c-5bae5cb17fb4	\N	2014-02-13 15:46:38.470193	create data on tps table with id 07ab5dae-e532-5f5d-a14b-188229407134
a8fdf0e6-9702-5b81-91ea-fc1ab097eeec	\N	2014-02-13 15:46:38.470193	create data on tps table with id 980e2299-b9c8-57a9-ae4a-b8360619d82e
41a0a444-d5df-520c-83b6-046b6c2c3f6a	\N	2014-02-13 15:46:38.470193	create data on tps table with id f77f4ac3-4f55-5b4f-992c-0090fd61d5ff
58641cc8-e8d0-525f-9327-2b3612a55452	\N	2014-02-13 15:46:38.470193	create data on tps table with id 7fd9d6a3-fd47-5974-96a3-43543b45ed6e
20719c00-9309-5008-91e1-736ec879d134	\N	2014-02-13 15:46:38.470193	create data on tps table with id 743aa830-b7d1-5d53-aa31-b1b2c1ca2172
67e7226b-3837-51a5-b203-2f9801e04066	\N	2014-02-13 15:46:38.470193	create data on tps table with id 64ee7f29-8f81-5e0a-9993-1362337c2524
27c8c85c-7449-574d-8489-e124ccc36587	\N	2014-02-13 15:46:38.470193	create data on tps table with id babc2931-883f-50ae-b6e1-9386e05e5bc0
a2efc0f6-880d-598a-b515-d2f0586a581d	\N	2014-02-13 15:46:38.470193	create data on tps table with id 0f5be733-49ef-5d9e-b5f5-dfe9883caa7d
cecd70ba-c10c-5be6-b579-3f50024b28bb	\N	2014-02-13 15:46:38.470193	create data on tps table with id 7a9fd53e-4567-5b40-8549-d35259dcd16f
8aeafbd7-53ba-5150-be96-e6f95e4f4798	\N	2014-02-13 15:46:38.470193	create data on tps table with id bcb86e32-62c5-5976-9843-0f3dfc062867
e682d8e7-5092-54e2-9613-ac6857f950f3	\N	2014-02-13 15:46:38.470193	create data on tps table with id e30c82cb-f1fb-503d-aae5-8d5aa623eb20
fe83a352-8f0e-551b-83f5-ab196cc5df98	\N	2014-02-13 15:46:38.470193	create data on tps table with id 55988ed6-3656-5484-ade6-932146e78f8a
cbea94f4-76bf-5ac5-a606-6322e8b7773d	\N	2014-02-13 15:46:38.470193	create data on tps table with id 0eacb61a-0bb5-54df-bdd0-168c510e2ce5
b2250742-07f4-5eee-96ab-9a3d96a60154	\N	2014-02-13 15:46:38.470193	create data on tps table with id 1e3a0735-b5b6-500e-b5f8-f3d00fcc7070
a5c1266f-4b70-5198-9246-63fe1ba54e12	\N	2014-02-13 15:46:56.212298	create data on tps table with id 64e751d7-c422-5c2d-bf80-367f2d62b53e
2b1d22cc-0157-5282-9564-63fc39aea128	\N	2014-02-13 15:46:56.212298	create data on tps table with id aa08a4dd-cfdd-5504-8b7e-e9c4b7cd9cfe
f2d6415c-d861-5a48-9524-9b1e07308f39	\N	2014-02-13 15:46:56.212298	create data on tps table with id f5f54edf-9ac5-5344-980e-89612276d06a
0554570c-7776-513c-b998-700c30fb5a80	\N	2014-02-13 15:46:56.212298	create data on tps table with id 102be1da-7933-55d9-bf0f-a9f8c74ca341
45beda8c-d7dc-543c-8762-619fb19d64a5	\N	2014-02-13 15:46:56.212298	create data on tps table with id 0eec1d73-5048-5056-8435-11605a6d97ad
14643db2-da2c-56ad-b734-88e8bcd9444b	\N	2014-02-13 15:46:56.212298	create data on tps table with id 04a1ccf9-0b2d-5101-8542-7ded87feb741
956a1a4c-37a1-597e-9a12-9537835e192a	\N	2014-02-13 15:46:56.212298	create data on tps table with id 64b4663a-d6c8-5236-9326-fb4c2034eede
ca706032-51af-50c2-bea8-38f441727176	\N	2014-02-13 15:46:56.212298	create data on tps table with id 62bff016-ecb1-512d-a886-6478c6d83c61
6575a323-2d0a-537b-821d-b8b847096b85	\N	2014-02-13 15:46:56.212298	create data on tps table with id 28c4caa0-d50a-5438-a477-780bc4b10ddd
ea438065-31d0-5caf-91dc-b1d3d564fe1d	\N	2014-02-13 15:46:56.212298	create data on tps table with id 3187c8e6-58da-53b3-9847-09e9c62ebfa7
1f0c3c76-4f99-5f60-9669-2918e472a9c8	\N	2014-02-13 15:46:56.212298	create data on tps table with id 351d0dab-9055-5b8b-92b3-be167e009cb3
6bdb85fc-7408-56c6-9af8-b9f2175e2101	\N	2014-02-13 15:46:56.212298	create data on tps table with id 992c27a4-6dc1-5710-9433-cd58281c285f
573a2360-db98-5cc6-812b-53e490d2c478	\N	2014-02-13 15:46:56.212298	create data on tps table with id 4372bb14-fde6-5083-8970-73b373d2c034
b759b9f3-9f01-583a-8ceb-8f2f0664b229	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6c5ef5f4-e609-5f94-a5d3-671774155ec2
027ef433-4048-52dd-9b77-02c3a1625ff7	\N	2014-02-13 15:46:56.212298	create data on tps table with id a5c54e33-b687-509e-84e8-7ca71e4fb5e8
da047376-c873-5826-8bb4-fe43c44b1e95	\N	2014-02-13 15:46:56.212298	create data on tps table with id 354e9924-3ef1-5b0d-8c75-186c9799a88a
0d3f501a-76d5-57f7-8497-bab9e343aadb	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6f41d5b4-50fa-577f-bb64-72fb41908c18
8ea9320a-c529-5cd5-aa9a-f38418e7e98b	\N	2014-02-13 15:46:56.212298	create data on tps table with id d02eed5f-da30-5787-90d9-8b4d19ed94b3
f25b4f1a-fe3d-50ed-9634-3adf85145809	\N	2014-02-13 15:46:56.212298	create data on tps table with id c5b8211d-a92d-52f2-a1bf-ff41f8952707
fad4615f-51bf-5736-af7b-b47f9bc519f8	\N	2014-02-13 15:46:56.212298	create data on tps table with id 420ae2d1-9703-5a46-92d3-b93f403c2532
eddf3c9e-d3cd-55ae-8265-ea868c7c32e7	\N	2014-02-13 15:46:56.212298	create data on tps table with id 912e5ef6-9325-5c43-8fe4-7e6d7ae75700
8628e9d6-2209-506a-b2d1-8972409a319a	\N	2014-02-13 15:46:56.212298	create data on tps table with id 46f3ed75-471c-5f07-9493-0a36a98f28b3
0e82f0d3-9d3a-5abd-8883-cc7f60044a63	\N	2014-02-13 15:46:56.212298	create data on tps table with id 3d1d79fb-c367-5029-9d85-076a6922182a
f032566a-8ecf-51e9-ab36-e38aeaf11551	\N	2014-02-13 15:46:56.212298	create data on tps table with id e5747a83-8ed3-5242-b921-7d784046d946
8aabfebc-6024-591a-bebb-703f89a851de	\N	2014-02-13 15:46:56.212298	create data on tps table with id acb3200d-640c-5e22-8134-3f1618c514a9
3f77e6b4-e612-53cc-a1f1-e18456f6f07c	\N	2014-02-13 15:46:56.212298	create data on tps table with id 3b02df01-37a1-5c9f-9249-21366b23e178
d4fcd0de-5c4b-59f8-87bc-ad81ecddbcf7	\N	2014-02-13 15:46:56.212298	create data on tps table with id aa3f89cc-4d71-5994-8654-c0055703421c
621139f6-a98d-5357-a40c-1a3580d09d4d	\N	2014-02-13 15:46:56.212298	create data on tps table with id fb498af4-7c09-5cd8-b244-4a20366b4a5e
fa2938cd-e830-5a63-a4c6-d3fba9dd2ad4	\N	2014-02-13 15:46:56.212298	create data on tps table with id 592f58f8-5b5c-5e36-bec7-56632c6549e8
c81ad41b-a9ac-5aef-b09d-911e3b7eb4e2	\N	2014-02-13 15:46:56.212298	create data on tps table with id 907d000e-10b2-5dc4-bd40-2f5c283859bb
aa03bc93-82d0-52a3-9630-70232b42c123	\N	2014-02-13 15:46:56.212298	create data on tps table with id c9c31780-f216-55ff-b292-1218cf836877
30a8c033-e265-5097-af4c-e203c445904d	\N	2014-02-13 15:46:56.212298	create data on tps table with id ffe4db05-74e3-590c-bb3d-55e7ddd10fa4
63f5853b-6a41-5711-83ad-1f6bca43b67b	\N	2014-02-13 15:46:56.212298	create data on tps table with id 8a6fbb43-681d-551f-a30d-21901b01d0f7
c988398c-1523-53bf-942c-9dfc40e8f38b	\N	2014-02-13 15:46:56.212298	create data on tps table with id ca37b9ab-d258-548e-8c87-7911a7a40603
2b310712-a87e-5b67-89ab-5a0aca9bb897	\N	2014-02-13 15:46:56.212298	create data on tps table with id f8448ec7-c894-5360-9093-75693a5699c2
b9b1b43f-e268-57de-b5c1-bf8d0d10aeb7	\N	2014-02-13 15:46:56.212298	create data on tps table with id 0ffd6f40-ebb5-5f87-af0b-f8c02db8318d
dec21435-9733-5251-a12b-3021c60bcf63	\N	2014-02-13 15:46:56.212298	create data on tps table with id 1fdf85f7-056b-5832-9a9a-f2d3b0a45c0b
b62ddee4-76bc-52e0-84ec-445ad92bf9d9	\N	2014-02-13 15:46:56.212298	create data on tps table with id f3f0858e-17d2-54ec-ba38-b10c95a11059
bf07c325-89ba-59ec-9625-ca61bf6f9756	\N	2014-02-13 15:46:56.212298	create data on tps table with id eb4c11ed-de15-5abe-ae0a-a51e8c5ebd05
cabd034b-950c-5eb5-b7f8-88c84cce07be	\N	2014-02-13 15:46:56.212298	create data on tps table with id bcd223be-a541-5123-a57c-d45ab06e2987
2b767a6d-76cc-5684-ab46-4d1ca0f8b00c	\N	2014-02-13 15:46:56.212298	create data on tps table with id f26318f9-8bdc-5cb4-ad66-d245c21361f6
1bd1146f-d35e-54ca-b76d-004699f40f0b	\N	2014-02-13 15:46:56.212298	create data on tps table with id d8e8f03c-b513-503a-84e0-3d6682eb1a19
799c3f24-db2c-5da1-98db-540098911a7f	\N	2014-02-13 15:46:56.212298	create data on tps table with id 5a027d31-769c-5793-b388-a9f52edce5e0
d808ba90-a0fc-5b14-a08a-9ed68c34e7e3	\N	2014-02-13 15:46:56.212298	create data on tps table with id 4fe1fbcd-6eff-5c1a-beb5-191cd2ea57c1
29b6c5ef-e942-5247-a98c-4e422429acf6	\N	2014-02-13 15:46:56.212298	create data on tps table with id a229026a-dfd9-55dd-98ea-c6fb415ad284
c70a89ee-c979-545b-8006-4ea09865c106	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6fdca12c-14ee-51e2-88f9-7d435475f3a0
362edb2b-c511-5d63-ad3a-39959f0ab367	\N	2014-02-13 15:46:56.212298	create data on tps table with id 425624b6-2d65-524f-b3fa-869751e3e61c
58553601-31d6-52b5-910b-0dd573edfe8e	\N	2014-02-13 15:46:56.212298	create data on tps table with id 2e2ec1a6-bb1d-52f1-9069-02deb4818326
72d2b35d-8575-5047-ab4b-c0c86fa2d2ad	\N	2014-02-13 15:46:56.212298	create data on tps table with id b9e64f4a-c9c0-566d-b735-fa001f7865f9
ad195dd3-af1a-58d7-8535-e52bd6e6d375	\N	2014-02-13 15:46:56.212298	create data on tps table with id de02b435-2e3e-5ea6-bd8f-dd231674fbbe
524aa290-dc92-59fa-9f42-48ddfc49ef53	\N	2014-02-13 15:46:56.212298	create data on tps table with id fe4ce5cd-2bf1-51c8-93e6-4e2f5eb9fc68
1580ae4c-92d5-524e-8c79-5ce68c5cb0b4	\N	2014-02-13 15:46:56.212298	create data on tps table with id 4245cba8-047b-52af-8339-c3bb8d1d00e5
c25b3b27-b443-566b-b8e1-56a5d4b3218c	\N	2014-02-13 15:46:56.212298	create data on tps table with id 703e7d77-86ac-52ce-af21-ea39ea7d2ee2
4962f97e-1cc1-5745-963a-11a16ec6eb25	\N	2014-02-13 15:46:56.212298	create data on tps table with id e595bb23-9fc3-55ab-9e45-d89b4d8da1c5
5b28e497-3fb1-57e3-b688-885d70295b9e	\N	2014-02-13 15:46:56.212298	create data on tps table with id d0f58d7f-087b-5e44-8bbd-25dda20c21c8
fee4c76a-1d1f-52b6-904c-155765a962d3	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6a159b44-d74d-5a37-832f-d22d8d68f628
4ce49a02-c886-552b-8fc8-894a499ede09	\N	2014-02-13 15:46:56.212298	create data on tps table with id 1f6179aa-f92b-59fa-9120-0ceeee387147
a240743c-7fd3-5e24-8720-1a9365d501af	\N	2014-02-11 21:16:33.114754	create data on tps_surveyor table with id 23392589-fde8-5f1d-81b4-25f97468a6ca
14bc387b-9e1e-504b-a6ef-5fee61ac9687	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 86d13a98-277c-5029-a5e0-cb279bed870a
6971709e-f974-5829-a9f2-57d2023213c6	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3504ff10-18cc-5dcf-b6d7-51b9a3ed70c1
d20c8f4d-db48-513c-a74f-0cb1f5545065	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id cb3df3ae-02b0-58c3-972f-8f79d657bdf5
2d4c992b-8544-5c28-8534-e3a94c977904	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 590f9cae-c4f1-5d90-87dd-cc9fa3f3a48b
31fd0e79-3fdf-58b7-a99b-9e3ce1b5e84b	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id bd9eeddb-c4f0-5917-9a92-dc419332edca
041088dc-2f40-53a4-a13e-7c08a2536482	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 82a8f8cf-2ada-5593-a145-2405db5d16f4
2715b164-8180-5045-9768-6ebc382654a0	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 8410649d-8cdd-55f3-bba8-613f231030d0
30a567f2-c5cb-5de6-b395-1d7a9c8026d9	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3d8bcfde-d147-5d51-924b-14447a6c66fd
e0fd2c23-51bf-5fc9-bd31-485799979caa	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 39b41a0f-80fc-58e3-929a-a00ea54a32a6
165b00cf-1266-5b29-9ab8-1918cbbe5eb8	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 61e70aa8-06d1-5821-85e8-d11181f8093d
6fb02f92-ed21-55f0-b3da-f365ec2dbf05	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id a75266b6-b348-5aa0-8785-b1f430862234
14ad880e-4a76-5f73-b28b-75e6c6591831	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5ba8a345-12d1-57c4-b35b-e0c929c50450
36c95d30-2854-5456-9214-a144ad3ef99c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1a008278-9295-5794-b276-0045a4ce406f
0307e9dc-e673-5cd5-a11e-96bf68847c7f	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 31c4f9da-59ae-55c5-9dfa-8c7ecafb9253
c0cfc8a4-7be8-5a7c-997f-c5051fb95d72	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3a42fd4c-b45f-5362-a40c-aeeb66dfb6ea
e10d5eb6-9d5e-521d-b381-273b10e6e505	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b99b9557-0481-556b-a5c2-b5807337dd88
ac97cd36-bea5-5be3-ae29-44a8eb623f95	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 576b6b72-648b-5652-9003-24099813d445
e03ed611-2337-5f78-b677-b383dde23be2	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id c54ac723-9023-5a24-89f2-4d9ec9cc6a41
31741941-2262-55fb-86e4-d2519065d641	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 166086f3-0180-5e93-8386-aedfdb37d9fc
9cce2200-4149-532f-a5a2-02175712e057	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 03c4fa47-6d01-5bf9-83b4-ce09693646a8
d7000387-9fa3-5f6f-9a62-c7870ddbc16d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 714f1147-e3cc-5c87-8e3c-4bd4774c728f
b30c3082-8370-50a1-8c29-46b59a83c45a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 43797aaf-c40e-58d9-87ba-f63dc904763e
2be9115c-5c50-5d7a-a5f2-1290461a6a64	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 2ea14652-4c96-5156-aa76-857223bc70d9
f6a01e7f-fcda-5460-a43a-4621f87285bd	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3cbbda5c-d8e4-5ac8-911f-50d5f2cda1b9
484e1377-3f2a-5732-b63c-4149e0e023a0	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 27ca348c-2af6-5564-94ad-8c945f968362
5027a85a-b0e2-565a-b454-92d4a54caea1	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5b8f01e3-41e2-574c-90fb-510ca1716825
b66dd106-2631-5701-926b-7a2260e4943d	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id f318f842-d757-5ef1-b359-ec10848118bf
3996335a-b041-5755-8e88-480bfef06a37	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e9e6f91c-1ea7-526b-b2d8-99a61d64dce0
d79cc7fb-0cb7-5968-883e-f117a0dec32c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 88bb805a-1c9c-5231-b3f5-d87d586f6ec9
7b41c47c-bff2-5eb5-936c-478a7160c63c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 01588caf-f73b-5aa2-b825-d4fb18807e61
1c04bbb7-3d12-575b-9f21-c7baf01f20ab	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b84fb53c-642c-5e69-81b4-3720b85599a1
db595933-b8c3-5a98-99a0-4b9dbae7bed5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e924e33e-acc9-5811-81d2-0dc599344dda
47d0a83f-b02a-550f-bf83-3a0bede5b5b9	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 33ac51cc-d861-5954-852c-411799bdd0b8
8468652b-f704-5b5e-91d8-a614eb300a0e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3f46b0dd-c3b1-564c-81ca-db79743595f5
033a42b1-9c28-5fdb-b320-e96a07ad61bb	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 0ce541d1-6182-565c-9f4c-95fe85ec4cdd
b6562dbe-fe7c-5041-b1bd-2cef114398f2	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e852f094-bdd6-5bc3-a912-3149e59b3056
8308a882-49cf-5adb-8807-0c60eb2c874a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3c1eb231-0883-550e-b470-d8be7fcb80cf
7580336d-4322-5acd-894a-d42c71c3dedb	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 7072e657-f143-5239-a7d1-0e3257b931b5
63fbc2cd-8426-55ff-88f2-708e2c530c01	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id fe8b1356-24ff-54e9-a2e7-e472939015c1
f1bfa906-a8ec-5563-b1d2-8b4f81e5e97c	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 89f7e4b5-5559-5c3e-9582-19eaf81eb879
defa8392-35a0-5aee-b0a0-e201c89fb822	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 413d29af-1f2a-5151-9853-0d9ec54f3eb8
41f88e96-05f6-5dc8-80fc-dfef908315c8	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1ca24479-925e-5696-9f07-16c0f001ef01
e04699ba-48ff-5bd2-8515-41d198e3662f	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 3f050918-01d5-570b-ba35-62ecab6c37dc
e38eb073-1540-5cfd-9e87-3c0f89a5f934	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id a964045f-f885-5f89-8310-228d49bbc1c4
bab737f9-b95f-57a9-9869-9baa6b3cfd5f	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 002782df-7858-50e5-9612-54cb4ca08de3
841ae315-cd49-57fe-9de9-dfdfc8e51073	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5faf61dc-456c-5582-af7c-e00461b5ecf5
c2dd81a6-67ec-5cfa-9144-d84f45cdc5a5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 44427045-b855-56ae-bca1-20d5f2ef991e
d2982a91-ca8f-5091-98aa-b4407d59a2a7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id fb761508-58e7-58c4-bc95-d4b63a057a43
92816a69-fe2e-5bd7-9e02-40b232d2c71a	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 62255842-ac8a-55ad-9ff0-74c29fa53413
ee48c1bb-8650-598f-b919-50271dbd0452	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 0519b9c3-b1bf-5d8b-b025-aaa1d2ffec67
41853292-4895-5efb-9b87-2644e241d9af	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 071be393-107a-56fe-a932-536513f77296
f7dade77-a9b4-5f32-b023-c2e22eadada8	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5b0b638a-2db0-51e9-bb6e-3318843bf435
58d7db8d-67a8-507e-a3a0-a638cfaf6128	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 1b87d1fc-43df-5623-acea-e3efb98785d6
88bc17f2-594a-5097-b0c8-a42ba8e6d9b7	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5699fbbe-7c9b-515c-8df4-8a8bdcfe638b
ab0c312f-f66a-506c-9683-3cd2f5fc8e28	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 91924471-8213-5cb3-8c6e-b02f91d6c6cf
028cf67d-3147-57df-9e0e-6dfbaa598978	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 98cfefa5-4760-593c-8496-c91abe8fc278
42a4f330-c1af-5371-88b8-0a847095a3a4	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 35b36d94-7bf3-51a0-a920-b2878e1e3cd9
a545e0cd-2073-56a0-8c45-6c8eff9869b5	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 14716e48-1862-522b-a564-11051beaaa08
d0309d75-e036-5711-a357-9a5450055d85	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 72b51198-518e-5636-9c3f-387d78e18272
47563c0a-28aa-51ee-91d2-5e50f290dcbe	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id aa3207ac-6ca8-5fa2-8492-d628c6669a7b
f14aebd2-11c2-51b3-be95-6bb3a2a10df9	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5214bdd3-103b-5a22-87e7-785f60955a31
b1b7e54e-1650-5d2d-b900-af421821c7cb	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 01a8252d-6ea8-52df-a1ad-735cf17d6f50
cbd2d008-3664-5953-a515-44feda64b5e1	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 66966a9d-5e3f-50bf-a613-846b467fe0cb
2b03c591-e6e3-52fd-a2e0-23d7e9e20c42	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id b6ec62fd-95de-5725-a60c-f6bb6c889cdc
26695403-3c30-5dc6-956c-b32ba92ad84e	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 8a7a38f2-561e-5191-b2be-a290940b142d
a629cfb7-29a1-5efd-a4df-d582c6102293	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 5e53e2cc-7f36-5d3f-b5b5-2e71c4edb120
3b865f82-e2ea-5bfe-ae19-0786cf05b79f	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id 36d44ef8-f89b-5de9-a85d-aad609c4f239
cf474bbd-051c-5e14-b98d-b12fc00c2008	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id e98c15f4-c57e-5c24-badc-98c97ee0dee8
85352d6d-0106-5841-9a5b-9e1195a1ec19	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id dbb750b5-0872-526e-8da9-ed92daca74af
68becb32-3447-59c1-9f11-c9dba398d0c3	\N	2014-02-05 14:59:47.595	create data on tps_surveyor table with id f50aa319-25e1-5121-9ed0-d1f66574328a
a50e8435-dd12-570e-8a9b-6dc08ce6a43e	\N	2014-02-13 15:46:56.212298	create data on tps table with id 3d1d79fb-c367-5029-9d85-076a6922182a
f8fc1613-6973-5dea-9ce5-6cf13dfea1a8	\N	2014-02-13 15:46:56.212298	create data on tps table with id e5747a83-8ed3-5242-b921-7d784046d946
c49728b3-c550-5dad-b663-ad03e454974b	\N	2014-02-13 15:46:38.470193	create data on tps table with id 48d23cea-4061-5878-8c95-e539daffebfd
b51be3a8-d513-5721-9127-c023cb0072fa	\N	2014-02-13 15:46:38.470193	create data on tps table with id 0d97ac42-a2aa-5159-ab49-226ae9fd8ae2
21be4d2b-bcd5-5d69-8ff8-91ead13669c2	\N	2014-02-13 15:46:38.470193	create data on tps table with id f3932ce3-ddb3-58a7-85ca-0839ac68484b
9ce85921-b05a-580b-a3bf-a69aa744469d	\N	2014-02-13 15:46:38.470193	create data on tps table with id 69938d98-467a-5067-adeb-5ba5bf64c4aa
73555923-916b-5e15-a21a-741cdc0b53ff	\N	2014-02-13 15:46:38.470193	create data on tps table with id 44b402ec-8a47-589b-9536-5a7255ab05ff
9cdf3fe5-8d52-57ed-9803-5c35c9aa120b	\N	2014-02-13 15:46:38.470193	create data on tps table with id 896df16a-6eac-5b34-bfac-81eeed64b81c
04f2a809-710d-538a-b266-c610155839ed	\N	2014-02-13 15:46:38.470193	create data on tps table with id 52fcbf94-9832-5c83-acb1-2c2c64550366
542435ee-8a93-5ad0-9904-54d164a2cbc2	\N	2014-02-13 15:46:38.470193	create data on tps table with id f2279e6c-c863-5142-bc32-ff1f92f95f2c
081fd4a3-aaf9-5f61-a83f-b6b99f6ee640	\N	2014-02-13 15:46:38.470193	create data on tps table with id 5023dc90-7f15-5ea3-b6bc-9ee2b170a3e1
8d7bb8bd-e622-5972-85cc-db24afca280b	\N	2014-02-13 15:46:38.470193	create data on tps table with id f2e9233a-55dd-543a-a8bf-5cdd0cfbb74a
0d10d7dd-07d8-5c90-b58a-e5f10e81307c	\N	2014-02-13 15:46:38.470193	create data on tps table with id 40944e3d-5b96-52ec-8983-e08ca3db3fa9
b8722d9b-d37b-56e7-8c25-f29b2ea5ab94	\N	2014-02-13 15:46:38.470193	create data on tps table with id 243e6df2-8a7c-5b05-8d26-29d5e36bd673
3f613b32-58b3-53e9-b628-17ca4bdb52b9	\N	2014-02-13 15:46:38.470193	create data on tps table with id ab513a59-38ab-5685-b75c-5116953a95c9
4854877a-675c-546f-8b47-61169064efd1	\N	2014-02-13 15:46:38.470193	create data on tps table with id efa0ada0-fc3e-54da-b2a4-699b1bf8afac
3936d1ff-7e37-5735-90dd-e021eb05381a	\N	2014-02-13 15:46:38.470193	create data on tps table with id 60d64ae1-8ead-51b2-9c81-ce40ce65a980
fa5188e7-f8d9-50e9-8241-7492c2f943b2	\N	2014-02-13 15:46:38.470193	create data on tps table with id d86839f3-95ad-5da9-8aa4-da86d7614cef
ec6bd925-8e53-57f9-8a21-f2553df9a1c4	\N	2014-02-13 15:46:38.470193	create data on tps table with id 95f4f7c2-c3e9-582a-b7b2-4ef04ad2b38e
b10a0dfd-7fb3-5d8e-a05e-4324db837db9	\N	2014-02-13 15:46:38.470193	create data on tps table with id f01463e2-5741-5c6c-8df2-f86ef722af01
37970e8b-6cc3-535c-b61a-48480910fcff	\N	2014-02-13 15:46:38.470193	create data on tps table with id f702eae1-2408-5b91-8a94-a416aedcdb12
e3622070-985f-5c62-9495-100b18777d46	\N	2014-02-13 15:46:38.470193	create data on tps table with id af614633-c97e-50c0-ba36-6ddbcaf6da42
62ede2be-ed02-54c0-adad-1c63247d5c4b	\N	2014-02-13 15:46:38.470193	create data on tps table with id 484c00ec-a0ed-593f-8c72-707037be8adb
7f4c6495-864f-5ea1-a340-e06e81b05bdf	\N	2014-02-13 15:46:38.470193	create data on tps table with id a0187f0a-5e88-50c6-adaa-d72495d1db7e
0b01d5aa-9015-55f3-a45d-c5d7a9232c02	\N	2014-02-13 15:46:38.470193	create data on tps table with id fefd9671-10c1-5c09-bc16-35dd015f8d93
ff59d437-9057-500d-8881-8ed2638385ec	\N	2014-02-13 15:46:38.470193	create data on tps table with id 81d48815-1159-55b4-820e-32508b256c0d
423ee1ff-7417-5590-8784-7f854791dbcb	\N	2014-02-13 15:46:38.470193	create data on tps table with id 9df1c5f4-b52d-59d1-a3d6-762974578a96
978336b1-e232-53f6-a4b4-402174c59ff9	\N	2014-02-13 15:46:38.470193	create data on tps table with id b1f11737-2f4a-5c81-84ca-e6702a440ecb
0a6fa1c4-2c17-55e4-ba89-965a74ee6b37	\N	2014-02-13 15:46:38.470193	create data on tps table with id 29ac3758-1a0a-5d67-9b18-fb63b3edda34
c2b7b81e-5dc7-5897-bb2d-cb6afaaeea5f	\N	2014-02-13 15:46:38.470193	create data on tps table with id 11f5a0f2-fe57-58a2-89cc-139f47ef6ae5
350ffd1d-647a-5788-8dbc-d2c5f0b2ab66	\N	2014-02-13 15:46:38.470193	create data on tps table with id d4bd8c17-0f14-513e-9f35-f316832a91d7
436771c0-6a88-5163-85fd-47fd9cbe53c9	\N	2014-02-13 15:46:38.470193	create data on tps table with id fc3fbf83-b5b2-5454-8376-97e0ac073702
e8c7a0a6-0f3e-531d-b628-6245acf06665	\N	2014-02-13 15:46:38.470193	create data on tps table with id 2451c698-750d-5019-9c49-93f20a72aab5
7f421304-4f17-5384-9a04-632d960a3ecc	\N	2014-02-13 15:46:38.470193	create data on tps table with id 6ad50776-b8c9-5f11-ac01-b9e4cbfbab1d
9a8b2afa-2081-5a3f-8bb1-83bd0431943e	\N	2014-02-13 15:46:38.470193	create data on tps table with id b307f96d-5d87-5b79-8b72-0813fb1afb5e
27b9068a-990a-594b-a0c1-e90ddbd237d7	\N	2014-02-13 15:46:38.470193	create data on tps table with id 92c01e8c-6194-5086-98c7-0a0ea533a6be
ac9d78d3-15ec-522f-b21a-9ddb90a35ded	\N	2014-02-13 15:46:38.470193	create data on tps table with id cd6d0929-821c-5119-a344-356b40605366
246b6a8b-82f6-5fa5-8feb-33883bade6b1	\N	2014-02-13 15:46:38.470193	create data on tps table with id 07ab5dae-e532-5f5d-a14b-188229407134
f3e10434-6b7c-5223-9353-88c3942c82db	\N	2014-02-13 15:46:38.470193	create data on tps table with id 980e2299-b9c8-57a9-ae4a-b8360619d82e
3bb8cd02-8832-54af-8841-cad1955fe046	\N	2014-02-13 15:46:38.470193	create data on tps table with id 7fd9d6a3-fd47-5974-96a3-43543b45ed6e
d478d83e-a096-52e0-93a8-04fed4b4ed33	\N	2014-02-13 15:46:38.470193	create data on tps table with id 743aa830-b7d1-5d53-aa31-b1b2c1ca2172
766d1250-0b45-5205-9513-b38ce844aa9b	\N	2014-02-13 15:46:38.470193	create data on tps table with id 64ee7f29-8f81-5e0a-9993-1362337c2524
c9285552-4d9c-5331-8834-fcf8cb96a077	\N	2014-02-13 15:46:38.470193	create data on tps table with id babc2931-883f-50ae-b6e1-9386e05e5bc0
608d53ce-b0f9-5e4e-a86b-bb3ad9913c4c	\N	2014-02-13 15:46:38.470193	create data on tps table with id 7a9fd53e-4567-5b40-8549-d35259dcd16f
5144876a-c17e-54d8-aa04-fefc0d83bf89	\N	2014-02-13 15:46:38.470193	create data on tps table with id bcb86e32-62c5-5976-9843-0f3dfc062867
5961b620-c4f3-5651-95f0-ce6761dfa138	\N	2014-02-13 15:46:38.470193	create data on tps table with id e30c82cb-f1fb-503d-aae5-8d5aa623eb20
b58d4fcc-abe5-55b9-890a-5de4b9c824d7	\N	2014-02-13 15:46:38.470193	create data on tps table with id 55988ed6-3656-5484-ade6-932146e78f8a
e4abace0-4c2f-5d6e-a9d0-1004c036aad6	\N	2014-02-13 15:46:38.470193	create data on tps table with id 0eacb61a-0bb5-54df-bdd0-168c510e2ce5
e8dd1400-74c5-555b-93d4-6d1edf4d189e	\N	2014-02-13 15:46:56.212298	create data on tps table with id 64e751d7-c422-5c2d-bf80-367f2d62b53e
ce1fac6e-5c05-5501-aed0-731024318979	\N	2014-02-13 15:46:56.212298	create data on tps table with id aa08a4dd-cfdd-5504-8b7e-e9c4b7cd9cfe
d8c9a762-219b-5418-86f4-bbdc7a038035	\N	2014-02-13 15:46:56.212298	create data on tps table with id f5f54edf-9ac5-5344-980e-89612276d06a
1b588f28-6c09-515d-8ad7-e7ab892cd299	\N	2014-02-13 15:46:56.212298	create data on tps table with id 102be1da-7933-55d9-bf0f-a9f8c74ca341
756d1bbf-fc79-5666-bd39-0d2cd3897ef4	\N	2014-02-13 15:46:56.212298	create data on tps table with id 0eec1d73-5048-5056-8435-11605a6d97ad
7e66bd45-ad42-5795-9778-465a6e634246	\N	2014-02-13 15:46:56.212298	create data on tps table with id 64b4663a-d6c8-5236-9326-fb4c2034eede
2af13f79-e4e7-56d0-9df9-bd45168b3e46	\N	2014-02-13 15:46:56.212298	create data on tps table with id 62bff016-ecb1-512d-a886-6478c6d83c61
8e40888e-c8b2-5d0a-ba19-23d9c7491437	\N	2014-02-13 15:46:56.212298	create data on tps table with id 28c4caa0-d50a-5438-a477-780bc4b10ddd
6bb1ea8a-0b16-5e44-bf04-f76a9f694f1f	\N	2014-02-13 15:46:56.212298	create data on tps table with id 3187c8e6-58da-53b3-9847-09e9c62ebfa7
ef981e9b-f9dd-5d65-bda7-0fd1452c4e40	\N	2014-02-13 15:46:56.212298	create data on tps table with id 351d0dab-9055-5b8b-92b3-be167e009cb3
1d19f9a5-ff78-54ab-aa3f-a3cdc82a3fd7	\N	2014-02-13 15:46:56.212298	create data on tps table with id 4372bb14-fde6-5083-8970-73b373d2c034
fcb411df-5adb-5fe1-85df-901803b452d7	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6c5ef5f4-e609-5f94-a5d3-671774155ec2
dbacf671-d905-55e3-87a8-bcbc4dc804ff	\N	2014-02-13 15:46:56.212298	create data on tps table with id a5c54e33-b687-509e-84e8-7ca71e4fb5e8
49212134-d140-5c23-9ff9-382d1cb9774d	\N	2014-02-13 15:46:56.212298	create data on tps table with id 354e9924-3ef1-5b0d-8c75-186c9799a88a
53ea63a2-291f-5a95-8a7d-4db780247383	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6f41d5b4-50fa-577f-bb64-72fb41908c18
23e78b9e-9b05-500d-ba02-4b62104c8086	\N	2014-02-13 15:46:56.212298	create data on tps table with id c5b8211d-a92d-52f2-a1bf-ff41f8952707
7c90c4d1-9a9a-538d-8115-81efc82a2a55	\N	2014-02-13 15:46:56.212298	create data on tps table with id 420ae2d1-9703-5a46-92d3-b93f403c2532
e8b935e6-86e2-59ce-be9e-19c450e6f7df	\N	2014-02-13 15:46:56.212298	create data on tps table with id 912e5ef6-9325-5c43-8fe4-7e6d7ae75700
e6eb9479-0c67-58e3-8be8-6b493619d83d	\N	2014-02-13 15:46:56.212298	create data on tps table with id 46f3ed75-471c-5f07-9493-0a36a98f28b3
3eb6fb95-08b7-53e6-b170-bf9321fdeb44	\N	2014-02-13 15:46:56.212298	create data on tps table with id acb3200d-640c-5e22-8134-3f1618c514a9
3f3c180e-662b-5b4e-b575-411f1d54cbe5	\N	2014-02-13 15:46:56.212298	create data on tps table with id 3b02df01-37a1-5c9f-9249-21366b23e178
87298555-fec8-5592-88b8-d92b1565c3ab	\N	2014-02-13 15:46:56.212298	create data on tps table with id aa3f89cc-4d71-5994-8654-c0055703421c
67a8a669-6f65-58f9-be52-68e590fb89f4	\N	2014-02-13 15:46:56.212298	create data on tps table with id fb498af4-7c09-5cd8-b244-4a20366b4a5e
a83a59fb-04ed-5a04-bfaf-6404594f5d1b	\N	2014-02-13 15:46:56.212298	create data on tps table with id 592f58f8-5b5c-5e36-bec7-56632c6549e8
cea5f63d-0766-5598-b617-7086073ee924	\N	2014-02-13 15:46:56.212298	create data on tps table with id 907d000e-10b2-5dc4-bd40-2f5c283859bb
eb1360d1-ef06-51ad-b941-503afed0b4d2	\N	2014-02-13 15:46:56.212298	create data on tps table with id c9c31780-f216-55ff-b292-1218cf836877
81793892-e79b-518c-9705-12a02a5ecfdf	\N	2014-02-13 15:46:56.212298	create data on tps table with id ffe4db05-74e3-590c-bb3d-55e7ddd10fa4
0106f951-ff3e-5bbc-9f9c-7f477f4ab3e4	\N	2014-02-13 15:46:56.212298	create data on tps table with id 8a6fbb43-681d-551f-a30d-21901b01d0f7
a50ef672-946a-5fc9-911d-b5743b945303	\N	2014-02-13 15:46:56.212298	create data on tps table with id ca37b9ab-d258-548e-8c87-7911a7a40603
49929dce-07a0-531f-b784-7f86fb0b19ae	\N	2014-02-13 15:46:56.212298	create data on tps table with id f8448ec7-c894-5360-9093-75693a5699c2
4ed21441-7ba1-5606-b44d-9cb4df342073	\N	2014-02-13 15:46:56.212298	create data on tps table with id 0ffd6f40-ebb5-5f87-af0b-f8c02db8318d
9e38c748-cb91-5f4c-a3de-9ffde9ea5bcb	\N	2014-02-13 15:46:56.212298	create data on tps table with id 1fdf85f7-056b-5832-9a9a-f2d3b0a45c0b
44eb8a8d-f2b8-5aac-9d07-c0be94536245	\N	2014-02-13 15:46:56.212298	create data on tps table with id f3f0858e-17d2-54ec-ba38-b10c95a11059
8cefdb45-3609-583b-9c23-d523fdc132b1	\N	2014-02-13 15:46:56.212298	create data on tps table with id eb4c11ed-de15-5abe-ae0a-a51e8c5ebd05
eda9aee0-64d6-5923-82a6-94801b116574	\N	2014-02-13 15:46:56.212298	create data on tps table with id bcd223be-a541-5123-a57c-d45ab06e2987
8954001f-6f33-5c34-a931-c1b807436a78	\N	2014-02-13 15:46:56.212298	create data on tps table with id f26318f9-8bdc-5cb4-ad66-d245c21361f6
c11de190-5eaf-5404-aa3b-0147cb247e5c	\N	2014-02-13 15:46:56.212298	create data on tps table with id d8e8f03c-b513-503a-84e0-3d6682eb1a19
a0b6e182-8f59-5dd9-8df3-07b7567a21aa	\N	2014-02-13 15:46:56.212298	create data on tps table with id 5a027d31-769c-5793-b388-a9f52edce5e0
fc65a5e9-c812-5747-9217-300540e1394a	\N	2014-02-13 15:46:56.212298	create data on tps table with id 4fe1fbcd-6eff-5c1a-beb5-191cd2ea57c1
3980cc7e-a834-5eee-9128-13e7fd09250e	\N	2014-02-13 15:46:56.212298	create data on tps table with id a229026a-dfd9-55dd-98ea-c6fb415ad284
6514ad86-a752-5acb-96ed-f8987e1c17cc	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6fdca12c-14ee-51e2-88f9-7d435475f3a0
30fa6fe8-b721-5ecc-a478-ae6c0810a48f	\N	2014-02-13 15:46:56.212298	create data on tps table with id 425624b6-2d65-524f-b3fa-869751e3e61c
c9bf255f-8b16-5699-a040-8e6135f8ac5b	\N	2014-02-13 15:46:56.212298	create data on tps table with id 2e2ec1a6-bb1d-52f1-9069-02deb4818326
1ed7f760-d61f-5cd5-906a-014d455323da	\N	2014-02-13 15:46:56.212298	create data on tps table with id b9e64f4a-c9c0-566d-b735-fa001f7865f9
28598de4-3f86-5f32-b677-b6d99ed5d34f	\N	2014-02-13 15:46:56.212298	create data on tps table with id de02b435-2e3e-5ea6-bd8f-dd231674fbbe
751c8153-3c60-5c61-821b-ff95d762f973	\N	2014-02-13 15:46:56.212298	create data on tps table with id fe4ce5cd-2bf1-51c8-93e6-4e2f5eb9fc68
b90f00e6-4351-55d4-a4cc-42fd224ec715	\N	2014-02-13 15:46:56.212298	create data on tps table with id 4245cba8-047b-52af-8339-c3bb8d1d00e5
fc7dc709-96cd-5737-9034-9a015d4f8e22	\N	2014-02-13 15:46:56.212298	create data on tps table with id 703e7d77-86ac-52ce-af21-ea39ea7d2ee2
3bd7e31c-70ee-5a52-8d32-5079af7d3a42	\N	2014-02-13 15:46:56.212298	create data on tps table with id e595bb23-9fc3-55ab-9e45-d89b4d8da1c5
31ae69e8-e4bc-5c00-9214-69646a2d4612	\N	2014-02-13 15:46:56.212298	create data on tps table with id d0f58d7f-087b-5e44-8bbd-25dda20c21c8
5a724ece-4cb4-520d-a2bc-2f069b20a98f	\N	2014-02-13 15:46:56.212298	create data on tps table with id 6a159b44-d74d-5a37-832f-d22d8d68f628
8d362e77-1fc4-5ca0-92a9-006ca8e9787d	\N	2014-02-13 15:46:56.212298	create data on tps table with id 1f6179aa-f92b-59fa-9120-0ceeee387147
fedf5db5-22fb-5422-9d4c-8c8b568f25c5	\N	2014-02-13 15:46:38.470193	create data on tps table with id a44d9a1c-69f6-58fb-ac90-c2378b56dd67
58306523-2ad8-5ac3-b762-45b3a1d547f7	\N	2014-02-13 15:46:38.470193	create data on tps table with id fccfdb3b-e06a-58a6-a69b-eaf7781b7366
3fb1dc24-f6ca-5d43-ab3e-15954508b085	\N	2014-02-13 15:46:38.470193	create data on tps table with id 7d1cad70-8fa4-5571-8c4b-c895b1f02308
01aff311-e594-5f0c-974d-685775cae8dd	\N	2014-02-13 15:46:38.470193	create data on tps table with id d2577e03-66ba-5606-9d2e-7d5f0b53db66
a36579d5-11c5-5dbf-8267-b7d4c686c4ae	\N	2014-02-13 15:46:38.470193	create data on tps table with id 66201c98-8808-55d9-81ee-e1dc2e795a37
d8a7478e-01b2-5b34-ad49-561ccf382d93	\N	2014-02-13 15:46:38.470193	create data on tps table with id 9c669fb1-797e-5741-a6f3-55a02897090b
f28fd85e-370c-5f29-a0b4-8dc322c425c7	\N	2014-02-13 15:46:38.470193	create data on tps table with id e1adafaf-fffd-5b9c-9a77-64fa3c4b9289
6c08fda6-1e93-5ab3-ae7e-ca42f5267c9d	\N	2014-02-13 15:46:38.470193	create data on tps table with id 4ca10400-b585-5c21-8f28-c8b95e17969f
aba467e7-5b4c-529c-838c-784ae05b1506	\N	2014-02-13 15:46:38.470193	create data on tps table with id f77f4ac3-4f55-5b4f-992c-0090fd61d5ff
6a2b8ad4-0d40-5dc1-851f-7f8acedd72eb	\N	2014-02-13 15:46:38.470193	create data on tps table with id 0f5be733-49ef-5d9e-b5f5-dfe9883caa7d
309742e6-044d-5973-8201-063facc2f9c2	\N	2014-02-13 15:46:38.470193	create data on tps table with id 1e3a0735-b5b6-500e-b5f8-f3d00fcc7070
a26fe527-058b-5e42-81bf-f84f30e83d13	\N	2014-02-13 15:46:56.212298	create data on tps table with id 04a1ccf9-0b2d-5101-8542-7ded87feb741
2eea9c2a-eb59-5db5-a113-321fd5c5ac9f	\N	2014-02-13 15:46:56.212298	create data on tps table with id 992c27a4-6dc1-5710-9433-cd58281c285f
302ee511-8119-5625-bed9-c2cb27b652b1	\N	2014-02-13 15:46:56.212298	create data on tps table with id d02eed5f-da30-5787-90d9-8b4d19ed94b3
\.


--
-- Data for Name: menus; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY menus (id, group_id, nama, link) FROM stdin;
\.


--
-- Data for Name: mpilkada; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY mpilkada (id, id_fk, parent_id, jenis, description, status_id) FROM stdin;
ec8ece37-cab6-52e1-8bee-3faa8613f0d5	e97b7f4b-679c-581f-9ac6-a2067960f17c	e97b7f4b-679c-581f-9ac6-a2067960f17c	0	\N	1
e989f899-b390-56d1-a59c-a25df5e8c7bd	1f779dfd-a17c-5b35-a5d4-978152323e0d	1f779dfd-a17c-5b35-a5d4-978152323e0d	0	\N	1
8e7081c0-ff97-5ed0-a6e7-9bda811ffb2a	c5d7ced3-40d5-58c3-a093-de9982bb8402	c5d7ced3-40d5-58c3-a093-de9982bb8402	0	\N	1
3973a3d8-740e-587d-8d42-beb4fbd99bf0	a7119ade-f30b-5c7e-bb50-20e51ab6e924	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
68d7fb02-3670-537c-9c82-12b4600c3f8f	fb37211e-6d16-5a72-a593-04a7fe58623e	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
9bf73845-ff69-5ce3-a93e-369490bcfc68	d3c79744-91e3-5763-8633-591bab308d14	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
c7fc9b33-b9a7-5192-8fbe-4b39c31bc5c5	47a39ff6-3887-514f-8dae-0480d575d786	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
41f4d62d-8e34-5f05-96c7-1a67ac8a915c	41bf8d96-d5bd-54b9-acf7-9f5cf98a1728	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
2887eeea-bb87-5ea4-b24e-476be4d088b9	1edade44-24f6-5fe5-9fce-304bea00fdb7	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
a04033e9-2cbc-5853-b3dd-f31574c254b1	0ef5a01f-5f33-540e-b314-634529fd6b97	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
ec0b1a2e-ac0c-5b24-99e7-ebf181bd3135	e97b7f4b-679c-581f-9ac6-a2067960f17c	e97b7f4b-679c-581f-9ac6-a2067960f17c	0	\N	1
22de89ff-2fe2-59d1-914c-bd974f24539b	1f779dfd-a17c-5b35-a5d4-978152323e0d	1f779dfd-a17c-5b35-a5d4-978152323e0d	0	\N	1
dd86788e-2e3b-5f2b-8898-b31df35092c2	c5d7ced3-40d5-58c3-a093-de9982bb8402	c5d7ced3-40d5-58c3-a093-de9982bb8402	0	\N	1
0cc744bf-b939-5e1e-ba1b-5f4013173ab8	a7119ade-f30b-5c7e-bb50-20e51ab6e924	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
c9b91f2b-0436-56d2-86bb-1ab59f54a781	fb37211e-6d16-5a72-a593-04a7fe58623e	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
63fea869-309b-5d67-bd97-63c51c4b1039	d3c79744-91e3-5763-8633-591bab308d14	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
6e831f13-403b-5cae-9753-3ca601543b87	47a39ff6-3887-514f-8dae-0480d575d786	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
afb5832d-e647-5a90-8c63-b0fc73e4c97b	41bf8d96-d5bd-54b9-acf7-9f5cf98a1728	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
246ef1e5-4742-5fcc-8515-50ad38c11f72	1edade44-24f6-5fe5-9fce-304bea00fdb7	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
c4432675-63a6-51ff-b4c0-62501e7d2a59	0ef5a01f-5f33-540e-b314-634529fd6b97	c5d7ced3-40d5-58c3-a093-de9982bb8402	1	\N	1
\.


--
-- Data for Name: pilkada_event; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY pilkada_event (id, mpilkada_id, tahun, description, status_id, createdby, createddate, updatedby, updateddate) FROM stdin;
4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	c4432675-63a6-51ff-b4c0-62501e7d2a59	2014	Pilkada Kota Malang\ndengan calon:\n1. ....\n2. ....\n3. ....	0	\N	2014-02-09 23:12:46.252794	\N	2014-02-10 13:05:13.645511
\.


--
-- Data for Name: propinsi; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY propinsi (id, kode, nama, createdby, createddate, updatedby, updateddate) FROM stdin;
e97b7f4b-679c-581f-9ac6-a2067960f17c	33	JAWA TENGAH	\N	2014-02-09 13:09:39.89	\N	\N
1f779dfd-a17c-5b35-a5d4-978152323e0d	34	DISTA YOGYAKARTA	\N	2014-02-09 13:09:39.89	\N	\N
c5d7ced3-40d5-58c3-a093-de9982bb8402	35	JAWA TIMUR	\N	2014-02-09 13:09:39.89	\N	\N
\.


--
-- Data for Name: sysparam; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY sysparam (name, val) FROM stdin;
\.


--
-- Data for Name: syuserlogin; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY syuserlogin (id, uname, pwd, cdate, level_id) FROM stdin;
\.


--
-- Data for Name: tps; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tps (id, pilkada_id, desa_id, kode, no, status_id, createdby, createddate, updatedby, updateddate, msisdn) FROM stdin;
3d1d79fb-c367-5029-9d85-076a6922182a	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	f828604d-2010-5218-87e2-ae3e7f957cf0	KL	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
e5747a83-8ed3-5242-b921-7d784046d946	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	e75e0f3a-24f7-5960-97d9-cfdec9dfc487	FE	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
48d23cea-4061-5878-8c95-e539daffebfd	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b807caab-26f0-5eca-a9f1-6f0e81d0f6c4	FV	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	628155502030
0d97ac42-a2aa-5159-ab49-226ae9fd8ae2	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	979273aa-2433-5503-beab-db20fe1c521d	HB	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285791975758
f3932ce3-ddb3-58a7-85ca-0839ac68484b	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	72b865b2-b818-5be7-951f-eb04d2432e21	OP	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6289634876886
69938d98-467a-5067-adeb-5ba5bf64c4aa	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b621027a-d549-58a3-b29c-ea8f11728d16	KX	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285749024217
44b402ec-8a47-589b-9536-5a7255ab05ff	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	ab3020d1-37c6-572f-8320-e159391ac2a8	LD	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285647425152
896df16a-6eac-5b34-bfac-81eeed64b81c	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4e1d16ae-fcf6-5a49-894d-398b1b96f777	PS	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285785380398
52fcbf94-9832-5c83-acb1-2c2c64550366	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	8447b159-f515-53b4-bcd8-db7b59c87f93	FH	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6282233144676
f2279e6c-c863-5142-bc32-ff1f92f95f2c	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	1bf91399-347d-5580-a49e-c16d924125f8	T3	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285258721649
5023dc90-7f15-5ea3-b6bc-9ee2b170a3e1	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	cff92b6d-5120-5bd6-ac6f-8819f67feabb	RD	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285704294202
f2e9233a-55dd-543a-a8bf-5cdd0cfbb74a	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	d32bf146-05f8-5588-aaaf-ad0615fca0e2	YJ	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285853774437
40944e3d-5b96-52ec-8983-e08ca3db3fa9	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	e7f8c503-9505-585a-a98f-9ad529e08154	34	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285853774437
243e6df2-8a7c-5b05-8d26-29d5e36bd673	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	9e838bbd-6a5b-5c19-870f-f47926ed1168	AL	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6287876469000
ab513a59-38ab-5685-b75c-5116953a95c9	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	26e4c87c-93e5-5e1d-856b-93f4836177a9	RW	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	628974313107
efa0ada0-fc3e-54da-b2a4-699b1bf8afac	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	cfdfd13c-e357-5359-acde-853e538e2455	2P	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281515600695
60d64ae1-8ead-51b2-9c81-ce40ce65a980	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4f99719b-f66a-569a-b188-7b2cd44315c9	NO	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281515451630
d86839f3-95ad-5da9-8aa4-da86d7614cef	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	8a7e7e46-b5d8-5f86-adc2-dfbc42898a22	ZF	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285731978905
95f4f7c2-c3e9-582a-b7b2-4ef04ad2b38e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	928c7824-6116-5f8d-97a7-69cde1d72f92	IQ	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281515600695
f01463e2-5741-5c6c-8df2-f86ef722af01	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	f828604d-2010-5218-87e2-ae3e7f957cf0	F5	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285731978905
f702eae1-2408-5b91-8a94-a416aedcdb12	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	e75e0f3a-24f7-5960-97d9-cfdec9dfc487	OH	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	628155007019
af614633-c97e-50c0-ba36-6ddbcaf6da42	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	0dfd5d6e-5fc5-5717-b99f-5d60ca97a7cc	CT	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285755627585
484c00ec-a0ed-593f-8c72-707037be8adb	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	d4afbb5d-6a15-56a4-9875-c66c6f0b34f9	F0	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	628563007227
a0187f0a-5e88-50c6-adaa-d72495d1db7e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	18fb4c09-ea9f-597c-a84d-ae3c7c24e7ba	CZ	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285655516191
fefd9671-10c1-5c09-bc16-35dd015f8d93	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	d234ab1a-2cf2-5857-b8b6-d8512500b304	NB	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6289681986456
81d48815-1159-55b4-820e-32508b256c0d	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	870e77c5-7f5f-595e-a7f1-11f28ed51982	GH	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285604797757
9df1c5f4-b52d-59d1-a3d6-762974578a96	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	9b100053-b809-5cca-836a-d12ce14aca84	L1	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285746906160
b1f11737-2f4a-5c81-84ca-e6702a440ecb	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	25ff1ca0-9e6a-58f6-8dc2-fad72e0cc581	00	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281330142492
29ac3758-1a0a-5d67-9b18-fb63b3edda34	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	acbc14d0-5d4a-5540-bc59-457591795af5	Z4	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285649522210
11f5a0f2-fe57-58a2-89cc-139f47ef6ae5	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	2a2ebca2-63e4-56ef-abfa-8a57e35cf454	VI	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281334434010
d4bd8c17-0f14-513e-9f35-f316832a91d7	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	e1b28d35-ee2c-5cb0-82b1-c9ebb48fb5e8	0I	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281334434010
fc3fbf83-b5b2-5454-8376-97e0ac073702	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	44c89a8e-9451-5cac-9384-de9f458cf68e	KH	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285733655159
2451c698-750d-5019-9c49-93f20a72aab5	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	a4a80b21-0d10-5017-869d-a2e14ca09225	VO	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281977352333
6ad50776-b8c9-5f11-ac01-b9e4cbfbab1d	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	f5fe215e-1eaf-55f2-a141-5ad8c9686af1	OB	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285749034031
b307f96d-5d87-5b79-8b72-0813fb1afb5e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	0ee44675-a474-5fde-bfde-a505a7a75331	IS	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285730535945
92c01e8c-6194-5086-98c7-0a0ea533a6be	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	79e63a25-93d1-5aba-b771-d6288768641d	Q1	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6289682029246
cd6d0929-821c-5119-a344-356b40605366	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	71a28213-685f-5746-8349-8f0a35f3f599	WH	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285730993717
07ab5dae-e532-5f5d-a14b-188229407134	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	3f9526e6-42ac-572d-9ecc-129e8194d865	EP	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281553125678
980e2299-b9c8-57a9-ae4a-b8360619d82e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	768ef350-5fc3-575a-afc5-42a0b5dc064e	32	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285258045345
7fd9d6a3-fd47-5974-96a3-43543b45ed6e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b3b02c61-851c-5065-b577-09f6bfb9a4a1	HR	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285646788676
743aa830-b7d1-5d53-aa31-b1b2c1ca2172	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4fd907f1-2e04-5d6c-aae1-b2fdb3e50a97	V2	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	62816595659
64ee7f29-8f81-5e0a-9993-1362337c2524	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	6b24f3ea-ea14-5db4-9c59-40cda635ebce	I2	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285745710050
babc2931-883f-50ae-b6e1-9386e05e5bc0	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	a078c020-7c4e-57e2-bed9-ad06c93eca92	QK	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	628970618198
7a9fd53e-4567-5b40-8549-d35259dcd16f	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	39a238d2-ec7c-5d17-83c1-5bc399101720	S2	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6283834415004
bcb86e32-62c5-5976-9843-0f3dfc062867	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	1833da32-04cb-596c-8293-a2b73f4db663	UH	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281555636505
e30c82cb-f1fb-503d-aae5-8d5aa623eb20	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	88798e68-e574-5794-adde-0af2740f836d	3X	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285735235254
55988ed6-3656-5484-ade6-932146e78f8a	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	adc79868-75c9-510b-b27a-206427ec0e2e	53	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281931605151
0eacb61a-0bb5-54df-bdd0-168c510e2ce5	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	7b8a4f81-c010-582c-aaf0-92253ff1f138	DS	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285736067750
64e751d7-c422-5c2d-bf80-367f2d62b53e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	73d39be6-63cf-5408-b068-89cb98d806ed	UR	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	628155040905
aa08a4dd-cfdd-5504-8b7e-e9c4b7cd9cfe	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b807caab-26f0-5eca-a9f1-6f0e81d0f6c4	TI	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	628986331507
f5f54edf-9ac5-5344-980e-89612276d06a	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	979273aa-2433-5503-beab-db20fe1c521d	NQ	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6281558663635
102be1da-7933-55d9-bf0f-a9f8c74ca341	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	72b865b2-b818-5be7-951f-eb04d2432e21	PF	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285646628435
0eec1d73-5048-5056-8435-11605a6d97ad	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	f0d83204-0372-50b3-abf7-536e2abbd66a	X3	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6289678029068
64b4663a-d6c8-5236-9326-fb4c2034eede	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	ab3020d1-37c6-572f-8320-e159391ac2a8	BJ	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6281515786018
62bff016-ecb1-512d-a886-6478c6d83c61	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4e1d16ae-fcf6-5a49-894d-398b1b96f777	PA	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6281515786018
28c4caa0-d50a-5438-a477-780bc4b10ddd	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	8447b159-f515-53b4-bcd8-db7b59c87f93	J4	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6281216668592
3187c8e6-58da-53b3-9847-09e9c62ebfa7	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	1bf91399-347d-5580-a49e-c16d924125f8	1K	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285706634394
351d0dab-9055-5b8b-92b3-be167e009cb3	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	3cbd8998-c424-56aa-a773-74c17b176bbf	EK	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285785225670
4372bb14-fde6-5083-8970-73b373d2c034	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	d32bf146-05f8-5588-aaaf-ad0615fca0e2	MC	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285640110319
6c5ef5f4-e609-5f94-a5d3-671774155ec2	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	e7f8c503-9505-585a-a98f-9ad529e08154	WR	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	628970331599
a5c54e33-b687-509e-84e8-7ca71e4fb5e8	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	9e838bbd-6a5b-5c19-870f-f47926ed1168	B3	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285655263637
354e9924-3ef1-5b0d-8c75-186c9799a88a	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	26e4c87c-93e5-5e1d-856b-93f4836177a9	EE	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285755842282
6f41d5b4-50fa-577f-bb64-72fb41908c18	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	04dd178c-a00c-57e2-a0d1-241c545a2dd6	ZN	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285731538746
c5b8211d-a92d-52f2-a1bf-ff41f8952707	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4f99719b-f66a-569a-b188-7b2cd44315c9	DD	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285732277099
420ae2d1-9703-5a46-92d3-b93f403c2532	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	8a7e7e46-b5d8-5f86-adc2-dfbc42898a22	HI	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285732277099
912e5ef6-9325-5c43-8fe4-7e6d7ae75700	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	928c7824-6116-5f8d-97a7-69cde1d72f92	U3	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285604023840
46f3ed75-471c-5f07-9493-0a36a98f28b3	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	da909ac4-ad14-5d4d-9586-61ae468a9800	SX	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285604023840
acb3200d-640c-5e22-8134-3f1618c514a9	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	0dfd5d6e-5fc5-5717-b99f-5d60ca97a7cc	KB	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
3b02df01-37a1-5c9f-9249-21366b23e178	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	d4afbb5d-6a15-56a4-9875-c66c6f0b34f9	JI	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
aa3f89cc-4d71-5994-8654-c0055703421c	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	18fb4c09-ea9f-597c-a84d-ae3c7c24e7ba	HT	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
fb498af4-7c09-5cd8-b244-4a20366b4a5e	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b7353ef1-07b1-59a3-a463-e9ed78a8edeb	LC	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
592f58f8-5b5c-5e36-bec7-56632c6549e8	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	d234ab1a-2cf2-5857-b8b6-d8512500b304	QU	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
907d000e-10b2-5dc4-bd40-2f5c283859bb	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	870e77c5-7f5f-595e-a7f1-11f28ed51982	HV	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
c9c31780-f216-55ff-b292-1218cf836877	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	9b100053-b809-5cca-836a-d12ce14aca84	IW	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
ffe4db05-74e3-590c-bb3d-55e7ddd10fa4	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	25ff1ca0-9e6a-58f6-8dc2-fad72e0cc581	0F	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
8a6fbb43-681d-551f-a30d-21901b01d0f7	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	acbc14d0-5d4a-5540-bc59-457591795af5	TB	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
ca37b9ab-d258-548e-8c87-7911a7a40603	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	bf3c3b68-5586-517d-9280-bd50f49352d8	UP	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
f8448ec7-c894-5360-9093-75693a5699c2	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	2a2ebca2-63e4-56ef-abfa-8a57e35cf454	NK	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
0ffd6f40-ebb5-5f87-af0b-f8c02db8318d	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	e1b28d35-ee2c-5cb0-82b1-c9ebb48fb5e8	RL	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
1fdf85f7-056b-5832-9a9a-f2d3b0a45c0b	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	44c89a8e-9451-5cac-9384-de9f458cf68e	DV	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
f3f0858e-17d2-54ec-ba38-b10c95a11059	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	a4a80b21-0d10-5017-869d-a2e14ca09225	KT	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
eb4c11ed-de15-5abe-ae0a-a51e8c5ebd05	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	f5fe215e-1eaf-55f2-a141-5ad8c9686af1	2N	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
bcd223be-a541-5123-a57c-d45ab06e2987	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	73a54677-5bff-513f-a154-20d2517c94bf	YD	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
f26318f9-8bdc-5cb4-ad66-d245c21361f6	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	0ee44675-a474-5fde-bfde-a505a7a75331	3R	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
d8e8f03c-b513-503a-84e0-3d6682eb1a19	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	79e63a25-93d1-5aba-b771-d6288768641d	AH	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
5a027d31-769c-5793-b388-a9f52edce5e0	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	71a28213-685f-5746-8349-8f0a35f3f599	LR	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
4fe1fbcd-6eff-5c1a-beb5-191cd2ea57c1	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	3f9526e6-42ac-572d-9ecc-129e8194d865	4L	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
a229026a-dfd9-55dd-98ea-c6fb415ad284	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	768ef350-5fc3-575a-afc5-42a0b5dc064e	JL	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
6fdca12c-14ee-51e2-88f9-7d435475f3a0	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	9746f9bf-b155-5976-9e30-753f6dd05b31	TS	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
425624b6-2d65-524f-b3fa-869751e3e61c	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b3b02c61-851c-5065-b577-09f6bfb9a4a1	E3	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
2e2ec1a6-bb1d-52f1-9069-02deb4818326	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4fd907f1-2e04-5d6c-aae1-b2fdb3e50a97	IM	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
b9e64f4a-c9c0-566d-b735-fa001f7865f9	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	6b24f3ea-ea14-5db4-9c59-40cda635ebce	45	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
de02b435-2e3e-5ea6-bd8f-dd231674fbbe	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	a078c020-7c4e-57e2-bed9-ad06c93eca92	PM	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
fe4ce5cd-2bf1-51c8-93e6-4e2f5eb9fc68	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4fa63681-22ae-56f3-9688-d3f6532b42ce	44	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
4245cba8-047b-52af-8339-c3bb8d1d00e5	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	39a238d2-ec7c-5d17-83c1-5bc399101720	4E	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
703e7d77-86ac-52ce-af21-ea39ea7d2ee2	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	1833da32-04cb-596c-8293-a2b73f4db663	TF	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
e595bb23-9fc3-55ab-9e45-d89b4d8da1c5	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	88798e68-e574-5794-adde-0af2740f836d	ZK	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
d0f58d7f-087b-5e44-8bbd-25dda20c21c8	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	adc79868-75c9-510b-b27a-206427ec0e2e	3G	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
6a159b44-d74d-5a37-832f-d22d8d68f628	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	7b8a4f81-c010-582c-aaf0-92253ff1f138	1R	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
1f6179aa-f92b-59fa-9120-0ceeee387147	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	461e10c9-7041-593e-8b78-01843dbfd9bb	3D	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	\N
a44d9a1c-69f6-58fb-ac90-c2378b56dd67	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	73d39be6-63cf-5408-b068-89cb98d806ed	PW	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6289602870835
fccfdb3b-e06a-58a6-a69b-eaf7781b7366	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	f0d83204-0372-50b3-abf7-536e2abbd66a	AD	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285730963675
7d1cad70-8fa4-5571-8c4b-c895b1f02308	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	3cbd8998-c424-56aa-a773-74c17b176bbf	LE	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285258721649
d2577e03-66ba-5606-9d2e-7d5f0b53db66	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	04dd178c-a00c-57e2-a0d1-241c545a2dd6	TC	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6283847653549
66201c98-8808-55d9-81ee-e1dc2e795a37	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	da909ac4-ad14-5d4d-9586-61ae468a9800	KJ	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6281515451630
9c669fb1-797e-5741-a6f3-55a02897090b	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b7353ef1-07b1-59a3-a463-e9ed78a8edeb	EZ	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6289676333986
e1adafaf-fffd-5b9c-9a77-64fa3c4b9289	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	bf3c3b68-5586-517d-9280-bd50f49352d8	GX	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	628979671512
4ca10400-b585-5c21-8f28-c8b95e17969f	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	73a54677-5bff-513f-a154-20d2517c94bf	55	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285641691695
f77f4ac3-4f55-5b4f-992c-0090fd61d5ff	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	9746f9bf-b155-5976-9e30-753f6dd05b31	2X	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285732676979
0f5be733-49ef-5d9e-b5f5-dfe9883caa7d	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	4fa63681-22ae-56f3-9688-d3f6532b42ce	4G	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6283834415004
1e3a0735-b5b6-500e-b5f8-f3d00fcc7070	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	461e10c9-7041-593e-8b78-01843dbfd9bb	SL	01	1	\N	2014-02-13 15:46:38.470193	\N	\N	6285649714704
04a1ccf9-0b2d-5101-8542-7ded87feb741	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	b621027a-d549-58a3-b29c-ea8f11728d16	3Q	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6281233045596
992c27a4-6dc1-5710-9433-cd58281c285f	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	cff92b6d-5120-5bd6-ac6f-8819f67feabb	HK	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	6285649406194
d02eed5f-da30-5787-90d9-8b4d19ed94b3	4105e8ef-29a1-5893-8103-cbd2c1e5fbaa	cfdfd13c-e357-5359-acde-853e538e2455	V4	02	1	\N	2014-02-13 15:46:56.212298	\N	\N	628970407417
\.


--
-- Data for Name: tps_surveyor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY tps_surveyor (id, nama, msisdn, tps_id, createdby, createddate, updatedby, updateddate) FROM stdin;
23392589-fde8-5f1d-81b4-25f97468a6ca	LURI DARMAWAN	6287876469000	fe1487a8-9ef1-5dfa-b268-46db37e2d562	\N	2014-02-11 21:16:33.114754	\N	\N
86d13a98-277c-5029-a5e0-cb279bed870a	Bagus Mertha Pradnyana	6281931605151	\N	\N	2014-02-05 14:59:47.595	\N	\N
3504ff10-18cc-5dcf-b6d7-51b9a3ed70c1	Dhesky Aris	6285731978905	\N	\N	2014-02-05 14:59:47.595	\N	\N
cb3df3ae-02b0-58c3-972f-8f79d657bdf5	Muzammil	6285785225670	\N	\N	2014-02-05 14:59:47.595	\N	\N
590f9cae-c4f1-5d90-87dd-cc9fa3f3a48b	Ghozali Muslim	6285641691695	\N	\N	2014-02-05 14:59:47.595	\N	\N
bd9eeddb-c4f0-5917-9a92-dc419332edca	Mahardini	6281216668592	\N	\N	2014-02-05 14:59:47.595	\N	\N
82a8f8cf-2ada-5593-a145-2405db5d16f4	Abdul Azis	6281555636505	\N	\N	2014-02-05 14:59:47.595	\N	\N
8410649d-8cdd-55f3-bba8-613f231030d0	M. Taufiqur Rusda	6285735235254	\N	\N	2014-02-05 14:59:47.595	\N	\N
3d8bcfde-d147-5d51-924b-14447a6c66fd	IQBAL ADHIM	6285604797757	\N	\N	2014-02-05 14:59:47.595	\N	\N
39b41a0f-80fc-58e3-929a-a00ea54a32a6	Mokhammad Aris Nur Yahya	628563007227	\N	\N	2014-02-05 14:59:47.595	\N	\N
61e70aa8-06d1-5821-85e8-d11181f8093d	Achmad andi setiyono	6285732676979	\N	\N	2014-02-05 14:59:47.595	\N	\N
a75266b6-b348-5aa0-8785-b1f430862234	Marudi Tri Subakti	6285646628435	\N	\N	2014-02-05 14:59:47.595	\N	\N
5ba8a345-12d1-57c4-b35b-e0c929c50450	Maisya Elvaro	6285730993717	\N	\N	2014-02-05 14:59:47.595	\N	\N
1a008278-9295-5794-b276-0045a4ce406f	Firdaus Dwika Ainun Ilmi	6285258721649	\N	\N	2014-02-05 14:59:47.595	\N	\N
31c4f9da-59ae-55c5-9dfa-8c7ecafb9253	muhammad zoqi sarwani	6281515600695	\N	\N	2014-02-05 14:59:47.595	\N	\N
3a42fd4c-b45f-5362-a40c-aeeb66dfb6ea	Handi susanto	6285655516191	\N	\N	2014-02-05 14:59:47.595	\N	\N
b99b9557-0481-556b-a5c2-b5807337dd88	Mokhamad Syaiful Faris	6281515786018	\N	\N	2014-02-05 14:59:47.595	\N	\N
576b6b72-648b-5652-9003-24099813d445	Satria Agung Pamuji	6285749034031	\N	\N	2014-02-05 14:59:47.595	\N	\N
c54ac723-9023-5a24-89f2-4d9ec9cc6a41	Muchamad Aly mBA	6285706634394	\N	\N	2014-02-05 14:59:47.595	\N	\N
166086f3-0180-5e93-8386-aedfdb37d9fc	Afes Oktavianus	6282233144676	\N	\N	2014-02-05 14:59:47.595	\N	\N
03c4fa47-6d01-5bf9-83b4-ce09693646a8	Belsazar Elgiborado Giovani Djoedir	6289634876886	\N	\N	2014-02-05 14:59:47.595	\N	\N
714f1147-e3cc-5c87-8e3c-4bd4774c728f	Poby Zaarifwandono	628970618198	\N	\N	2014-02-05 14:59:47.595	\N	\N
43797aaf-c40e-58d9-87ba-f63dc904763e	Muhammad Yurid Rofrofi Indillah	628979671512	\N	\N	2014-02-05 14:59:47.595	\N	\N
2ea14652-4c96-5156-aa76-857223bc70d9	Khairul Mun\\047im Al Bisri	6283847653549	\N	\N	2014-02-05 14:59:47.595	\N	\N
3cbbda5c-d8e4-5ac8-911f-50d5f2cda1b9	Ahmad Barrul Faizin	6289681986456	\N	\N	2014-02-05 14:59:47.595	\N	\N
27ca348c-2af6-5564-94ad-8c945f968362	Dimas Prayogi Indra K.	628974313107	\N	\N	2014-02-05 14:59:47.595	\N	\N
5b8f01e3-41e2-574c-90fb-510ca1716825	Rizki Rivaldi	6289682029246	\N	\N	2014-02-05 14:59:47.595	\N	\N
f318f842-d757-5ef1-b359-ec10848118bf	AHMAD SIROJUL MIFTAKH	6285731538746	\N	\N	2014-02-05 14:59:47.595	\N	\N
e9e6f91c-1ea7-526b-b2d8-99a61d64dce0	MUHAMMD UBAIDILLAH	6285755842282	\N	\N	2014-02-05 14:59:47.595	\N	\N
88bb805a-1c9c-5231-b3f5-d87d586f6ec9	AHMAD RIZQI HABIBILLAH	6285736067750	\N	\N	2014-02-05 14:59:47.595	\N	\N
01588caf-f73b-5aa2-b825-d4fb18807e61	ARMAN	628155502030	\N	\N	2014-02-05 14:59:47.595	\N	\N
b84fb53c-642c-5e69-81b4-3720b85599a1	M. Winasikin	6289678259045	\N	\N	2014-02-05 14:59:47.595	\N	\N
e924e33e-acc9-5811-81d2-0dc599344dda	Umi Fadhilah	628970331599	\N	\N	2014-02-05 14:59:47.595	\N	\N
33ac51cc-d861-5954-852c-411799bdd0b8	Donny Azhar	6281515451630	\N	\N	2014-02-05 14:59:47.595	\N	\N
3f46b0dd-c3b1-564c-81ca-db79743595f5	Hendrik Chrisnaedy	6281330142492	\N	\N	2014-02-05 14:59:47.595	\N	\N
0ce541d1-6182-565c-9f4c-95fe85ec4cdd	Endra Wijaya	6285647425152	\N	\N	2014-02-05 14:59:47.595	\N	\N
e852f094-bdd6-5bc3-a912-3149e59b3056	Shandy Irawan	6285640110319	\N	\N	2014-02-05 14:59:47.595	\N	\N
3c1eb231-0883-550e-b470-d8be7fcb80cf	Dwi Apri Wahyu Prayogo	6289676333986	\N	\N	2014-02-05 14:59:47.595	\N	\N
7072e657-f143-5239-a7d1-0e3257b931b5	M. Ikmal Farih	6285745710050	\N	\N	2014-02-05 14:59:47.595	\N	\N
fe8b1356-24ff-54e9-a2e7-e472939015c1	Makhrus Sholeh	6285604023840	\N	\N	2014-02-05 14:59:47.595	\N	\N
89f7e4b5-5559-5c3e-9582-19eaf81eb879	FRENKY DIRGAYASA	6285649714704	\N	\N	2014-02-05 14:59:47.595	\N	\N
413d29af-1f2a-5151-9853-0d9ec54f3eb8	ARIEF SOFIYAN	6285649522210	\N	\N	2014-02-05 14:59:47.595	\N	\N
1ca24479-925e-5696-9f07-16c0f001ef01	Muhammad Bambang A. C	6285853774437	\N	\N	2014-02-05 14:59:47.595	\N	\N
3f050918-01d5-570b-ba35-62ecab6c37dc	Rudi Hartono	6285746906160	\N	\N	2014-02-05 14:59:47.595	\N	\N
a964045f-f885-5f89-8310-228d49bbc1c4	Chumairo	6281936855100	\N	\N	2014-02-05 14:59:47.595	\N	\N
002782df-7858-50e5-9612-54cb4ca08de3	Fakhrun Nisa\\047ul Azizah	6289602870835	\N	\N	2014-02-05 14:59:47.595	\N	\N
5faf61dc-456c-5582-af7c-e00461b5ecf5	Rachmad Hidayat Agustyono	6285258045345	\N	\N	2014-02-05 14:59:47.595	\N	\N
44427045-b855-56ae-bca1-20d5f2ef991e	Dwi Bagus Fitrianto	6281334434010	\N	\N	2014-02-05 14:59:47.595	\N	\N
fb761508-58e7-58c4-bc95-d4b63a057a43	Ade Yudha Pratama	6285732277099	\N	\N	2014-02-05 14:59:47.595	\N	\N
62255842-ac8a-55ad-9ff0-74c29fa53413	Citra Ayu Jayanti	6285646788676	\N	\N	2014-02-05 14:59:47.595	\N	\N
0519b9c3-b1bf-5d8b-b025-aaa1d2ffec67	FAHAT FAHRIZAL	6285730963675	\N	\N	2014-02-05 14:59:47.595	\N	\N
071be393-107a-56fe-a932-536513f77296	H Na V	6285749024217	\N	\N	2014-02-05 14:59:47.595	\N	\N
5b0b638a-2db0-51e9-bb6e-3318843bf435	Fiki Hasanah	6285730535945	\N	\N	2014-02-05 14:59:47.595	\N	\N
1b87d1fc-43df-5623-acea-e3efb98785d6	Lathifah	6285704294202	\N	\N	2014-02-05 14:59:47.595	\N	\N
5699fbbe-7c9b-515c-8df4-8a8bdcfe638b	Moh Fatoni	6281977352333	\N	\N	2014-02-05 14:59:47.595	\N	\N
91924471-8213-5cb3-8c6e-b02f91d6c6cf	Putri Laraswati Khoirun Nisa	628986331507	\N	\N	2014-02-05 14:59:47.595	\N	\N
98cfefa5-4760-593c-8496-c91abe8fc278	Lukman Widi C.	6281558663635	\N	\N	2014-02-05 14:59:47.595	\N	\N
35b36d94-7bf3-51a0-a920-b2878e1e3cd9	ANANG AFANDI	628155007019	\N	\N	2014-02-05 14:59:47.595	\N	\N
14716e48-1862-522b-a564-11051beaaa08	Santi Dwi Ratnasari	6285785380398	\N	\N	2014-02-05 14:59:47.595	\N	\N
72b51198-518e-5636-9c3f-387d78e18272	Faisal Alfareza	6283834415004	\N	\N	2014-02-05 14:59:47.595	\N	\N
aa3207ac-6ca8-5fa2-8492-d628c6669a7b	Dwi Riyan Tono	6289678029068	\N	\N	2014-02-05 14:59:47.595	\N	\N
5214bdd3-103b-5a22-87e7-785f60955a31	Achmad Zamrozi 	6285733655159	\N	\N	2014-02-05 14:59:47.595	\N	\N
01a8252d-6ea8-52df-a1ad-735cf17d6f50	Rizki Nur Iman, S.Kom.	6285791975758	\N	\N	2014-02-05 14:59:47.595	\N	\N
66966a9d-5e3f-50bf-a613-846b467fe0cb	Tigor Mangatur Manurung	62816595659	\N	\N	2014-02-05 14:59:47.595	\N	\N
b6ec62fd-95de-5725-a60c-f6bb6c889cdc	Bimo Syahputro	6281233045596	\N	\N	2014-02-05 14:59:47.595	\N	\N
8a7a38f2-561e-5191-b2be-a290940b142d	setijo Agus	628155040905	\N	\N	2014-02-05 14:59:47.595	\N	\N
5e53e2cc-7f36-5d3f-b5b5-2e71c4edb120	Gede Adnya Karsana	6281553125678	\N	\N	2014-02-05 14:59:47.595	\N	\N
36d44ef8-f89b-5de9-a85d-aad609c4f239	Candra Agung Pratama	6285755627585	\N	\N	2014-02-05 14:59:47.595	\N	\N
e98c15f4-c57e-5c24-badc-98c97ee0dee8	aris taufiq Febrianto 	6285655263637	\N	\N	2014-02-05 14:59:47.595	\N	\N
dbb750b5-0872-526e-8da9-ed92daca74af	Rahasdita Reo Hansdoko	6285649406194	\N	\N	2014-02-05 14:59:47.595	\N	\N
f50aa319-25e1-5121-9ed0-d1f66574328a	Rahmanda Fitrianto	628970407417	\N	\N	2014-02-05 14:59:47.595	\N	\N
\.


--
-- Data for Name: vote_colector; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY vote_colector (id, calon_id, apinbox_id, tps_id, post_date, vote, createdby, createddate, updatedby, updateddate) FROM stdin;
3a2725f7-7335-5bd4-ac13-da79d6006f00	e88d703d-d9cd-5744-9c90-330bdf09c573	7d455877-fcc8-5282-a084-45855723e2c1	243e6df2-8a7c-5b05-8d26-29d5e36bd673	2014-02-13 22:07:16.277	10	\N	2014-02-13 22:02:15.477	\N	\N
214f875a-fda3-557c-be96-7c653726b28b	f850a044-9d39-55ae-a8f5-803107c2fce4	7d455877-fcc8-5282-a084-45855723e2c1	243e6df2-8a7c-5b05-8d26-29d5e36bd673	2014-02-13 22:07:16.277	20	\N	2014-02-13 22:02:15.477	\N	\N
5a534734-108d-5dfb-b28e-b169ba3ec99d	9ea1f78e-2cc6-54e6-b45c-02000f00f6e7	7d455877-fcc8-5282-a084-45855723e2c1	243e6df2-8a7c-5b05-8d26-29d5e36bd673	2014-02-13 22:07:16.277	30	\N	2014-02-13 22:02:15.477	\N	\N
250dd3f6-61b3-5b02-88f1-03f4af702a89	e88d703d-d9cd-5744-9c90-330bdf09c573	8a4d6589-7ff6-53d5-bdcd-22b16c94a6f7	48d23cea-4061-5878-8c95-e539daffebfd	2014-02-13 22:09:18.68	5	\N	2014-02-13 22:09:18.68	\N	\N
da5d1e2c-1f2a-5b69-9ab6-7f5086b85de5	f850a044-9d39-55ae-a8f5-803107c2fce4	8a4d6589-7ff6-53d5-bdcd-22b16c94a6f7	48d23cea-4061-5878-8c95-e539daffebfd	2014-02-13 22:09:18.68	6	\N	2014-02-13 22:09:18.68	\N	\N
e4607a4d-02e8-55a2-b39b-aa2d2214ae06	9ea1f78e-2cc6-54e6-b45c-02000f00f6e7	8a4d6589-7ff6-53d5-bdcd-22b16c94a6f7	48d23cea-4061-5878-8c95-e539daffebfd	2014-02-13 22:09:18.68	7	\N	2014-02-13 22:09:18.68	\N	\N
\.


--
-- Name: acls_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY acls
    ADD CONSTRAINT acls_id_pk PRIMARY KEY (id);


--
-- Name: apinbox_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY apinbox
    ADD CONSTRAINT apinbox_id_pk PRIMARY KEY (id);


--
-- Name: apoutbox_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY apoutbox
    ADD CONSTRAINT apoutbox_id_pk PRIMARY KEY (id);


--
-- Name: calon_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY calon
    ADD CONSTRAINT calon_pk PRIMARY KEY (id);


--
-- Name: desa_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY desa
    ADD CONSTRAINT desa_pk PRIMARY KEY (id);


--
-- Name: groups_id; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_id PRIMARY KEY (id);


--
-- Name: kabupaten_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY kabupaten
    ADD CONSTRAINT kabupaten_pk PRIMARY KEY (id);


--
-- Name: kecamatan_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY kecamatan
    ADD CONSTRAINT kecamatan_pk PRIMARY KEY (id);


--
-- Name: level_acls_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY level_acls
    ADD CONSTRAINT level_acls_id_pk PRIMARY KEY (id);


--
-- Name: level_menu_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY level_menus
    ADD CONSTRAINT level_menu_id_pk PRIMARY KEY (id);


--
-- Name: levels_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY levels
    ADD CONSTRAINT levels_id_pk PRIMARY KEY (id);


--
-- Name: logs_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY logs
    ADD CONSTRAINT logs_id_pk PRIMARY KEY (id);


--
-- Name: menus_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY menus
    ADD CONSTRAINT menus_id_pk PRIMARY KEY (id);


--
-- Name: mpilkada_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mpilkada
    ADD CONSTRAINT mpilkada_pk PRIMARY KEY (id);


--
-- Name: pilkada_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pilkada_event
    ADD CONSTRAINT pilkada_pk PRIMARY KEY (id);


--
-- Name: propinsi_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY propinsi
    ADD CONSTRAINT propinsi_pk PRIMARY KEY (id);


--
-- Name: sysparam_name_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sysparam
    ADD CONSTRAINT sysparam_name_pk PRIMARY KEY (name);


--
-- Name: syuserlogin_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY syuserlogin
    ADD CONSTRAINT syuserlogin_id_pk PRIMARY KEY (id);


--
-- Name: tps_kode_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tps
    ADD CONSTRAINT tps_kode_unique UNIQUE (kode);


--
-- Name: tps_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tps
    ADD CONSTRAINT tps_pk PRIMARY KEY (id);


--
-- Name: tps_survey_unique; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tps_surveyor
    ADD CONSTRAINT tps_survey_unique UNIQUE (msisdn);


--
-- Name: tps_surveyor_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tps_surveyor
    ADD CONSTRAINT tps_surveyor_id_pk PRIMARY KEY (id);


--
-- Name: vote_id_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY vote_colector
    ADD CONSTRAINT vote_id_pk PRIMARY KEY (id);


--
-- Name: calon_nama; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX calon_nama ON calon USING btree (nama) WITH (fillfactor=90);


--
-- Name: desa_nama; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX desa_nama ON desa USING btree (nama) WITH (fillfactor=90);


--
-- Name: kab_nama; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX kab_nama ON kabupaten USING btree (nama) WITH (fillfactor=90);


--
-- Name: kec_nama; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX kec_nama ON kecamatan USING btree (nama) WITH (fillfactor=90);


--
-- Name: prop_nama; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX prop_nama ON propinsi USING btree (nama) WITH (fillfactor=90);


--
-- Name: apinbox; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER apinbox AFTER INSERT OR UPDATE ON apinbox FOR EACH ROW EXECUTE PROCEDURE apinbox();


--
-- Name: calon; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER calon AFTER INSERT OR UPDATE ON calon FOR EACH ROW EXECUTE PROCEDURE calon();


--
-- Name: desa; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER desa AFTER INSERT OR UPDATE ON desa FOR EACH ROW EXECUTE PROCEDURE desa();


--
-- Name: kabupaten; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER kabupaten AFTER INSERT OR UPDATE ON kabupaten FOR EACH ROW EXECUTE PROCEDURE kabupaten();


--
-- Name: kecamatan; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER kecamatan AFTER INSERT OR UPDATE ON kecamatan FOR EACH ROW EXECUTE PROCEDURE kecamatan();


--
-- Name: pilkada_event; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER pilkada_event AFTER INSERT OR UPDATE ON pilkada_event FOR EACH ROW EXECUTE PROCEDURE pilkada_event();


--
-- Name: propinsi; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER propinsi AFTER INSERT OR UPDATE ON propinsi FOR EACH ROW EXECUTE PROCEDURE propinsi();


--
-- Name: tps; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tps AFTER INSERT OR UPDATE ON tps FOR EACH ROW EXECUTE PROCEDURE tps();


--
-- Name: tps_surveyor; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tps_surveyor AFTER INSERT OR UPDATE ON tps_surveyor FOR EACH ROW EXECUTE PROCEDURE tps_surveyor();


--
-- Name: apinbox_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vote_colector
    ADD CONSTRAINT apinbox_fk FOREIGN KEY (apinbox_id) REFERENCES apinbox(id) MATCH FULL ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: apoutbox_sysuserlogi_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY apoutbox
    ADD CONSTRAINT apoutbox_sysuserlogi_id_fk FOREIGN KEY (syuserlogin_id) REFERENCES syuserlogin(id) MATCH FULL;


--
-- Name: calon_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY vote_colector
    ADD CONSTRAINT calon_fk FOREIGN KEY (calon_id) REFERENCES calon(id) MATCH FULL ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: calon_pilkada_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY calon
    ADD CONSTRAINT calon_pilkada_id_fk FOREIGN KEY (pilkada_id) REFERENCES pilkada_event(id) MATCH FULL;


--
-- Name: desa_kec_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY desa
    ADD CONSTRAINT desa_kec_id_fk FOREIGN KEY (kecamatan_id) REFERENCES kecamatan(id) MATCH FULL;


--
-- Name: kab_prop_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kabupaten
    ADD CONSTRAINT kab_prop_id_fk FOREIGN KEY (propinsi_id) REFERENCES propinsi(id) MATCH FULL;


--
-- Name: kec_kab_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY kecamatan
    ADD CONSTRAINT kec_kab_id FOREIGN KEY (kabupaten_id) REFERENCES kabupaten(id) MATCH FULL;


--
-- Name: level_level_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY level_acls
    ADD CONSTRAINT level_level_id_fk FOREIGN KEY (level_id) REFERENCES levels(id) MATCH FULL;


--
-- Name: level_menus_menu_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY level_menus
    ADD CONSTRAINT level_menus_menu_id_fk FOREIGN KEY (menu_id) REFERENCES menus(id) MATCH FULL;


--
-- Name: level_velel_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY level_menus
    ADD CONSTRAINT level_velel_id_fk FOREIGN KEY (level_id) REFERENCES levels(id) MATCH FULL;


--
-- Name: levels_acls_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY level_acls
    ADD CONSTRAINT levels_acls_id_fk FOREIGN KEY (acl_id) REFERENCES acls(id) MATCH FULL;


--
-- Name: logs_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY logs
    ADD CONSTRAINT logs_user_id_fk FOREIGN KEY (user_id) REFERENCES syuserlogin(id) MATCH FULL;


--
-- Name: menus_group_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY menus
    ADD CONSTRAINT menus_group_id_fk FOREIGN KEY (group_id) REFERENCES groups(id) MATCH FULL;


--
-- Name: mpilkada_parent_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mpilkada
    ADD CONSTRAINT mpilkada_parent_id_fk FOREIGN KEY (parent_id) REFERENCES propinsi(id) MATCH FULL;


--
-- Name: sysuserlogin_level_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY syuserlogin
    ADD CONSTRAINT sysuserlogin_level_id_fk FOREIGN KEY (level_id) REFERENCES levels(id) MATCH FULL;


--
-- Name: tps_desa_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tps
    ADD CONSTRAINT tps_desa_id_fk FOREIGN KEY (desa_id) REFERENCES desa(id) MATCH FULL;


--
-- Name: tps_msisdn_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tps
    ADD CONSTRAINT tps_msisdn_fk FOREIGN KEY (msisdn) REFERENCES tps_surveyor(msisdn);


--
-- Name: tps_pilkada_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tps
    ADD CONSTRAINT tps_pilkada_id_fk FOREIGN KEY (pilkada_id) REFERENCES pilkada_event(id) MATCH FULL;


--
-- Name: public; Type: ACL; Schema: -; Owner: uLiL
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM "uLiL";
GRANT ALL ON SCHEMA public TO "uLiL";
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: acls; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE acls FROM PUBLIC;
REVOKE ALL ON TABLE acls FROM postgres;
GRANT ALL ON TABLE acls TO postgres;


--
-- Name: apinbox; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE apinbox FROM PUBLIC;
REVOKE ALL ON TABLE apinbox FROM postgres;
GRANT ALL ON TABLE apinbox TO postgres;


--
-- Name: apoutbox; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE apoutbox FROM PUBLIC;
REVOKE ALL ON TABLE apoutbox FROM postgres;
GRANT ALL ON TABLE apoutbox TO postgres;


--
-- Name: calon; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE calon FROM PUBLIC;
REVOKE ALL ON TABLE calon FROM postgres;
GRANT ALL ON TABLE calon TO postgres;


--
-- Name: desa; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE desa FROM PUBLIC;
REVOKE ALL ON TABLE desa FROM postgres;
GRANT ALL ON TABLE desa TO postgres;


--
-- Name: groups; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE groups FROM PUBLIC;
REVOKE ALL ON TABLE groups FROM postgres;
GRANT ALL ON TABLE groups TO postgres;


--
-- Name: kabupaten; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE kabupaten FROM PUBLIC;
REVOKE ALL ON TABLE kabupaten FROM postgres;
GRANT ALL ON TABLE kabupaten TO postgres;


--
-- Name: kecamatan; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE kecamatan FROM PUBLIC;
REVOKE ALL ON TABLE kecamatan FROM postgres;
GRANT ALL ON TABLE kecamatan TO postgres;


--
-- Name: level_acls; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE level_acls FROM PUBLIC;
REVOKE ALL ON TABLE level_acls FROM postgres;
GRANT ALL ON TABLE level_acls TO postgres;


--
-- Name: level_menus; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE level_menus FROM PUBLIC;
REVOKE ALL ON TABLE level_menus FROM postgres;
GRANT ALL ON TABLE level_menus TO postgres;


--
-- Name: levels; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE levels FROM PUBLIC;
REVOKE ALL ON TABLE levels FROM postgres;
GRANT ALL ON TABLE levels TO postgres;


--
-- Name: logs; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE logs FROM PUBLIC;
REVOKE ALL ON TABLE logs FROM postgres;
GRANT ALL ON TABLE logs TO postgres;


--
-- Name: menus; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE menus FROM PUBLIC;
REVOKE ALL ON TABLE menus FROM postgres;
GRANT ALL ON TABLE menus TO postgres;


--
-- Name: mpilkada; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE mpilkada FROM PUBLIC;
REVOKE ALL ON TABLE mpilkada FROM postgres;
GRANT ALL ON TABLE mpilkada TO postgres;


--
-- Name: pilkada_event; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE pilkada_event FROM PUBLIC;
REVOKE ALL ON TABLE pilkada_event FROM postgres;
GRANT ALL ON TABLE pilkada_event TO postgres;


--
-- Name: propinsi; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE propinsi FROM PUBLIC;
REVOKE ALL ON TABLE propinsi FROM postgres;
GRANT ALL ON TABLE propinsi TO postgres;


--
-- Name: sysparam; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE sysparam FROM PUBLIC;
REVOKE ALL ON TABLE sysparam FROM postgres;
GRANT ALL ON TABLE sysparam TO postgres;


--
-- Name: syuserlogin; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE syuserlogin FROM PUBLIC;
REVOKE ALL ON TABLE syuserlogin FROM postgres;
GRANT ALL ON TABLE syuserlogin TO postgres;


--
-- Name: tps; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tps FROM PUBLIC;
REVOKE ALL ON TABLE tps FROM postgres;
GRANT ALL ON TABLE tps TO postgres;


--
-- Name: tps_surveyor; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tps_surveyor FROM PUBLIC;
REVOKE ALL ON TABLE tps_surveyor FROM postgres;
GRANT ALL ON TABLE tps_surveyor TO postgres;


--
-- Name: vote_colector; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vote_colector FROM PUBLIC;
REVOKE ALL ON TABLE vote_colector FROM postgres;
GRANT ALL ON TABLE vote_colector TO postgres;


--
-- Name: vpilkada_event; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vpilkada_event FROM PUBLIC;
REVOKE ALL ON TABLE vpilkada_event FROM postgres;
GRANT ALL ON TABLE vpilkada_event TO postgres;


--
-- Name: vtps; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE vtps FROM PUBLIC;
REVOKE ALL ON TABLE vtps FROM postgres;
GRANT ALL ON TABLE vtps TO postgres;


--
-- PostgreSQL database dump complete
--

