--ALTER TABLE common.TRACE_LOG
-- DROP PRIMARY KEY CASCADE;

--DROP TABLE common.TRACE_LOG CASCADE CONSTRAINTS;

PROMPT CREATING: common.trace_log

CREATE TABLE common.trace_log
(
   id_trace_log       NUMBER NOT NULL,
   id_trace_summary   NUMBER NOT NULL,
   module             VARCHAR2 (500 BYTE),
   context            VARCHAR2 (500 BYTE),
   position           NUMBER,
   name               VARCHAR2 (4000 BYTE),
   datatype           VARCHAR2 (100 BYTE),
   value_date         DATE,
   value_varchar      VARCHAR2 (4000 BYTE),
   value_number       NUMBER,
   value_clob         CLOB,
   call_stack         VARCHAR2 (4000 BYTE),
   datetime           TIMESTAMP (9),
   created_by         VARCHAR2 (100 BYTE),
   value_timestamp9   TIMESTAMP (9)
)
LOB (value_clob) STORE AS SECUREFILE
   (TABLESPACE &&enter_tblsp_lob)
TABLESPACE &&enter_tblsp_m
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;



CREATE UNIQUE INDEX common.pk_trace_log
   ON common.trace_log (id_trace_log)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_m
   NOPARALLEL;



ALTER TABLE common.trace_log ADD (
  CONSTRAINT pk_trace_log
  PRIMARY KEY
  (id_trace_log)
  USING INDEX common.pk_trace_log
  ENABLE VALIDATE);

ALTER TABLE common.trace_log ADD (
  CONSTRAINT fk_trace_summary_log
  FOREIGN KEY (id_trace_summary)
  REFERENCES common.trace_summary (id_trace_summary)
  ON DELETE CASCADE
  ENABLE VALIDATE);

CREATE OR REPLACE PUBLIC SYNONYM trace_log FOR common.trace_log;