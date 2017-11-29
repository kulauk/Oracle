--DROP SEQUENCE common.seq_id_trace_config;

PROMPT CREATING: common.seq_id_trace_config 

CREATE SEQUENCE common.seq_id_trace_config START WITH 1 NOMAXVALUE MINVALUE 1 NOCYCLE CACHE 50 NOORDER;


CREATE OR REPLACE PUBLIC SYNONYM seq_id_trace_config FOR common.seq_id_trace_config;