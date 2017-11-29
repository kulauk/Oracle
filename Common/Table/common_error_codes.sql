--ALTER TABLE common.common_error_codes
--   DROP PRIMARY KEY CASCADE;
--
--DROP TABLE common.common_error_codes CASCADE CONSTRAINTS;

CREATE TABLE common.common_error_codes
(
   id_common_error_codes         NUMBER,
   package_name                  VARCHAR2 (100 CHAR),
   procfunc                      VARCHAR2 (100 CHAR),
   when_error                    VARCHAR2 (100 CHAR),
   error_message                 VARCHAR2 (4000 CHAR),
   idsblocation                  CHAR (2 BYTE) DEFAULT 'UK',
   error_level                   NUMBER (2) DEFAULT 0 NOT NULL,
   send_alert_email              NUMBER (1) DEFAULT NULL,
   email_alert_threshold_hours   NUMBER (15, 6) DEFAULT 24 NOT NULL
)
TABLESPACE &&enter_tblsp_s
NOPARALLEL
MONITORING;


CREATE UNIQUE INDEX common.common_error_codes_pk
   ON common.common_error_codes (id_common_error_codes)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_s
   NOPARALLEL;

CREATE UNIQUE INDEX common.common_error_codes_uidx
   ON common.common_error_codes (package_name, procfunc, when_error)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_s
   NOPARALLEL;



CREATE OR REPLACE TRIGGER common.common_error_codes_seq_bie
   BEFORE INSERT
   ON common.common_error_codes
   REFERENCING NEW AS new OLD AS old
   FOR EACH ROW
BEGIN
   --   tmpvar := 0;
   --
   --   SELECT id_common_error_codes_seq.NEXTVAL
   --     INTO tmpvar
   --     FROM DUAL;

   :new.id_common_error_codes := id_common_error_codes_seq.NEXTVAL;
END common_error_codes_seq_bie;
/


CREATE OR REPLACE PUBLIC SYNONYM common_error_codes FOR common.common_error_codes;


ALTER TABLE common.common_error_codes ADD (
  CONSTRAINT common_error_codes_pk
  PRIMARY KEY
  (id_common_error_codes)
  USING INDEX common.common_error_codes_pk
  ENABLE VALIDATE);