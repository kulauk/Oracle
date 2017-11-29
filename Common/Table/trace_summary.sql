--ALTER TABLE common.trace_summary
--   DROP PRIMARY KEY CASCADE;
--
--DROP TABLE common.trace_summary CASCADE CONSTRAINTS;

PROMPT CREATING: common.trace_summary

CREATE TABLE common.trace_summary
(
   id_trace_summary NUMBER NOT NULL,
   package_name     VARCHAR2 (32 BYTE),
   procedure_name   VARCHAR2 (32 BYTE) NOT NULL,
   start_time       TIMESTAMP (9) NOT NULL,
   end_time         TIMESTAMP (9),
   trace_level      NUMBER (3) NOT NULL,
   procedure_call   VARCHAR2 (4000 BYTE),
   client_id        VARCHAR2 (500 BYTE) NOT NULL,
   owner            VARCHAR2 (50 BYTE) DEFAULT 'COMMON' NOT NULL
)
TABLESPACE &&enter_tblsp_s
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;


CREATE UNIQUE INDEX common.pk_trace_summary
   ON common.trace_summary (id_trace_summary)
   LOGGING
   TABLESPACE &&enter_indx_tblsp_s
   NOPARALLEL;


ALTER TABLE common.trace_summary ADD (
  CONSTRAINT pk_trace_summary
  PRIMARY KEY
  (id_trace_summary)
  USING INDEX common.pk_trace_summary
  ENABLE VALIDATE);

CREATE OR REPLACE PUBLIC SYNONYM trace_summary FOR common.trace_summary;