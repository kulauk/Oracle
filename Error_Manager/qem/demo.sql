DECLARE
   l_error   q$error_manager.error_info_rt;
BEGIN
   q$error_manager.mark_q$error_handled;
   q$error_manager.raise_unanticipated
             (text_in      => 'Unexpected error when attempting to do X, Y and Z.');
EXCEPTION
   WHEN OTHERS
   THEN
      q$error_manager.get_error_info (l_error);
      DBMS_OUTPUT.put_line (l_error.NAME);
      DBMS_OUTPUT.put_line (l_error.text);
END;
/

/* Raise and propagate an Oracle error */

DECLARE
   l_error   q$error_manager.error_info_rt;
BEGIN
   q$error_manager.mark_q$error_handled;

   BEGIN
      RAISE DUP_VAL_ON_INDEX;
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Trap the error, add some context, pass it along. */
         q$error_manager.raise_unanticipated
                       (text_in        => 'Only one row allowed with these values.'
                      , name1_in       => 'TABLE_NAME'
                      , value1_in      => 'ABC'
                       );
   END;
EXCEPTION
   WHEN OTHERS
   THEN
      q$error_manager.get_error_info (l_error);
      DBMS_OUTPUT.put_line (l_error.code);
      DBMS_OUTPUT.put_line (l_error.NAME);
      DBMS_OUTPUT.put_line (l_error.text);
      DBMS_OUTPUT.put_line (l_error.error_stack);
END;
/

/*
And now raise exception deep in call stack...
*/

CREATE OR REPLACE PROCEDURE proc1
IS
BEGIN
   RAISE NO_DATA_FOUND;
END;
/

CREATE OR REPLACE PROCEDURE proc2
IS
BEGIN
   proc1;
END;
/

CREATE OR REPLACE PROCEDURE proc3
IS
BEGIN
   proc2;
END;
/

DECLARE
   l_error   q$error_manager.error_info_rt;
BEGIN
   q$error_manager.mark_q$error_handled;

   BEGIN
      proc3;
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Trap the error, add some context, pass it along. */
         q$error_manager.raise_unanticipated
                            (text_in      => 'Error completing execution of proc3');
   END;
EXCEPTION
   WHEN OTHERS
   THEN
      /* Retrieve the error information back into a record. */
      q$error_manager.get_error_info (l_error);
      DBMS_OUTPUT.put_line (l_error.code || ' - ' || l_error.NAME);
      DBMS_OUTPUT.put_line (l_error.text);
      DBMS_OUTPUT.put_line ('Error stack/trace:');
      DBMS_OUTPUT.put_line (l_error.error_stack);
      DBMS_OUTPUT.put_line ('Call stack:');
      DBMS_OUTPUT.put_line (l_error.call_stack);
END;
/