--ALTER TABLE common.common_error_alert
--   DROP PRIMARY KEY CASCADE;
--
--DROP TABLE common.common_error_alert CASCADE CONSTRAINTS;

CREATE TABLE common.common_error_alert
(
   id_common_error_alert    NUMBER NOT NULL,
   id_common_error_codes    NUMBER NOT NULL,
   first_id_common_errors   NUMBER NOT NULL,
   first_queued_dts         TIMESTAMP (6) NOT NULL,
   last_queued_dts          TIMESTAMP (6) NOT NULL,
   number_of_occurences     NUMBER NOT NULL,
   email_sent_dts           DATE,
   alert_acknowledged_dts   DATE
)
TABLESPACE &&enter_tblsp_m
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;


CREATE UNIQUE INDEX common.idx_common_error_alert
   ON common.common_error_alert (id_common_error_codes, email_sent_dts, alert_acknowledged_dts)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;

CREATE UNIQUE INDEX common.pk_common_error_alert
   ON common.common_error_alert (id_common_error_alert)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;


ALTER TABLE common.common_error_alert ADD (
  CONSTRAINT pk_common_error_alert
  PRIMARY KEY
  (id_common_error_alert)
  USING INDEX common.pk_common_error_alert
  ENABLE VALIDATE);


CREATE OR REPLACE PUBLIC SYNONYM common_error_alert FOR common.common_error_alert;