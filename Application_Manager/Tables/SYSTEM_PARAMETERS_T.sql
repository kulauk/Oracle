CREATE TABLE system_parameters_t (
                                   parameter_id         NUMBER( 38 ) NOT NULL
                                 , created_dts          DATE NOT NULL
                                 , last_updated_dts     DATE NOT NULL
                                 , parameter_name       VARCHAR2( 50 ) NOT NULL
                                 , parameter_value      VARCHAR2( 200 ) NOT NULL
                                 , parameter_units      VARCHAR2( 100 )
                                 , parameter_type       VARCHAR2( 30 )
                                 , plsql_constant_name  VARCHAR2( 30 )
                                 , CONSTRAINT xpk_sys_param_id PRIMARY KEY( parameter_id )
)
LOGGING
NOCOMPRESS
NOCACHE
NOPARALLEL
MONITORING;
