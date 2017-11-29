SET DEFINE ON
SET FEEDBACK OFF
SET VERIFY OFF
DEFINE schema_name=&1
DEFINE app_name=&2

variable l_return_code number;

DECLARE
v_app_name VARCHAR2(100);

BEGIN

	SELECT  DISTINCT installed_applications
	INTO	v_app_name
	FROM	&schema_name..application_manager_t
	WHERE	installed_applications = '&app_name';

	:l_return_code := 0;
	DBMS_OUTPUT.PUT_LINE('EXIT CODE=' || :l_return_code );
EXCEPTION
WHEN no_data_found THEN
	:l_return_code := 1;	
	DBMS_OUTPUT.PUT_LINE('EXIT CODE=' || :l_return_code );
END;
/

EXIT :l_return_code