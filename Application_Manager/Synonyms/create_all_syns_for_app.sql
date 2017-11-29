SET DEFINE ON
DEFINE app_schema_name=&1
DEFINE app_manager_name=&2

DECLARE
    v_error VARCHAR2(32000);
BEGIN
    FOR c1 IN (	SELECT	application_object_name
		FROM	&app_manager_name..application_manager_t
		WHERE   create_synonym_flag = 'Y' )
    LOOP
	BEGIN
		EXECUTE IMMEDIATE 'CREATE OR REPLACE SYNONYM &app_schema_name..' || c1.application_object_name || ' FOR &app_manager_name..' || c1.application_object_name;
	EXCEPTION
	WHEN OTHERS THEN
		v_error := v_error || CHR(10) || 'Error occured running the command: CREATE OR REPLACE SYNONYM &app_schema_name..' || c1.application_object_name || 
				' FOR &app_manager_name..' || c1.application_object_name || CHR(10) || 'ERROR:...' || SQLERRM;
		DBMS_OUTPUT.PUT_LINE( v_error ); 
	END;
    END LOOP;

    IF v_error IS NOT NULL THEN
	RAISE_APPLICATION_ERROR ( -20000, 'ERROR OCCURED RUNNING SCRIPT: create_all_syns_for_app.sql' || v_error );
    END IF;

END;
/