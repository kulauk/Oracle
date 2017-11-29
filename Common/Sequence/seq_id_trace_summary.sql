--DROP SEQUENCE common.seq_id_trace_summary;

CREATE SEQUENCE common.seq_id_trace_summary START WITH 1 NOMAXVALUE MINVALUE 1 NOCYCLE CACHE 20 NOORDER;


CREATE OR REPLACE PUBLIC SYNONYM seq_id_trace_summary FOR common.seq_id_trace_summary;