DECLARE
   c_support            CONSTANT  VARCHAR2(32767) := 'Please contact support on 01392 251289';
   c_recommendation     CONSTANT  VARCHAR2(32767) := 'An unexpected error has occured please contact the helpdesk on 01392 251289 quoting the following id: ';
   PROCEDURE p_create_qem_errors
   IS
   BEGIN
      FOR cur IN (  SELECT  id,
                            description,
                            plsql_constant_name,
                            qem_recommendation,
                            qem_sustitute_string 
                    FROM    status_code_t )
      LOOP                    
          BEGIN
            
            IF INSTR( cur.plsql_constant_name, 'gc_ferr' ) > 0 THEN
                  dbms_output.put_line ( 'Creating fatal error');
                  INSERT INTO q$error(
                                         id
                                       , error_category_name
                                       , code
                                       , name
                                       , description
                                       , substitute_string
                                       , recommendation
                                       , created_on
                                       , created_by                           
                             )
                  VALUES     (
                                 q$error_seq.NEXTVAL
                               , 'APP FATAL ERRORS'
                               , (20000 + cur.id) * -1
                               , REPLACE( UPPER(cur.description), ' ', '_' )
                               , 'A fatal error has been raised explicitly by the application'
                               , NVL( cur.qem_sustitute_string, '')
                               , NVL( cur.qem_recommendation, c_recommendation)
                               , SYSDATE
                               , 'QEM$DEFINE_ERRORS'
                             );
            ELSIF INSTR( cur.plsql_constant_name, 'gc_err' ) > 0 THEN
                    dbms_output.put_line ( 'Creating application error');
                  INSERT INTO q$error(
                                         id
                                       , error_category_name
                                       , code
                                       , name
                                       , description
                                       , substitute_string
                                       , recommendation
                                       , created_on
                                       , created_by                           
                             )
                  VALUES     (
                                 q$error_seq.NEXTVAL
                               , 'APPLICATION ERRORS'
                               , (20000 + cur.id) * -1
                               , REPLACE( UPPER(cur.description), ' ', '_' )
                               , 'A fatal error has been raised explicitly by the application'
                               , NVL( cur.qem_sustitute_string, '')
                               , NVL( cur.qem_recommendation, c_recommendation)
                               , SYSDATE
                               , 'QEM$DEFINE_ERRORS'
                             );  
            ELSE
                dbms_output.put_line ( 'Not fatal or application');                         
            END IF;
            
          EXCEPTION
          WHEN DUP_VAL_ON_INDEX
          THEN
             /* Running install over existing install. Just ignore. */
             dbms_output.put_line ( 'duplicate index found'); 
          END;
          
                 
      END LOOP;        
                                
   END p_create_qem_errors;
BEGIN   
   p_create_qem_errors;
   
END;
/   
   
COMMIT;
