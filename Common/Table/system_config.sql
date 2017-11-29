--DROP TABLE common.system_config CASCADE CONSTRAINTS;

CREATE TABLE common.system_config
(
   section                 VARCHAR2 (64 BYTE) NOT NULL,
   name                    VARCHAR2 (64 BYTE) NOT NULL,
   data                    VARCHAR2 (1000 BYTE),
   description             VARCHAR2 (2000 BYTE),
   idoperatorcreated       VARCHAR2 (30 BYTE) DEFAULT USER NOT NULL,
   created_date             DATE DEFAULT SYSDATE NOT NULL,
   idoperatormodified      VARCHAR2 (30 BYTE) DEFAULT USER NOT NULL,
   modified_date           DATE DEFAULT SYSDATE NOT NULL
)
TABLESPACE &&enter_tblsp_s
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;

CREATE UNIQUE INDEX common.pk_system_config
   ON common.system_config (section, name)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_s
   NOPARALLEL;

ALTER TABLE common.system_config ADD (
  CONSTRAINT pk_system_config
  PRIMARY KEY
  (name, section)
  USING INDEX common.pk_system_config
  ENABLE VALIDATE);

CREATE OR REPLACE PUBLIC SYNONYM system_config FOR common.system_config;