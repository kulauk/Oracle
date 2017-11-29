BEGIN
   DELETE FROM q$error_instance;

   FOR rec IN (SELECT *
                 FROM employees)
   LOOP
      DBMS_OUTPUT.put_line (rec.last_name);
      q$error_manager.register_error (error_name_in      => 'UNANTICIPATED-ERROR'
                                    , text_in            =>    'My message here: '
                                                            || rec.last_name
                                    , name1_in           => 'FIRSTNAME'
                                    , value1_in          => rec.first_name
                                     );
      q$error_manager.mark_q$error_handled;
   END LOOP;

   COMMIT;
END;