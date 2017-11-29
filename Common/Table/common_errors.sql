--ALTER TABLE common.common_errors
--   DROP PRIMARY KEY CASCADE;
--
--DROP TABLE common.common_errors CASCADE CONSTRAINTS;

CREATE TABLE common.common_errors
(
   id_common_errors           NUMBER NOT NULL,
   id_common_error_codes      NUMBER NOT NULL,
   oracle_sqlerrm             VARCHAR2 (4000 BYTE),
   field                      VARCHAR2 (1000 CHAR),
   field_value                VARCHAR2 (1000 CHAR),
   field_value_transformed    VARCHAR2 (1000 CHAR),
   timestamp                  DATE DEFAULT SYSDATE NOT NULL,
   error_message              VARCHAR2 (1000 CHAR),
   id_common_errors_autorun   NUMBER,
   autorun_execution          NUMBER (1)
)
TABLESPACE &&enter_tblsp_m
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;


CREATE INDEX common.idx_ora_err_idautorun
   ON common.common_errors (id_common_errors_autorun)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE INDEX common.i_date_common_errors
   ON common.common_errors (TRUNC ("TIMESTAMP"))
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;


CREATE INDEX common.i_time_common_errors
   ON common.common_errors (timestamp)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;


CREATE UNIQUE INDEX common.common_errors_pk
   ON common.common_errors (id_common_errors)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;


CREATE OR REPLACE TRIGGER common.common_errors_seq_bie
   BEFORE INSERT
   ON common.common_errors
   REFERENCING NEW AS new OLD AS old
   FOR EACH ROW
BEGIN
   --   tmpvar := 0;
   --
   --   SELECT id_common_errors_seq.NEXTVAL
   --     INTO tmpvar
   --     FROM DUAL;

   :new.id_common_errors := id_common_errors_seq.NEXTVAL;
END common_errors_seq_bie;
/


CREATE OR REPLACE PUBLIC SYNONYM common_errors FOR common.common_errors;


ALTER TABLE common.common_errors ADD (
  CONSTRAINT common_errors_pk
  PRIMARY KEY
  (id_common_errors)
  USING INDEX common.common_errors_pk
  ENABLE VALIDATE);