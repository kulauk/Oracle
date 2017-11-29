--DROP TABLE common.common_error_values CASCADE CONSTRAINTS;

CREATE TABLE common.common_error_values
(
   id_common_errors   NUMBER NOT NULL,
   field              VARCHAR2 (1000 BYTE) NOT NULL,
   field_value        VARCHAR2 (1000 BYTE),
   id                 NUMBER
)
TABLESPACE &&enter_tblsp_m
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;


CREATE UNIQUE INDEX common.uk_common_error_values
   ON common.common_error_values (id_common_errors, field)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE OR REPLACE PUBLIC SYNONYM common_error_values FOR common.common_error_values;


ALTER TABLE common.common_error_values ADD (
  CONSTRAINT fk_orerrvalues_orerr
  FOREIGN KEY (id_common_errors)
  REFERENCES common.common_errors (id_common_errors)
  ON DELETE CASCADE
  ENABLE VALIDATE);