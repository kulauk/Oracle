/* 
Raise and propagate an Oracle error, then
trap that error and extract information about the error.
*/

CREATE OR REPLACE PROCEDURE dept_sal (department_id_in IN PLS_INTEGER)
IS
   l_max_salary   NUMBER;
   l_error        q$error_manager.error_info_rt;
BEGIN
   l_max_salary := CASE
                     WHEN department_id_in > 100
                        THEN 10000
                     ELSE 20000
                  END;

   BEGIN
      RAISE DUP_VAL_ON_INDEX;
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Trap the error, add some context, pass it along. */
         q$error_manager.raise_unanticipated
                       (name1_in       => 'DEPARTMENT ID'
                      , value1_in      => department_id_in
                      , name2_in       => 'MAX SALARY'
                      , value2_in      => l_max_salary
                      , name3_in       => 'TABLE_NAME'
                      , value3_in      => 'DEPARTMENTS'
                      , name4_in       => 'OWNER'
                      , value4_in      => USER
                       );
   END;
EXCEPTION
   WHEN OTHERS
   THEN
      q$error_manager.get_error_info (l_error);
      DBMS_OUTPUT.put_line ('');
      DBMS_OUTPUT.put_line ('Error in DEPT_SAL Procedure:');
      DBMS_OUTPUT.put_line ('Code = ' || l_error.code);
      DBMS_OUTPUT.put_line ('Name = ' || l_error.NAME);
      DBMS_OUTPUT.put_line ('Text = ' || l_error.text);
      DBMS_OUTPUT.put_line ('Error Stack = ' || l_error.error_stack);
END dept_sal;
/

BEGIN
   dept_sal (50);
   dept_sal (200);
END;
/