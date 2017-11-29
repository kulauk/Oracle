--ALTER TABLE common.TRACE_CONFIG
-- DROP PRIMARY KEY CASCADE;
--
--DROP TABLE common.TRACE_CONFIG CASCADE CONSTRAINTS;

PROMPT CREATING: common.trace_config

CREATE TABLE common.trace_config
(
   id_trace_config    NUMBER NOT NULL,
   package_name       VARCHAR2 (32 BYTE),
   procedure_name     VARCHAR2 (32 BYTE) NOT NULL,
   trace_level        NUMBER (3) DEFAULT 0 NOT NULL,
   last_updated_by    VARCHAR2 (100 BYTE) NOT NULL,
   last_updated_dts   DATE NOT NULL,
   owner              VARCHAR2 (50 BYTE) DEFAULT 'common' NOT NULL
)
TABLESPACE &&enter_tblsp_s
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;


CREATE UNIQUE INDEX common.i_trace_config1
   ON common.trace_config (owner, package_name, procedure_name)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_s
   NOPARALLEL;

CREATE UNIQUE INDEX common.pk_trace_config
   ON common.trace_config (id_trace_config)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_s
   NOPARALLEL;

CREATE OR REPLACE TRIGGER common.trace_config_bie
   BEFORE INSERT
   ON common.trace_config
   FOR EACH ROW
BEGIN
   SELECT seq_id_trace_config.NEXTVAL INTO :new.id_trace_config FROM DUAL;
END;
/



ALTER TABLE common.trace_config ADD (
  CONSTRAINT pk_trace_config
  PRIMARY KEY
  (id_trace_config)
  USING INDEX common.pk_trace_config
  ENABLE VALIDATE);


CREATE OR REPLACE PUBLIC SYNONYM trace_config FOR common.trace_config;