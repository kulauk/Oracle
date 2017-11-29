SET DEFINE ON
DEFINE app_schema_name=&1

DECLARE
    v_error VARCHAR2(32000);
BEGIN
    FOR c1 IN (	SELECT	application_object_name,
			grant_to_application
		FROM	application_manager_t
		WHERE   create_synonym_flag = 'Y' )
    LOOP
	BEGIN
		EXECUTE IMMEDIATE 'GRANT ' || c1.grant_to_application || ' ON ' || c1.application_object_name || ' TO &app_schema_name';
	EXCEPTION
	WHEN OTHERS THEN
		v_error := v_error || CHR(10) || 'Error occured running the command: GRANT ' || c1.grant_to_application || ' ON ' || c1.application_object_name || 
				' TO &app_schema_name' || CHR(10) || 'ERROR IS:...' || SQLERRM;
		DBMS_OUTPUT.PUT_LINE( v_error ); 
	END;
    END LOOP;

    IF v_error IS NOT NULL THEN
	RAISE_APPLICATION_ERROR ( -20000, 'ERROR OCCURED RUNNING SCRIPT: grant_all_pkgs_to_app.sql' || v_error );
    END IF;
END;
/