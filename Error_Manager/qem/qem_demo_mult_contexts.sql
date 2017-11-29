/* 
Raise and propagate an Oracle error, then
trap that error and extract information about the error.
*/

CREATE OR REPLACE PROCEDURE dept_sal (department_id_in IN PLS_INTEGER)
IS
   l_max_salary   NUMBER;
   l_error        q$error_manager.error_info_rt;
BEGIN
   IF q$error_manager.trace_enabled
   THEN
      q$error_manager.trace ('context1', department_id_in);
   END IF;

   l_max_salary := CASE WHEN department_id_in > 100 THEN 10000 ELSE 20000 END;

   IF q$error_manager.trace_enabled
   THEN
      q$error_manager.trace ('context2', l_max_salary);
   END IF;
END dept_sal;
/

BEGIN
   q$error_manager.trace_on ('context2,context1');
   q$error_manager.toscreen;
   
   dept_sal (50);
   dept_sal (200);

   IF q$error_manager.trace_enabled
   THEN
      q$error_manager.trace ('CONTEXT3', 'All done!');
   END IF;
END;
/