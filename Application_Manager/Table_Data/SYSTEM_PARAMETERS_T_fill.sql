CREATE SEQUENCE sys_param_seq
    START WITH 1
    MAXVALUE 999999999999999999999999999
    MINVALUE 1
    NOCYCLE
    NOCACHE
    NOORDER
/

TRUNCATE TABLE  system_parameters_t;

--==============================================================================
-- System parameters: 
--..............................................................................


INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL, SYSDATE, SYSDATE, 'SYSTEM_VERSION', '1.0', NULL, NULL );


INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL, SYSDATE, SYSDATE, 'CURRENT_SYSTEM_STATUS', '1', NULL, NULL );

INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL
       , SYSDATE
       , SYSDATE
       , 'SYSTEM_STATUS_OPEN'
       , '1'
       , ''
       , 'INTEGER'
       , 'gc_system_status_open' );
       
INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL
       , SYSDATE
       , SYSDATE
       , 'SYSTEM_STATUS_CLOSED'
       , '0'
       , ''
       , 'INTEGER'
       , 'gc_system_status_closed' );       


INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL
       , SYSDATE
       , SYSDATE
       , 'NHS_NUMBER_VALIDATION_LEVEL'
       , '1'
       , ''
       , 'INTEGER'
       , 'gc_nhs_number_validation_level' );

INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL
       , SYSDATE
       , SYSDATE
       , 'STANDARD_DATE_FORMAT'
       , '''DD.MM.YYYY'''
       , ''
       , 'VARCHAR2(10)'
       , 'gc_standard_date_format' );

INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL
       , SYSDATE
       , SYSDATE
       , 'STANDARD_DTTIME_FORMAT'
       , '''DD.MM.YYYY HH24:MI'''
       , ''
       , 'VARCHAR2(18)'
       , 'gc_standard_dttime_format' );


INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL, SYSDATE, SYSDATE, 'SMTP_MAIL_HOST_EXETER', '192.168.17.117', NULL, NULL, NULL );


INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL, SYSDATE, SYSDATE, 'SYSTEM_PASSWORD_TYPE', '''CLEAR''', NULL, 'VARCHAR2(5)', 'gc_system_password_type' );

INSERT INTO system_parameters_t( parameter_id
                               , created_dts
                               , last_updated_dts
                               , parameter_name
                               , parameter_value
                               , parameter_units
                               , parameter_type
                               , plsql_constant_name )
VALUES ( sys_param_seq.NEXTVAL, SYSDATE, SYSDATE, 'SYSTEM_SESSION_TYPE', '''SLAVE''', NULL, 'VARCHAR2(6)', 'gc_system_session_type' );


--==============================================================================
-- 
--..............................................................................
DROP SEQUENCE sys_param_seq;
COMMIT;