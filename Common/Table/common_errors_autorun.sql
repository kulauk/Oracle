--ALTER TABLE common.common_errors_autorun
--   DROP PRIMARY KEY CASCADE;
--
--DROP TABLE common.common_errors_autorun CASCADE CONSTRAINTS;

CREATE TABLE common.common_errors_autorun
(
   id_common_errors_autorun      NUMBER,
   id_common_error_codes         NUMBER,
   autorun_command               VARCHAR2 (2000 BYTE),
   autorun_command_with_params   VARCHAR2 (2000 BYTE),
   number_of_occurences          NUMBER,
   number_of_autoruns            NUMBER,
   status                        VARCHAR2 (50 BYTE),
   last_autorun_start_dts        DATE,
   created_dts                   DATE,
   modified_dts                  DATE
)
TABLESPACE &&enter_tblsp_m
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;


CREATE INDEX common.idx_ora_err_autorun1
   ON common.common_errors_autorun (status)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE INDEX common.idx_ora_err_autorun2
   ON common.common_errors_autorun (id_common_errors_autorun, last_autorun_start_dts)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE INDEX common.idx_ora_err_autorun3
   ON common.common_errors_autorun (id_common_error_codes, status)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE INDEX common.idx_ora_err_autorun4
   ON common.common_errors_autorun (autorun_command_with_params, status)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE UNIQUE INDEX common.pk_common_errors_autorun
   ON common.common_errors_autorun (id_common_errors_autorun)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

ALTER TABLE common.common_errors_autorun ADD (
  CONSTRAINT pk_common_errors_autorun
  PRIMARY KEY
  (id_common_errors_autorun)
  USING INDEX common.pk_common_errors_autorun
  ENABLE VALIDATE);
