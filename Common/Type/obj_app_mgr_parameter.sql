--DROP TYPE common.obj_app_mgr_parameter;

CREATE OR REPLACE TYPE common.obj_app_mgr_parameter AS OBJECT
(
   parameter_name VARCHAR2 (32),
   param_value_varchar VARCHAR2 (4000),
   param_value_number NUMBER,
   param_value_date DATE
);
/