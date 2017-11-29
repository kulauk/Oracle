CREATE OR REPLACE PACKAGE BODY common.error_utils
AS
    --=============================================================================
    --
    --      Declaration section
    --
    -- (Place your private package level variables and declarations here )
    --=============================================================================
    g_package_name   VARCHAR2 (30) := 'ERROR_UTILS';
    g_email_alert_threshold_hours CONSTANT PLS_INTEGER := 24;

    c_error_level_1      CONSTANT PLS_INTEGER := 1;
    c_error_level_2      CONSTANT PLS_INTEGER := 2;
    c_error_level_3      CONSTANT PLS_INTEGER := 3;
    c_error_level_4      CONSTANT PLS_INTEGER := 4;
    c_error_level_5      CONSTANT PLS_INTEGER := 5;

    c_error_threshold_mins_lvl1      CONSTANT PLS_INTEGER := 240;
    c_error_threshold_mins_lvl2      CONSTANT PLS_INTEGER := 180;
    c_error_threshold_mins_lvl3      CONSTANT PLS_INTEGER := 120;
    c_error_threshold_mins_lvl4      CONSTANT PLS_INTEGER := 60;


    c_dont_send_email_alert  CONSTANT PLS_INTEGER := 0;
    c_send_email_alert       CONSTANT PLS_INTEGER := 1;

    c_email_unacknowledged   CONSTANT PLS_INTEGER := 0;
    c_email_acknowledged     CONSTANT PLS_INTEGER := 1;

    c_emailsubject           CONSTANT VARCHAR2 (200) := 'Error table alert';
    c_attrib_idalerts        CONSTANT VARCHAR2 (20) := 'ID_EMAIL_ALERTS';
    c_messageTypeAlert       CONSTANT VARCHAR2 (20) := 'ERROR TABLE ALERT';


    c_autorun_resolved      CONSTANT VARCHAR2 (10) := 'RESOLVED';
    c_autorun_unresolved    CONSTANT VARCHAR2 (10) := 'UNRESOLVED';
    c_autorun_running       CONSTANT VARCHAR2 (9)  := 'RUNNING';
    c_autorun_complete      CONSTANT VARCHAR2 (9)  := 'COMPLETE';
    c_autorun_failed        CONSTANT VARCHAR2 (9)  := 'FAILED';

    c_autorun_execution_nonauto     CONSTANT PLS_INTEGER := 0;
    c_autorun_execution_auto        CONSTANT PLS_INTEGER := 1;
    c_autorun_execution_resolved    CONSTANT PLS_INTEGER := 2;

    c_maxlength_error_msg           CONSTANT PLS_INTEGER := 4000;

    g_id_ora_error_autorun    NUMBER;
    e_fatal EXCEPTION;

    --=============================================================================
    --
    --      PRIVATE PROCEDURES AND FUNCTIONS
    --
    --=============================================================================



    --=============================================================================
    --
    --      PUBLIC PROCEDURES AND FUNCTIONS
    --
    --=============================================================================

   /*******************************************************************************
        NAME: get_success_message
        TYPE: PUBLIC
     PURPOSE:
   REVISIONS:
   Ver    Patch   Date     Author           Description
   -----  -----  --------  ---------------  ---------------------------------------
   1.000  2726   02.04.07  Stephen Dooley   Initial Revision
   *******************************************************************************/
   FUNCTION get_success_message (
      p_idsblocation_in varchar2)
      RETURN common_error_codes.error_message%TYPE
   IS
      var_success_message   common_error_codes.error_message%TYPE;
   BEGIN
      BEGIN
         SELECT error_message
           INTO var_success_message
           FROM common_error_codes
          WHERE id_common_error_codes = 0
                AND idsblocation = p_idsblocation_in;
      EXCEPTION
         WHEN OTHERS
         THEN
            SELECT error_message
              INTO var_success_message
              FROM common_error_codes
             WHERE id_common_error_codes = 0 AND idsblocation = 'UK';
      END;

      RETURN var_success_message;
   END get_success_message;

   /*******************************************************************************
        NAME: get_message_translated
        TYPE: PRIVATE
     PURPOSE: if a NON UK error message does not exist, use this function to get
               the UK version, translate it to the relevant language and return the
              translated error message.
   REVISIONS:
   Ver    Patch  Date      Author           Description
   -----  -----  --------  ---------------  ---------------------------------------
   1.000  2726   02.04.07  Stephen Dooley   Initial Revision
   *******************************************************************************/
   FUNCTION get_message_translated (
      p_package_name_in    IN common_error_codes.package_name%TYPE,
      p_procfunc_name_in   IN common_error_codes.procfunc%TYPE,
      p_when_error_in      IN common_error_codes.when_error%TYPE,
      p_idsblocation_in    IN common_error_codes.idsblocation%TYPE)
      RETURN VARCHAR2
   IS
      p_error_message_out   common_error_codes.error_message%TYPE;
   BEGIN
      SELECT error_message
        INTO p_error_message_out
        FROM common_error_codes
       WHERE LOWER (SUBSTR (package_name, INSTR (package_name, '.') + 1)) =
                LOWER(SUBSTR (p_package_name_in,
                              INSTR (p_package_name_in, '.') + 1))
             AND LOWER (procfunc) = LOWER (p_procfunc_name_in)
             AND LOWER (when_error) = LOWER (p_when_error_in)
             AND LOWER (idsblocation) = LOWER (NVL (p_idsblocation_in, 'UK'));

      IF p_idsblocation_in NOT IN ('UK', 'IE', 'US', 'AU')
      THEN
         --or create a speak_english flag
         NULL;
      --call TheBigWord API to translate message into swedish
      --p_error_message_out:=API_CALL(text, languauge);
      END IF;

      RETURN p_error_message_out;
   END get_message_translated;

   /*******************************************************************************
        NAME: insert_err_codes
        TYPE: PRIVATE
     PURPOSE: A UK version of each unique EXCEPTION error should be already be
              added to this table, when the developer adds new functionality. This
              proc retrieves the error code and message. If the unique error message
              does not exist for non UK countries, then it is has to be translated
              then inserted into the common_error_codes table.
   REVISIONS:
   Ver    Patch  Date      Author           Description
   -----  -----  --------  ---------------  ---------------------------------------
   1.000  2726   02.04.07  Stephen Dooley   Initial Revision
   *******************************************************************************/
   PROCEDURE insert_err_codes (
      p_idsblocation_in     IN     common_error_codes.idsblocation%TYPE,
      p_package_name_in     IN     common_error_codes.package_name%TYPE,
      p_procfunc_name_in    IN     common_error_codes.procfunc%TYPE,
      p_when_error_in       IN     common_error_codes.when_error%TYPE,
      p_oracle_sqlerrm_in   IN     common_error_codes.error_message%TYPE,
      p_error_code_out         OUT common_error_codes.id_common_error_codes%TYPE,
      p_error_mess_out         OUT common_error_codes.error_message%TYPE)
   AS
   --var_message_translated   common_error_codes.ERROR_MESSAGE%TYPE;
   BEGIN
      BEGIN
         SELECT id_common_error_codes, error_message
           INTO p_error_code_out, p_error_mess_out
           FROM common_error_codes
          WHERE LOWER (SUBSTR (package_name, INSTR (package_name, '.') + 1)) =
                   LOWER(SUBSTR (p_package_name_in,
                                 INSTR (p_package_name_in, '.') + 1))
                AND LOWER (procfunc) = LOWER (p_procfunc_name_in)
                AND LOWER (when_error) = LOWER (p_when_error_in)
                AND LOWER (idsblocation) =
                      LOWER (NVL (p_idsblocation_in, 'UK'));
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            --            --not sure this is worth doing as TBW can do immediate translation
            --            var_message_translated:= get_message_translated(p_package_name_in,
            --                                                            p_procfunc_name_in,
            --                                                            p_when_error_in,
            --                                                            p_nationality_in);
            INSERT INTO common_error_codes (package_name,
                                            procfunc,
                                            when_error,
                                            error_message,
                                            idsblocation)
                VALUES (LOWER (p_package_name_in),
                        LOWER (p_procfunc_name_in),
                        LOWER (p_when_error_in),
                        LOWER (p_oracle_sqlerrm_in),
                        UPPER (p_idsblocation_in))
             RETURNING id_common_error_codes
                  INTO p_error_code_out;

            p_error_mess_out := p_oracle_sqlerrm_in;
            --p_error_mess_out := LOWER(var_message_translated);
            COMMIT;
      END;
   END insert_err_codes;

   /*******************************************************************************
        NAME: insert_trans_error
        TYPE: PRIVATE
     PURPOSE: record specific error for a clients unique transaction.
   REVISIONS:
   Ver    Patch  Date      Author           Description
   -----  -----  --------  ---------------  ---------------------------------------
   1.000  2726   02.04.07  Stephen Dooley   Initial Revision
   *******************************************************************************/
   PROCEDURE insert_trans_error (
      p_error_code_in       IN     common_errors.id_common_error_codes%TYPE,
      p_oracle_sqlerrm_in   IN     common_errors.oracle_sqlerrm%TYPE,
      p_field_in            IN     common_errors.field%TYPE,
      p_value_in            IN     common_errors.field_value%TYPE,
      p_error_id_out           OUT common_errors.id_common_errors%TYPE)
   AS
   BEGIN
      INSERT INTO common_errors (id_common_error_codes,
                                 oracle_sqlerrm,
                                 field,
                                 field_value)
          VALUES (LOWER (p_error_code_in),
                  LOWER (p_oracle_sqlerrm_in),
                  LOWER (p_field_in),
                  LOWER (p_value_in))
       RETURNING id_common_errors
            INTO p_error_id_out;

      COMMIT;
   END insert_trans_error;


   /******************************************************************************
        NAME: error_utils
     PURPOSE: logs error encountered and return error message in clients selected
              language.
   REVISIONS:
   Ver    Patch  Date      Author         Description
   -----  -----  --------  -------------  -----------------------------------------
   1.000  2726   26/01/07  S Dooley       Overloaded version to handle international
                                          also stuck the main code into sub procs.
   ******************************************************************************/
   PROCEDURE log_error (
      p_idsblocation_in     IN     VARCHAR2,
      p_package_name_in     IN     VARCHAR2,
      p_procfunc_name_in    IN     VARCHAR2,
      p_when_error_in       IN     VARCHAR2,
      p_oracle_sqlerrm_in   IN     VARCHAR2,
      p_field_in            IN     VARCHAR2,
      p_value_in            IN     VARCHAR2,
      p_error_code_out         OUT NUMBER,
      p_error_message_out      OUT VARCHAR2)
   IS
--      l_error_id        NUMBER;
--      l_oracle_sqlerrm_in common_errors.error_message%TYPE;
--
      l_errormsg         VARCHAR2 (4000);
      l_errorcode        NUMBER;
   BEGIN
--        l_errormsg := p_error_message_in;
        l_errorcode := log_error_alert  (   p_package_name_in        => p_package_name_in,
                                            p_procfunc_name_in       => p_procfunc_name_in,
                                            p_when_error_in          => p_when_error_in,
                                            p_oracle_sqlerrm_in      => p_oracle_sqlerrm_in,
                                            p_error_message_in_out   => l_errormsg,
                                            p_error_nvp_tbl          => error_utils.init_error_nvp,
                                            p_error_level            => 0,
                                            p_autorun_command        => NULL );

        p_error_code_out := l_errorcode;

--      insert_err_codes (p_idsblocation_in,
--                        p_package_name_in,
--                        p_procfunc_name_in,
--                        p_when_error_in,
--                        p_oracle_sqlerrm_in,
--                        p_error_code_out,
--                        p_error_message_out);
--
--      l_oracle_sqlerrm_in := p_oracle_sqlerrm_in || CHR(13) || dbms_utility.format_error_backtrace;
--
--      insert_trans_error (p_error_code_out,
--                          l_oracle_sqlerrm_in,
--                          p_field_in,
--                          p_value_in,
--                          l_error_id);
--      p_error_message_out :=
--         create_error_message (p_error_message_out,
--                               l_error_id,
--                               p_idsblocation_in);
--   EXCEPTION
--      WHEN OTHERS
--      THEN
--         insert_err_codes (p_idsblocation_in,
--                           p_package_name_in,
--                           p_procfunc_name_in,
--                           'OTHERS',
--                           p_oracle_sqlerrm_in,
--                           p_error_code_out,
--                           p_error_message_out);
--         insert_trans_error (p_error_code_out,
--                             p_oracle_sqlerrm_in,
--                             p_field_in,
--                             p_value_in,
--                             l_error_id);
--         p_error_message_out :=
--            --p_error_message_out||' '||l_error_id||' '||p_idsblocation_in;
--            create_error_message (p_error_message_out,
--                                  l_error_id,
--                                  p_idsblocation_in);
   END log_error;


   /******************************************************************************
      NAME:       log_errors
      PURPOSE:
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        26/01/2007  Kaiser Khan      1. Created this package body.
      2.0        04/03/2013  Duncan Lucas     2. Update to include support for email alerts and
                                                 passing a collection of field values
   ******************************************************************************/

   FUNCTION log_error (p_package_name_in        IN     VARCHAR2,
                       p_procfunc_name_in       IN     VARCHAR2,
                       p_when_error_in          IN     VARCHAR2,
                       p_oracle_sqlerrm_in      IN     VARCHAR2,
                       p_error_message_in_out   IN OUT VARCHAR2,
                       p_field_in               IN     VARCHAR2,
                       p_value_in               IN     VARCHAR2 )
      RETURN NUMBER
   IS
      l_nvp_tbl     error_nvp_tbl;
   BEGIN
        -- set local collection first element with name value pair so we can call error_log
--        l_nvp_tbl(NVL(p_field_in, '')) := p_value_in;

        l_nvp_tbl(1).field := NVL(p_field_in, '');
        l_nvp_tbl(1).field_value := NVL(p_value_in, '');

        RETURN log_error_alert  (   p_package_name_in        => p_package_name_in,
                                    p_procfunc_name_in       => p_procfunc_name_in,
                                    p_when_error_in          => p_when_error_in,
                                    p_oracle_sqlerrm_in      => p_oracle_sqlerrm_in,
                                    p_error_message_in_out   => p_error_message_in_out,
                                    p_error_nvp_tbl          => l_nvp_tbl,
                                    p_error_level            => NULL  );  -- use a default of 1 to set the lowest error level for existing code
                                                               -- any new code should use the new version
   END log_error;

   /******************************************************************************
      NAME:       error_utils
      PURPOSE:
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        26/01/2007  Kaiser Khan      1. Created this package body.
      2.0        04/03/2013  Duncan Lucas     2. Update to include support for email alerts and
                                                 passing a collection of field values
      3.0        01/04/2014  Duncan Lucas     3. Added autorun capabilities
                                                NOTE: for autorun commands which have date parameters
                                                      you must supply the full date in this format
                                                      dd/mm/yyyy hh24:mi:ss  (even if you don't have a time component)
   ******************************************************************************/
    FUNCTION log_error_alert ( p_package_name_in        IN     VARCHAR2,
                               p_procfunc_name_in       IN     VARCHAR2,
                               p_when_error_in          IN     VARCHAR2,
                               p_oracle_sqlerrm_in      IN     VARCHAR2,
                               p_error_message_in_out   IN OUT VARCHAR2,
                               p_error_nvp_tbl          IN     error_nvp_tbl,
                               p_error_level            IN     NUMBER DEFAULT NULL,
                               p_autorun_command        IN     VARCHAR2 DEFAULT NULL)
      RETURN NUMBER
    IS
        g_procfunc_name    VARCHAR2 (30) := 'LOG_ERROR_ALERT';
        p_error_code_out   NUMBER;
        l_errormsg         VARCHAR2 (1000);
        l_errorcode        NUMBER;
        l_error_id         NUMBER;
--        l_send_alert_email        common_error_codes.send_alert_email%TYPE;
        l_oracle_sqlerrm_in       common_errors.oracle_sqlerrm%TYPE;
        rec_common_error_codes    common_error_codes%ROWTYPE;
        l_error_level             common_error_codes.error_level%TYPE;

        l_key             common_errors.field%TYPE;

        l_id_common_errors_autorun  common_errors_autorun.id_common_errors_autorun%TYPE;
        l_autorun_execution         common_errors.autorun_execution%TYPE;
        PRAGMA AUTONOMOUS_TRANSACTION;

        -----------------------------------------------------------------------
        --.............................
        PROCEDURE register_new_error_code
        IS
        BEGIN
            -- set default value for error level
            l_error_level := NVL(p_error_level, 1);

--            -- check error level if set and above 5 then set email alerts on
--            IF l_error_level >= c_error_level_5 THEN
--                l_send_alert_email := 1;
--            ELSE
--                l_send_alert_email := 0;
--            END IF;

            -- register new error code
            -- set send email alert to null intially (only used to force an alert)
            INSERT INTO common_error_codes (package_name,
                                            procfunc,
                                            when_error,
                                            error_message,
                                            error_level,
                                            send_alert_email)
                VALUES (p_package_name_in,
                        p_procfunc_name_in,
                        p_when_error_in,
                        p_error_message_in_out,
                        l_error_level,
                        NULL)
             RETURNING  id_common_error_codes,
                        package_name,
                        procfunc,
                        when_error,
                        error_message,
                        idsblocation,
                        error_level,
                        send_alert_email,
                        email_alert_threshold_hours
             INTO rec_common_error_codes;
        END register_new_error_code;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE check_new_error_level
        IS
        BEGIN

            -- now check if the error level was set by the parameter and if it is different to the table value then
            -- use the new error level and update the tabel
            IF p_error_level IS NOT NULL AND (rec_common_error_codes.error_level <> p_error_level) THEN

--                -- check error level if set and above 5 then set email alerts on
--                IF p_error_level >= c_error_level_5 THEN
--                    l_send_alert_email := 1;
--                ELSE
--                    l_send_alert_email := 0;
--                END IF;

                rec_common_error_codes.error_level := p_error_level;
--                rec_common_error_codes.send_alert_email := l_send_alert_email;

                -- if error level changes then reset send_alert_email flag back to null
                UPDATE common_error_codes
                SET error_level = p_error_level,
                    send_alert_email = NULL
                WHERE id_common_error_codes = rec_common_error_codes.id_common_error_codes;

            END IF;

        END check_new_error_level;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE insert_error_autorun
        IS
            l_autorun_command               common_errors_autorun.autorun_command%TYPE;
            l_autorun_command_with_params   common_errors_autorun.autorun_command_with_params%TYPE;

            -----------------------------------------------------------------------
            -----------------------------------------------------------------------
        BEGIN
            -- only generate an autorun entry if this error is not the result of an autorun itself
            -- indicated by g_id_ora_error_autorun variable being null
            IF p_autorun_command IS NOT NULL AND g_id_ora_error_autorun IS NULL THEN

                -- set the autorun command
                l_autorun_command := p_autorun_command;

                -- set flag to indicate this was NOT an autorun execution
                l_autorun_execution := c_autorun_execution_nonauto;

                l_autorun_command_with_params := set_autorun_command (  p_id_common_errors  => l_error_id,
                                                                        p_autorun_command   => l_autorun_command );
                -- Merge into common_errors_autorun
                -- unique index is on autorun_command and resolved column
                -- so if row exists unresolved (0) then it will just update the existing row to increment the number of occurences
                -- if there is no unresolved entry for this autorun_command then add an entry so it will be autorun.
                BEGIN
                    SELECT  id_common_errors_autorun
                    INTO    l_id_common_errors_autorun
                    FROM    common_errors_autorun
                    WHERE autorun_command_with_params = l_autorun_command_with_params
                    AND status = c_autorun_unresolved;
                EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_id_common_errors_autorun := NULL;
                END;

                IF l_id_common_errors_autorun IS NOT NULL THEN


                    -- if the autorun_command already exists in an unresolved state then just update that row
                    -- to increment the count and last occured date
                    UPDATE common_errors_autorun ar
                    SET ar.number_of_occurences = (ar.number_of_occurences + 1),
                        ar.modified_dts = SYSDATE
                    WHERE ar.id_common_errors_autorun = l_id_common_errors_autorun;

                ELSE

                    -- if no autorun_command exists unresolved then insert a new entry so that autorun happens
                    INSERT INTO common_errors_autorun
                        (   id_common_errors_autorun,
                            id_common_error_codes,
                            autorun_command,
                            autorun_command_with_params,
                            number_of_occurences,
                            number_of_autoruns,
                            status,
                            last_autorun_start_dts,
                            created_dts,
                            modified_dts )
                    VALUES (seq_id_common_errors_autorun.NEXTVAL,
                            p_error_code_out,
                            l_autorun_command,
                            l_autorun_command_with_params,
                            1,
                            0,
                            c_autorun_unresolved,
                            NULL,
                            SYSDATE,
                            SYSDATE
                            )
                    RETURNING id_common_errors_autorun INTO l_id_common_errors_autorun;

                END IF;

            ELSIF g_id_ora_error_autorun IS NOT NULL THEN
                -- ifthe global g_id_ora_error_autorun is set this
                -- indicates that this error was a result of an autorun itself so in this case
                -- we need to insert this g_id_ora_error_autorun id onto the common_errors instance
                -- to show that the error occured as the result of an autorun.
                -- This is used by the autorun job to determin if the autorun was successful or not
                -- ie if the common_errors row exists with the id_common_error_autorun column set then
                -- the error either instigated an autorun OR was the result of an autorun
                l_id_common_errors_autorun := g_id_ora_error_autorun;

                -- set flag to indicate this was an autorun execution
                l_autorun_execution := c_autorun_execution_auto;

            ELSE
                -- no autorun_command is set to just ensure the id is set to null
                -- it is used to insert into the common_errors table
                l_id_common_errors_autorun := NULL;
            END IF;

            UPDATE common_errors
            SET id_common_errors_autorun = l_id_common_errors_autorun,
                autorun_execution   = l_autorun_execution
            WHERE id_common_errors = l_error_id;

            -- reset global
            g_id_ora_error_autorun := NULL;

        END insert_error_autorun;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE insert_new_error_instance
        IS
            l_field             common_errors.field%TYPE;
            l_field_value       common_errors.field_value%TYPE;
        BEGIN
          -- set the oracle error message to include the backtrace
            l_oracle_sqlerrm_in := p_oracle_sqlerrm_in || CHR(13) || dbms_utility.format_error_backtrace;

            IF p_error_nvp_tbl.COUNT = 1 THEN
                -- the first element of the name value collection holding the field values is placed in the common_errors table
                -- get the first element name from nvp collection
--                l_key := p_error_nvp_tbl.first;
--
--                l_field := l_key;
--                l_field_value := p_error_nvp_tbl(l_key);
--
                l_field := p_error_nvp_tbl(1).field;
                l_field_value := p_error_nvp_tbl(1).field_value;

            ELSE
                -- the field and field_values will just be null
                NULL;
            END IF;

            -- insert into common_errors using first value from collection for name and value
            INSERT INTO common_errors ( id_common_error_codes,
                                         oracle_sqlerrm,
                                         field,
                                         field_value,
                                         error_message)
              VALUES (p_error_code_out,
                      l_oracle_sqlerrm_in,
                      l_field,
                      l_field_value,
                      p_error_message_in_out)
            RETURNING id_common_errors
                INTO l_error_id;


        END insert_new_error_instance;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE insert_new_error_values
        IS
            l_field             common_errors.field%TYPE;
            l_field_value       common_errors.field_value%TYPE;

        BEGIN

            -- need to check how many oracle values in the collection.. if we only have 1 then it gets logged in common_errors only
            -- for more than 1 then we log first value in common_errors and ALL values in common_error_values
            IF p_error_nvp_tbl.COUNT > 1 THEN

                -- the first element of the name value collection holding the field values is placed in the common_errors table
                -- get the first element name from nvp collection

--                l_key := p_error_nvp_tbl.first;

                -- loop through collection of name value pairs and add to common_errors and if more than 1 place nvps in common_error_values table
                -- can't do this using bulk because it is not supported for associative array
                FOR i IN p_error_nvp_tbl.FIRST .. p_error_nvp_tbl.LAST
                LOOP
--                    i := i + 1;
                    l_field := p_error_nvp_tbl(i).field;
                    l_field_value := p_error_nvp_tbl(i).field_value;

                    -- insert into the common_errors_nvp table
                    INSERT INTO common_error_values (
                            id_common_errors,
                            id,
                            field,
                            field_value )
                    VALUES (l_error_id,
                            i,
                            l_field,
                            l_field_value );

--                    -- iterate key to next value in collection
--                    l_key := p_error_nvp_tbl.NEXT(l_key);

--                    EXIT WHEN l_key IS NULL;


                END LOOP;
            END IF;

        END insert_new_error_values;
        -----------------------------------------------------------------------
        --.................................................
        PROCEDURE log_email_alert (   p_rec_oraerrcodes           IN  common_error_codes%ROWTYPE,
                                      p_id_common_errors          IN  common_errors.id_common_errors%TYPE )
        IS
        BEGIN
            -- check to see if we need to send an alert by checking last sent date and the threshold for this type of alert
            -- or if the send email alert flag is set
            -- we queue up the error
            IF  g_id_ora_error_autorun IS NULL AND
                (p_rec_oraerrcodes.error_level >= c_error_level_1 OR
                p_rec_oraerrcodes.send_alert_email = c_send_email_alert)
            THEN


                -- first try and update the common_error_alert table to record the latest occurence of the
                -- error for the unacknowledged rows where the email has yet to be sent
                --and if no rows updated then it must be a new occurence of the error since the last the email sent (or first occurence)
                -- in which case insert a new row
                UPDATE common_error_alert
                SET last_queued_dts = SYSTIMESTAMP,
                    number_of_occurences = (number_of_occurences + 1)
                WHERE id_common_error_codes = p_rec_oraerrcodes.id_common_error_codes
                AND email_sent_dts IS NULL
                AND alert_acknowledged_dts IS NULL;

                IF SQL%ROWCOUNT = 0 THEN

                    -- record first occurence of the error alert
                    INSERT INTO common_error_alert (
                                id_common_error_alert,
                                id_common_error_codes,
                                first_id_common_errors,
                                first_queued_dts,
                                last_queued_dts,
                                number_of_occurences,
                                email_sent_dts,
                                alert_acknowledged_dts)
                    VALUES (    seq_id_common_error_alert.NEXTVAL,
                                p_rec_oraerrcodes.id_common_error_codes,
                                p_id_common_errors,
                                SYSTIMESTAMP,
                                SYSTIMESTAMP,
                                1,
                                NULL,
                                NULL );
                END IF;

            ELSE -- no emails need to be sent the errors are logged as normal in common_errors so do nothing
                NULL;
            END IF;


        END log_email_alert;
        -----------------------------------------------------------------------
        -----------------------------------------------------------------------


    --===========================
    -- START MAIN:log_error_alert
    --==========================
    BEGIN
       -- first fetch error type from common_error_codes... if error doesn't exist then register a new error by adding a new row
        BEGIN
         SELECT id_common_error_codes,
                package_name,
                procfunc,
                when_error,
                error_message,
                idsblocation,
                error_level,
                send_alert_email,
                email_alert_threshold_hours
           INTO rec_common_error_codes
           FROM common_error_codes
          WHERE     NVL(package_name, 'X') = NVL(p_package_name_in, 'X')
                AND procfunc = p_procfunc_name_in
                AND when_error = p_when_error_in;
        EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            register_new_error_code;
        END;

        -- need to check if the error_level has changed
--        check_new_error_level;        -- dont want to change error level anymore  just change in table data

        -- set out parameter
        p_error_code_out := rec_common_error_codes.id_common_error_codes;
        -- call procedure to insert error instance;
        insert_new_error_instance;

        -- call procedure to insert all the rest of the error values if any exist
        insert_new_error_values;

        -- call procedure to check for an autorun entry
        insert_error_autorun;

        -- now log an email alert if it is necessary
        log_email_alert ( p_rec_oraerrcodes       => rec_common_error_codes,
                          p_id_common_errors      => l_error_id );


        COMMIT;

        -- reset output error message
        p_error_message_in_out :=
            p_error_message_in_out
         || ' Please quote this error code '
         || l_error_id
         || ' at all times.';

        RETURN p_error_code_out;

    EXCEPTION
      WHEN OTHERS
      THEN

        l_oracle_sqlerrm_in := SQLERRM || CHR(13) || dbms_utility.format_error_backtrace;
         BEGIN
            SELECT id_common_error_codes
              INTO p_error_code_out
              FROM common_error_codes
             WHERE     package_name = g_package_name
                   AND procfunc = g_procfunc_name
                   AND when_error = 'OTHERS';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               INSERT INTO common_error_codes (package_name,
                                               procfunc,
                                               when_error,
                                               error_message)
                   VALUES (g_package_name,
                           g_procfunc_name,
                           'OTHERS',
                           p_error_message_in_out)
                RETURNING id_common_error_codes
                     INTO p_error_code_out;

               COMMIT;
         END;

         INSERT INTO common_errors (id_common_error_codes,
                                    oracle_sqlerrm,
                                    field,
                                    field_value,
                                    error_message)
             VALUES (p_error_code_out,
                     l_oracle_sqlerrm_in,
                     NULL,
                     NULL,
                     p_error_message_in_out)
          RETURNING id_common_errors
               INTO l_error_id;

         COMMIT;
         p_error_message_in_out :=
               p_error_message_in_out
            || ' Please quote this error code '
            || l_error_id
            || ' at all times.';


         RETURN p_error_code_out;
    END log_error_alert;




   /******************************************************************************
      NAME:       log_error
      PURPOSE:      Calls the function log_error but return nothing to client
                    For use when you don't care about the return codes you just want the error logged
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        22/02/2013  Duncan Lucas     1. Created this package body.
   ******************************************************************************/
   PROCEDURE log_error_alert (  p_package_name_in        IN     VARCHAR2,
                                p_procfunc_name_in       IN     VARCHAR2,
                                p_when_error_in          IN     VARCHAR2,
                                p_oracle_sqlerrm_in      IN     VARCHAR2,
                                p_error_message_in       IN     VARCHAR2,
                                p_error_nvp_tbl          IN     error_nvp_tbl,
                                p_error_level            IN     NUMBER DEFAULT NULL,
                                p_autorun_command        IN     VARCHAR2 DEFAULT NULL)
   IS
      l_errormsg         VARCHAR2 (4000);
      l_errorcode        NUMBER;
   BEGIN
        l_errormsg := p_error_message_in;
        l_errorcode := log_error_alert  (   p_package_name_in        => p_package_name_in,
                                            p_procfunc_name_in       => p_procfunc_name_in,
                                            p_when_error_in          => p_when_error_in,
                                            p_oracle_sqlerrm_in      => p_oracle_sqlerrm_in,
                                            p_error_message_in_out   => l_errormsg,
                                            p_error_nvp_tbl          => p_error_nvp_tbl,
                                            p_error_level            => p_error_level,
                                            p_autorun_command        => p_autorun_command );

   END log_error_alert;

    --=============================================================================
    FUNCTION format_errmsg ( p_error_message    IN  VARCHAR2,
                             p_error_nvp_tbl    IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp())
    RETURN VARCHAR2
    IS
        l_return_errmsg VARCHAR2(4000);
    BEGIN
        l_return_errmsg := p_error_message;

        -- add the error values to the error message
        IF p_error_nvp_tbl.COUNT > 0 THEN

            FOR i IN 1 .. p_error_nvp_tbl.COUNT
            LOOP
                l_return_errmsg := l_return_errmsg || CHR(13) || p_error_nvp_tbl(i).field || ' = ' || p_error_nvp_tbl(i).field_value;

            END LOOP;
        END IF;

        -- now add the full error stack
        l_return_errmsg := l_return_errmsg || CHR(13) || DBMS_UTILITY.FORMAT_ERROR_STACK || CHR(13) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE ;

        -- limit the error message to the max size
        l_return_errmsg := SUBSTR(l_return_errmsg, 1, c_maxlength_error_msg);

        RETURN l_return_errmsg;
    END format_errmsg;
    --=============================================================================
    -- This procedure raises an application error
    -- It is better to do it this way with RAISE_APPLICATION_ERROR since you can specify
    -- the exact message and pass values to the error stack, and get the full back trace of the line
    -- number where the error occured. Whereas if you just use user defined errors then each time you
    -- reraise after handling the UDE you will lose the full error stack which contains the line number of the error.
    -- The default error level is 1 which means it will always trace (if tracing is on) but this can be overriden.
    -- .....................
    PROCEDURE handle_error (p_log_error         IN  BOOLEAN DEFAULT FALSE,
                            p_package_name      IN  VARCHAR2 DEFAULT NULL,
                            p_procedure_name    IN  VARCHAR2 DEFAULT NULL,
                            p_when_error        IN  VARCHAR2 DEFAULT NULL,
                            p_error_code        IN  NUMBER DEFAULT SQLCODE,
                            p_error_message     IN  VARCHAR2 DEFAULT SQLERRM,
                            p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                            p_error_level       IN  PLS_INTEGER DEFAULT 0,
                            ------------------
                            p_trace_level       IN  PLS_INTEGER DEFAULT 1,
                            p_reraise_error     IN  BOOLEAN DEFAULT FALSE )
    IS
        l_error_message     VARCHAR2(4000);
        l_errormsg_out      VARCHAR2(4000);

        --======================================================================
        PROCEDURE trace_all_values
        IS
        BEGIN
            -- create trace entry for the error messsage
            -- pkg_app_manager.p_trace (p_level => p_trace_level, p_name => 'ERROR:', p_text => l_error_message);

            FOR i IN 1 .. p_error_nvp_tbl.COUNT
            LOOP
                -- create trace entry for the error messsage
                -- pkg_app_manager.p_trace (p_level => p_trace_level, p_name => 'ERROR: ' || p_error_nvp_tbl(i).field, p_text => p_error_nvp_tbl(i).field_value);
                DBMS_OUTPUT.PUT_LINE('ERROR: ' || p_error_nvp_tbl(i).field || ': ' || p_error_nvp_tbl(i).field_value);
            END LOOP;
        END trace_all_values;
        --======================================================================
        PROCEDURE log_error_alert
        IS
        BEGIN
            -- if required log error and alert
            IF p_log_error THEN

                common.error_utils.log_error_alert (p_package_name,
                                                    p_procedure_name,
                                                    p_when_error,
                                                    l_error_message,
                                                    l_errormsg_out,
                                                    p_error_nvp_tbl,
                                                    p_error_level);

            END IF;
        END log_error_alert;
        --======================================================================
        PROCEDURE reraise_error
        IS
            l_error_code    NUMBER;
        BEGIN
            -- if required reraise the error with the specified error code and formatted error message
            IF p_reraise_error THEN

                -- ensure error code is within valid range                
                IF p_error_code BETWEEN -20999 AND -20000 THEN 
                    l_error_code := p_error_code;
                ELSE
                    l_error_code := -20001;
                END IF;                
                -- raise the error after formatting the error message to include the full stack trace of where the error occured
                RAISE_APPLICATION_ERROR(l_error_code, l_error_message);
            END IF;
        END reraise_error;
        --======================================================================
        --======================================================================
    BEGIN

        -- format error message to include backtrace error stack
        l_error_message := format_errmsg (  p_error_message => p_error_message,
                                            p_error_nvp_tbl => p_error_nvp_tbl);

        -- create trace entry for the error messsage
        trace_all_values;

        -- check flag and log if required
        log_error_alert;

        -- re raise the error if required
        reraise_error;

    END handle_error;


    PROCEDURE log_and_raise (   p_package_name      IN  VARCHAR2,
                                p_procedure_name    IN  VARCHAR2,
                                p_when_error        IN  VARCHAR2,
                                p_error_code        IN  NUMBER DEFAULT SQLCODE,
                                p_error_message     IN  VARCHAR2 DEFAULT SQLERRM,
                                p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                                p_error_level       IN  PLS_INTEGER DEFAULT 0,
                                p_trace_level       IN  PLS_INTEGER DEFAULT 1 )
    IS
    BEGIN

        handle_error (  p_log_error         => TRUE,
                        p_package_name      => UPPER(p_package_name),
                        p_procedure_name    => UPPER(p_procedure_name),
                        p_when_error        => p_when_error,
                        p_error_code        => p_error_code,
                        p_error_message     => p_error_message,
                        p_error_nvp_tbl     => p_error_nvp_tbl,
                        p_error_level       => p_error_level,
                        ------------------
                        p_trace_level       => p_trace_level,
                        p_reraise_error     => TRUE );
    END log_and_raise;

    PROCEDURE log_no_raise (    p_package_name      IN  VARCHAR2,
                                p_procedure_name    IN  VARCHAR2,
                                p_when_error        IN  VARCHAR2,
                                p_error_message     IN  VARCHAR2 DEFAULT SQLERRM,
                                p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                                p_error_level       IN  PLS_INTEGER DEFAULT 0,
                                p_trace_level       IN  PLS_INTEGER DEFAULT 1 )
    IS
    BEGIN
        handle_error (  p_log_error         => TRUE,
                        p_package_name      => UPPER(p_package_name),
                        p_procedure_name    => UPPER(p_procedure_name),
                        p_when_error        => p_when_error,
                        p_error_message     => p_error_message,
                        p_error_nvp_tbl     => p_error_nvp_tbl,
                        p_error_level       => p_error_level,
                        ------------------
                        p_trace_level       => p_trace_level,
                        p_reraise_error     => FALSE );
    END log_no_raise;

    PROCEDURE raise_error ( p_error_code        IN  NUMBER,
                            p_error_message     IN  VARCHAR2,
                            p_error_value       IN  VARCHAR2,
                            p_trace_level       IN  PLS_INTEGER DEFAULT 1 )
    IS
    BEGIN
        handle_error (  p_log_error         => FALSE,
                        p_error_code        => p_error_code,
                        p_error_message     => p_error_message,
                        p_error_nvp_tbl     => error_utils.init_error_nvp(  p_name1    => 'ERROR VALUE:',
                                                                            p_value1   => p_error_value),
                        ------------------
                        p_trace_level       => p_trace_level,
                        p_reraise_error     => TRUE );
    END raise_error;

    PROCEDURE raise_error ( p_error_code        IN  NUMBER,
                            p_error_message     IN  VARCHAR2,
                            p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                            p_trace_level       IN  PLS_INTEGER DEFAULT 1 )
    IS
    BEGIN
        handle_error (  p_log_error         => FALSE,
                        p_error_code        => p_error_code,
                        p_error_message     => p_error_message,
                        p_error_nvp_tbl     => p_error_nvp_tbl,
                        ------------------
                        p_trace_level       => p_trace_level,
                        p_reraise_error     => TRUE );
    END raise_error;

    FUNCTION init_error_nvp (   p_name1         IN  VARCHAR2    DEFAULT NULL,
                                p_value1        IN  VARCHAR2    DEFAULT NULL,
                                p_name2         IN  VARCHAR2    DEFAULT NULL,
                                p_value2        IN  VARCHAR2    DEFAULT NULL,
                                p_name3         IN  VARCHAR2    DEFAULT NULL,
                                p_value3        IN  VARCHAR2    DEFAULT NULL,
                                p_name4         IN  VARCHAR2    DEFAULT NULL,
                                p_value4        IN  VARCHAR2    DEFAULT NULL,
                                p_name5         IN  VARCHAR2    DEFAULT NULL,
                                p_value5        IN  VARCHAR2    DEFAULT NULL,
                                p_name6         IN  VARCHAR2    DEFAULT NULL,
                                p_value6        IN  VARCHAR2    DEFAULT NULL,
                                p_name7         IN  VARCHAR2    DEFAULT NULL,
                                p_value7        IN  VARCHAR2    DEFAULT NULL,
                                p_name8         IN  VARCHAR2    DEFAULT NULL,
                                p_value8        IN  VARCHAR2    DEFAULT NULL,
                                p_name9         IN  VARCHAR2    DEFAULT NULL,
                                p_value9        IN  VARCHAR2    DEFAULT NULL,
                                p_name10        IN  VARCHAR2    DEFAULT NULL,
                                p_value10       IN  VARCHAR2    DEFAULT NULL )
    RETURN error_nvp_tbl
    IS
        l_error_nvp_tbl error_nvp_tbl;
    BEGIN
        IF p_name1 IS NOT NULL THEN
            l_error_nvp_tbl(1).field        := p_name1;
            l_error_nvp_tbl(1).field_value  := p_value1;
        END IF;

        IF p_name2 IS NOT NULL THEN
            l_error_nvp_tbl(2).field        := p_name2;
            l_error_nvp_tbl(2).field_value  := p_value2;
        END IF;

        IF p_name3 IS NOT NULL THEN
            l_error_nvp_tbl(3).field        := p_name3;
            l_error_nvp_tbl(3).field_value  := p_value3;
        END IF;

        IF p_name4 IS NOT NULL THEN
            l_error_nvp_tbl(4).field        := p_name4;
            l_error_nvp_tbl(4).field_value  := p_value4;
        END IF;

        IF p_name5 IS NOT NULL THEN
            l_error_nvp_tbl(5).field        := p_name5;
            l_error_nvp_tbl(5).field_value  := p_value5;
        END IF;

        IF p_name6 IS NOT NULL THEN
            l_error_nvp_tbl(6).field        := p_name6;
            l_error_nvp_tbl(6).field_value  := p_value6;
        END IF;

        IF p_name7 IS NOT NULL THEN
            l_error_nvp_tbl(7).field        := p_name7;
            l_error_nvp_tbl(7).field_value  := p_value7;
        END IF;

        IF p_name8 IS NOT NULL THEN
            l_error_nvp_tbl(8).field        := p_name8;
            l_error_nvp_tbl(8).field_value  := p_value8;
        END IF;

        IF p_name9 IS NOT NULL THEN
            l_error_nvp_tbl(9).field        := p_name9;
            l_error_nvp_tbl(9).field_value  := p_value9;
        END IF;

        IF p_name10 IS NOT NULL THEN
            l_error_nvp_tbl(10).field        := p_name10;
            l_error_nvp_tbl(10).field_value  := p_value10;
        END IF;

--        IF p_name1 IS NOT NULL THEN l_error_nvp_tbl (p_name1) := p_value1; END IF;
--        IF p_name2 IS NOT NULL THEN l_error_nvp_tbl (p_name2) := p_value2; END IF;
--        IF p_name3 IS NOT NULL THEN l_error_nvp_tbl (p_name3) := p_value3; END IF;
--        IF p_name4 IS NOT NULL THEN l_error_nvp_tbl (p_name4) := p_value4; END IF;
--        IF p_name5 IS NOT NULL THEN l_error_nvp_tbl (p_name5) := p_value5; END IF;
--        IF p_name6 IS NOT NULL THEN l_error_nvp_tbl (p_name6) := p_value6; END IF;
--        IF p_name7 IS NOT NULL THEN l_error_nvp_tbl (p_name7) := p_value7; END IF;
--        IF p_name8 IS NOT NULL THEN l_error_nvp_tbl (p_name8) := p_value8; END IF;
--        IF p_name9 IS NOT NULL THEN l_error_nvp_tbl (p_name9) := p_value8; END IF;
--        IF p_name10 IS NOT NULL THEN l_error_nvp_tbl (p_name10) := p_value10; END IF;

        RETURN l_error_nvp_tbl;

    END init_error_nvp;


    -----------------------------------------------------------------------
    --.............................
    -- Can't really use the substitution code as it is now because
    -- it will only work for varchar parameters.... for numbers and dates etc
    -- we would need to conver the datatypes as appropriate and there is no way of telling
    -- if its a number of a date so for now the client has to build the autorun command manually with
    -- the parameters already embedded.
    FUNCTION set_autorun_command (  p_id_common_errors        IN  common_errors.id_common_errors%TYPE,
                                    p_autorun_command         IN  common_errors_autorun.autorun_command%TYPE    )
    RETURN common_errors_autorun.autorun_command%TYPE
    IS
        l_number_of_parameters  PLS_INTEGER;
        e_too_many_substit_parameter   EXCEPTION;
        e_missing_substit_parameter    EXCEPTION;

        l_autorun_command       VARCHAR2(2000);
        l_owner                 VARCHAR2(30);
        l_param_datatype        all_arguments.data_type%TYPE;
        l_param_value           common_errors.field_value%TYPE;
        -----------------------------------------------------------------------
        --...........
        PROCEDURE substitute_autorun_params (   p_parameter_sequence    IN  PLS_INTEGER,
                                                p_parameter_datatype    IN  VARCHAR2,
                                                p_parameter_value       IN  VARCHAR2,
                                                pio_autorun_command     IN OUT VARCHAR2)
        IS
            l_parameter_value  VARCHAR2(2000);
        BEGIN
            --dbms_output.put_line('START: substitute_autorun_params');

            IF p_parameter_datatype = 'VARCHAR2' THEN

                l_parameter_value := '''' || p_parameter_value || '''';

              --  dbms_output.put_line('VARCHAR2 value = ' || l_parameter_value);
            ELSIF p_parameter_datatype = 'NUMBER' THEN

                l_parameter_value := p_parameter_value;

                --dbms_output.put_line('NUMBER value = ' || l_parameter_value);
            ELSIF p_parameter_datatype = 'DATE' THEN

                l_parameter_value := 'TO_DATE(''' || p_parameter_value || ''', ''DD/MM/YYYY HH24:MI:SS'')';

                --dbms_output.put_line('DATE value = ' || l_parameter_value);
            END IF;

            --dbms_output.put_line('pio_autorun_command BEFORE substitution = ' || pio_autorun_command);

            pio_autorun_command := REPLACE( pio_autorun_command, ('&' || p_parameter_sequence), l_parameter_value);

            --dbms_output.put_line('pio_autorun_command AFTER substitution = ' || pio_autorun_command);
        END substitute_autorun_params;
        --=====================================================================
    BEGIN

        l_autorun_command := p_autorun_command;
        l_number_of_parameters := REGEXP_COUNT(p_autorun_command, '&');
        l_owner := UPPER(SUBSTR(l_autorun_command, 1, (INSTR(l_autorun_command, '.', 1)-1)));

        IF l_number_of_parameters = 0 THEN
             --dbms_output.put_line('No parameters');
             -- no substitution parameters are required so do nothing
             NULL;
        ELSIF l_number_of_parameters = 1 THEN
            --dbms_output.put_line('1 parameter');
            -- if only 1 parameter exists then no need to check oracle error_values table
            -- get datatype from all_arguments table for sequence id 1
            BEGIN
                SELECT  aa.data_type,
                        oe.field_value
                INTO    l_param_datatype,
                        l_param_value
                FROM    common_error_codes oec,
                        common_errors oe,
                        all_arguments aa
                WHERE   oec.id_common_error_codes = oe.id_common_error_codes
                AND     oec.package_name = aa.package_name
                AND     oec.procfunc = aa.object_name
                AND     aa.owner = l_owner
                AND     aa.sequence = 1
                AND     oe.id_common_errors = p_id_common_errors;

            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- if sql return no data then the auto_command contains too
                -- many substitution variables... more than above sql can find
                RAISE e_too_many_substit_parameter;

            WHEN TOO_MANY_ROWS THEN
                -- if sql return multiple rows of data then the auto_command contains too
                -- few substitution variables... and above sql can find more
                RAISE e_missing_substit_parameter;

            END;

            substitute_autorun_params ( p_parameter_sequence    => 1,
                                        p_parameter_datatype    => l_param_datatype,
                                        p_parameter_value       => l_param_value,
                                        pio_autorun_command     => l_autorun_command );

        ELSIF l_number_of_parameters > 1 THEN

            --dbms_output.put_line('Multiple parameters');
            FOR i IN 1 .. l_number_of_parameters
            LOOP

                BEGIN
                    SELECT
                            aa.data_type,
                            oev.field_value
                    INTO    l_param_datatype,
                            l_param_value
                    FROM    common_error_codes oec,
                            (   -- use analytic to get latest row from common_errors table
                                -- since we only want to join that to the rest of the tables
                                SELECT  id_common_errors,
                                        id_common_error_codes
                                FROM (
                                        SELECT ROW_NUMBER() OVER (PARTITION BY oes.id_common_error_codes ORDER BY oes.timestamp DESC) AS rn,
                                                oes.id_common_errors,
                                                oes.id_common_error_codes
                                        FROM common_errors oes )
                                WHERE rn = 1
                            ) oe,
                            common_error_values oev,
                            all_arguments aa
                    WHERE   oec.id_common_error_codes = oe.id_common_error_codes
                    AND     oe.id_common_errors = oev.id_common_errors
                    AND     oec.package_name = aa.package_name
                    AND     oec.procfunc = aa.object_name
                    AND     oev.id = aa.sequence
                    AND     aa.owner = l_owner
                    AND     aa.sequence = i
                    AND     oe.id_common_errors = p_id_common_errors;

                EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    -- if sql return no data then the auto_command contains too
                    -- many substitution variables... more than above sql can find
                    -- or other possibility is the joins aren't returning any data for this error id
                    RAISE e_too_many_substit_parameter;

                WHEN TOO_MANY_ROWS THEN
                    -- if sql return multiple rows of data then the auto_command contains too
                    -- few substitution variables... and above sql can find more
                    RAISE e_missing_substit_parameter;
                END;

                substitute_autorun_params ( p_parameter_sequence    => i,
                                            p_parameter_datatype    => l_param_datatype,
                                            p_parameter_value       => l_param_value,
                                            pio_autorun_command     => l_autorun_command );

            END LOOP;

        END IF;

        RETURN l_autorun_command;
--
--            -- number of substitution parameters is more than 0 but number of actual parameters found is 0
--            -- this is wrong it should be the same so raise an error
--            RAISE e_parameter_mismatch;
--        ELSIF l_number_of_parameters > 0 AND p_error_nvp_tbl.COUNT > 0 AND p_error_nvp_tbl.COUNT <> l_number_of_parameters
--        THEN
--            -- number of substitution parameters is more than 0 but number of actual parameters found is > 0
--            -- but the numbers aren't the asme
--            -- this is wrong it should be the same so raise an error
--            RAISE e_parameter_mismatch;
--        ELSE -- no more possibilities should exist so raise an error if they do
--            RAISE e_parameter_mismatch;
--        END IF;
--
--        --dbms_output.put_line('l_autorun_command = ' || l_autorun_command);

    EXCEPTION
    WHEN e_too_many_substit_parameter THEN
        log_error_alert (   p_package_name_in       => 'ERROR_UTILS',
                            p_procfunc_name_in      => 'SET_AUTORUN_COMMAND',
                            p_when_error_in         => 'e_too_many_substit_parameter',
                            p_oracle_sqlerrm_in     => SQLERRM,
                            p_error_message_in      => 'FATAL ERROR',
                            p_error_nvp_tbl         => error_utils.init_error_nvp( p_name1  => 'p_autorun_command',
                                                                                   p_value1 => p_autorun_command,
                                                                                   p_name2  => 'l_number_of_parameters',
                                                                                   p_value2 => l_number_of_parameters
                                                                                   ),
                            p_error_level           => 5 );

    WHEN e_missing_substit_parameter THEN
        log_error_alert (   p_package_name_in       => 'ERROR_UTILS',
                            p_procfunc_name_in      => 'SET_AUTORUN_COMMAND',
                            p_when_error_in         => 'e_missing_substit_parameter',
                            p_oracle_sqlerrm_in     => SQLERRM,
                            p_error_message_in      => 'FATAL ERROR',
                            p_error_nvp_tbl         => error_utils.init_error_nvp( p_name1  => 'p_autorun_command',
                                                                                   p_value1 => p_autorun_command,
                                                                                   p_name2  => 'l_number_of_parameters',
                                                                                   p_value2 => l_number_of_parameters
                                                                                   ),
                            p_error_level           => 5 );
    END set_autorun_command;


    PROCEDURE execute_error_autorun (   p_id_common_errors_autorun  IN  common_errors_autorun.id_common_errors_autorun%TYPE,
                                        p_id_common_error_codes     IN  common_errors_autorun.id_common_error_codes%TYPE,
                                        p_autorun_command           IN  common_errors_autorun.autorun_command%TYPE )
    IS
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE update_autorun_status ( p_status IN common_errors_autorun.status%TYPE)
        IS
        PRAGMA AUTONOMOUS_TRANSACTION;
            l_failure_count     PLS_INTEGER;
        BEGIN

            IF p_status = c_autorun_running THEN

                UPDATE common_errors_autorun oea
                SET oea.status = p_status,
                    oea.last_autorun_start_dts = SYSDATE,
                    oea.number_of_autoruns = (oea.number_of_autoruns + 1),
                    oea.modified_dts = SYSDATE
                WHERE oea.id_common_errors_autorun = p_id_common_errors_autorun;

                -- sleep to ensure that execution of procedure can't
                -- happen in same second as start date since the results query below
                -- checks for errors > then the start date
                DBMS_LOCK.SLEEP(1);
            ELSIF p_status = c_autorun_complete THEN

                -- check for results
                SELECT COUNT(*)
                INTO l_failure_count
                FROM common_errors oe, common_errors_autorun oea
                WHERE oe.id_common_errors_autorun = oea.id_common_errors_autorun
                AND oe.timestamp > oea.last_autorun_start_dts
                AND oea.id_common_errors_autorun = p_id_common_errors_autorun
                AND oe.autorun_execution = 1;


                IF l_failure_count > 0 THEN
                    -- autorun did produce additional errors so error is not resolved
                    -- update only autoruns currently running
                    UPDATE common_errors_autorun oea
                    SET oea.status = c_autorun_unresolved,
                        oea.modified_dts = SYSDATE
                    WHERE oea.id_common_errors_autorun = p_id_common_errors_autorun
                    AND status = c_autorun_running;
                ELSE
                    -- autorun did NOT produce additional errors so error IS resolved

                    UPDATE common_errors_autorun oea
                    SET oea.status = c_autorun_resolved,
                        oea.modified_dts = SYSDATE
                    WHERE oea.id_common_errors_autorun = p_id_common_errors_autorun
                    AND status = c_autorun_running;

                    -- if we are marking the error as resolved we need to update the
                    -- common_errors table to mark that error as resovled by setting autorun_execution flag to 2
                    UPDATE common_errors
                    SET autorun_execution = c_autorun_execution_resolved
                    WHERE id_common_errors_autorun = p_id_common_errors_autorun;

                END IF;

            ELSIF p_status = c_autorun_failed THEN

                UPDATE common_errors_autorun oea
                SET oea.status = p_status,
                    oea.modified_dts = SYSDATE
                WHERE oea.id_common_errors_autorun = p_id_common_errors_autorun;

            END IF;

            COMMIT;

        EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
        END update_autorun_status;
        --=====================================================================
    BEGIN
        g_id_ora_error_autorun := p_id_common_errors_autorun;

        update_autorun_status ( p_status => c_autorun_running);

        --dbms_output.put_line('execute p_autorun_command = ' || p_autorun_command );

        EXECUTE IMMEDIATE 'BEGIN ' || p_autorun_command || '; END;';

        update_autorun_status ( p_status => c_autorun_complete);
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        log_error_alert (   p_package_name_in       => 'ERROR_UTILS',
                            p_procfunc_name_in      => 'EXECUTE_ERROR_AUTORUN',
                            p_when_error_in         => 'OTHERS',
                            p_oracle_sqlerrm_in     => SQLERRM || CHR(13) || dbms_utility.format_error_backtrace,
                            p_error_message_in      => 'FATAL ERROR',
                            p_error_nvp_tbl         => error_utils.init_error_nvp(  p_name1  => 'p_id_common_errors_autorun',
                                                                                    p_value1 => p_id_common_errors_autorun,
                                                                                    p_name2  => 'p_id_common_error_codes',
                                                                                    p_value2 => p_id_common_error_codes,
                                                                                    p_name3  => 'p_autorun_command',
                                                                                    p_value3 => p_autorun_command
                                                                                   ),
                            p_error_level           => 5 );

        update_autorun_status ( p_status => c_autorun_failed );

    END execute_error_autorun;


    PROCEDURE generate_error_autorun ( p_max_num_of_autoruns    IN NUMBER DEFAULT c_max_number_autoruns)
    IS
        i                   PLS_INTEGER := 0;
--        l_autorun_command   common_errors_autorun.autorun_command%TYPE;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE update_error_autorun_cmd (    p_id_common_errors_autorun  IN common_errors_autorun.id_common_errors_autorun%TYPE,
                                                p_autorun_command           IN common_errors_autorun.autorun_command%TYPE)
        IS
            PRAGMA AUTONOMOUS_TRANSACTION;
        BEGIN

            UPDATE common_errors_autorun
            SET autorun_command_with_params = p_autorun_command
            WHERE id_common_errors_autorun = p_id_common_errors_autorun;

            COMMIT;
        END update_error_autorun_cmd;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE check_all_errors_status (   p_id_common_error_codes  IN common_errors_autorun.id_common_error_codes%TYPE )
        IS
            l_unresolved_failed_count   PLS_INTEGER;
        BEGIN
            -- count all unresolved or failed errors for this id oracle error code autorun
            SELECT COUNT(*)
            INTO l_unresolved_failed_count
            FROM common_errors_autorun
            WHERE id_common_error_codes = p_id_common_error_codes
            AND status IN (c_autorun_unresolved, c_autorun_failed);

            IF l_unresolved_failed_count = 0 THEN

                -- if no unresovled errors left then acknowledge the error
                acknowledge_email_alert ( p_id_common_error_codes => p_id_common_error_codes);

            END IF;

        END check_all_errors_status;
        --=====================================================================
        --=====================================================================
    BEGIN

        FOR cur IN (    SELECT  id_common_errors_autorun,
                                id_common_error_codes,
                                autorun_command,
                                autorun_command_with_params,
                                number_of_occurences,
                                status,
                                last_autorun_start_dts,
                                created_dts,
                                modified_dts
                        FROM common_errors_autorun
                        WHERE status = c_autorun_unresolved
                        ORDER BY created_dts, id_common_errors_autorun)
        LOOP
            i := i + 1;

            -- call the procedure to execute the autorun procedure
            -- this could be replaced by a call to dbms_scheduler to run it.
            execute_error_autorun ( p_id_common_errors_autorun  => cur.id_common_errors_autorun,
                                    p_id_common_error_codes     => cur.id_common_error_codes,
                                    p_autorun_command           => cur.autorun_command_with_params );

            g_id_ora_error_autorun := NULL;

            check_all_errors_status (   p_id_common_error_codes => cur.id_common_error_codes );

            -- create exit condition so that this generate autorun does not run too many
            -- procedures at once
            EXIT WHEN i = p_max_num_of_autoruns;

        END LOOP;

        COMMIT;

    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        log_error_alert (   p_package_name_in       => 'ERROR_UTILS',
                            p_procfunc_name_in      => 'GENERATE_ERROR_AUTORUN',
                            p_when_error_in         => 'OTHERS',
                            p_oracle_sqlerrm_in     => SQLERRM,
                            p_error_message_in      => 'FATAL ERROR',
                            p_error_nvp_tbl         => error_utils.init_error_nvp,
                            p_error_level           => 5 );
    END generate_error_autorun;
    /******************************************************************************
    NAME: send_email_alert

    PURPOSE: Called by batch job eg every 1 minute . Checks the email_alerts table
              to see if any emails need to be sent

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE send_email_alert
    IS
        tbl_emailalerts             tab_emailpayload := tab_emailpayload ();
        l_new_error_alert_flag      BOOLEAN := FALSE;
        l_error_alert_rt            common_error_alert%ROWTYPE;

        TYPE tbl_numbers IS TABLE OF NUMBER;
        tbl_id_error_alert          tbl_numbers := tbl_numbers();


        g_procfunc_name             VARCHAR2 (30) := 'SEND_EMAIL_ALERT';
        l_error_code_out            NUMBER;
        l_error_message_out         VARCHAR2 (4000);
        l_error_id_resolved         BOOLEAN;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE add_to_email_payload (    p_group_id              IN  NUMBER,
                                            p_messagetype           IN  VARCHAR2 DEFAULT c_messageTypeAlert,
                                            p_attribute_name        IN  VARCHAR2,
                                            p_attribute_value       IN  VARCHAR2,
                                            p_column_order in number )

        IS

        BEGIN
            -- add attribute to payload
            -- limit attributes to 100 char since that is the email payload limit
            tbl_emailalerts.EXTEND;
            tbl_emailalerts (tbl_emailalerts.LAST) := obj_emailpayload (   p_group_id,
                                                                           p_messagetype, --c_messageTypeAlert,
                                                                           SUBSTR(p_attribute_name, 1, 100),
                                                                           SUBSTR(p_attribute_value, 1, 100),
                                                                           p_column_order);
        END add_to_email_payload;

        -----------------------------------------------------------------------
        --.............................
        PROCEDURE add_all_attribs_to_payload (  p_group_id              IN  NUMBER,
                                                p_id_common_error_codes IN  common_errors.id_common_error_codes%TYPE,
                                                p_id_error_alert        IN  common_error_alert.id_common_error_alert%TYPE,
                                                p_number_of_occurences  IN  common_error_alert.number_of_occurences%TYPE,
                                                p_package_name          IN  common_error_codes.package_name%TYPE,
                                                p_procedure_name        IN  common_error_codes.procfunc%TYPE,
                                                p_exception             IN  common_error_codes.when_error%TYPE,
                                                p_error_message         IN  common_errors.oracle_sqlerrm%TYPE   )

        IS
            l_id_common_errors  common_errors.id_common_errors%TYPE;
            i PLS_INTEGER := 5;
        BEGIN
            -- in our case we are using id_common_errors as the group id in order to group the errors together in one email row
            -- so we also need to report this id_common_errors as an attribute so we can make use of the existing pararmeter
            l_id_common_errors := p_group_id;

            -- we use 4 attributes for the email so add each one in turn and use the id_common_errors
            -- as the groupid so that we know that all attributes belong to same error and will appear as 1 single row in the errors email

            -- add attributes using the goup id to show its all part of the same error instance
            -- first add the error values from the common_error_values table
            FOR cur IN (    SELECT  field,
                                    field_value
                            FROM common_errors
                            WHERE id_common_errors = l_id_common_errors
                            AND (   field IS NOT NULL
                                OR  field_value IS NOT NULL)
                            UNION ALL
                            SELECT  field,
                                    field_value
                            FROM    common_error_values
                            WHERE id_common_errors = l_id_common_errors )
            LOOP
                add_to_email_payload (  p_group_id              => p_group_id,
                                        p_messagetype           => p_id_common_error_codes,
                                        p_attribute_name        => SUBSTR(cur.field, 1, 100),
                                        p_attribute_value       => SUBSTR(cur.field_value, 1, 100),
                                        p_column_order          => i );

                i := i + 1;
            END LOOP;

            -- now add the rest of the attributes
            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'ID_common_errorS',
                                    p_attribute_value       => l_id_common_errors,
                                    p_column_order          => 99 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'ID_common_error_CODES',
                                    p_attribute_value       => p_id_common_error_codes ,
                                    p_column_order          => 90 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'id_common_error_alert',
                                    p_attribute_value       => p_id_error_alert ,
                                    p_column_order          => 80 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'NUMBER OF OCCURENCES',
                                    p_attribute_value       => p_number_of_occurences ,
                                    p_column_order          => 70 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'ERROR MESSAGE',
                                    p_attribute_value       => p_error_message ,
                                    p_column_order          => 4 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'EXCEPTION BLOCK',
                                    p_attribute_value       => p_exception ,
                                    p_column_order          => 3 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'PROCEDURE NAME',
                                    p_attribute_value       => p_procedure_name ,
                                    p_column_order          => 2 );

            add_to_email_payload (  p_group_id              => p_group_id,
                                    p_messagetype           => p_id_common_error_codes,
                                    p_attribute_name        => 'PACKAGE NAME',
                                    p_attribute_value       => p_package_name ,
                                    p_column_order          => 1 );


        END add_all_attribs_to_payload;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE add_id_error_alert (  p_id_error_alert                IN  common_error_alert.id_common_error_alert%TYPE   )

        IS
        BEGIN
            tbl_id_error_alert.EXTEND;
            tbl_id_error_alert(tbl_id_error_alert.LAST) := p_id_error_alert;
        END add_id_error_alert;
        -----------------------------------------------------------------------
        -- If an existing alert has NOT reoccured since the last email
        -- but the threshold has passed so the email send flag is true then
        -- we need to send another email however there is no row in the table with
        -- a null EMAIL_SENT_DTS so we need to add an additional row in common_error_alert.
        -- Copy the row for the last_email_Sent_dts which is indicated by the fact that
        -- EMAIL_SENT_DTS is not null
        --.............................
        PROCEDURE check_to_resend_emails (  p_error_alert_rt   IN OUT  common_error_alert%ROWTYPE,
                                            po_return             OUT  BOOLEAN)
        IS
        BEGIN

            -- check if the email_sent_Dts is not null since this is the lastest
            -- unacknowledged row if it is not null we need to create a new row for
            -- a new email for the alert to be resent
            IF p_error_alert_rt.email_sent_dts IS NOT NULL THEN

                -- copy entire row apart from the id_common_error_alert and the email_sent_dts which we set to null
                -- also set number of occurences to 0 so that we know it was a copy
                p_error_alert_rt.id_common_error_alert := seq_id_common_error_alert.NEXTVAL;
                p_error_alert_rt.email_sent_dts := NULL;
                p_error_alert_rt.number_of_occurences := 0;

                -- now insert row into table
                INSERT INTO common_error_alert
                VALUES p_error_alert_rt;

                po_return := TRUE;
            ELSE
                -- if the email_sent_dts is null then this row would trigger an email and be updated
                -- so return false
                po_return := FALSE;
            END IF;

        END check_to_resend_emails;
        -----------------------------------------------------------------------
        --.............................
        PROCEDURE update_error_alert

        IS
        BEGIN
            -- update errors with email id
            FORALL i IN tbl_id_error_alert.FIRST .. tbl_id_error_alert.LAST
                UPDATE common_error_alert
                SET email_sent_dts = SYSDATE
                WHERE id_common_error_alert = tbl_id_error_alert(i)
                AND  email_sent_dts IS NULL;
        END update_error_alert;
        -----------------------------------------------------------------------
        -----------------------------------------------------------------------

    BEGIN

--        -- initalise trace
--        -- pkg_app_manager.p_trace_start(   p_client_id          => NULL,
--                                         p_package_name       => 'ERROR_UTILS',
--                                         p_procedure_name     => 'SEND_EMAIL_ALERT');

        -- select the first unacknowledged email sent in each group of id oracle error codes for those where an email should be sent
        -- only select the first 10 errors of each type so that the email isn't overloaded
        FOR cur IN (    SELECT  ---------------------------
                                -- All common_error_alert columns
                                id_common_error_alert,
                                id_common_error_codes,
                                first_id_common_errors ,
                                first_queued_dts,
                                last_queued_dts,
                                number_of_occurences,
                                email_sent_dts,
                                alert_acknowledged_dts,
                                ---------------------------
                                last_email_sent_dts,
                                package_name,
                                procedure_name,
                                exception_name,
                                oracle_sqlerrm,
                                first_current_common_error,
                                send_email_flag
                        FROM (
                                SELECT  --------------------------------------------------------------------
                                        (CASE WHEN (last_email_sent_dts IS NULL OR
                                                   ((SYSDATE - last_email_sent_dts) * 24 >= email_alert_threshold_hours)) THEN
                                            1
                                         ELSE
                                            0
                                         END) as send_email_flag,
                                        --------------------------------------------------------------------
                                        -- All common_error_alert columns
                                        id_common_error_alert,
                                        id_common_error_codes,
                                        first_id_common_errors ,
                                        first_queued_dts,
                                        last_queued_dts,
                                        number_of_occurences,
                                        email_sent_dts,
                                        alert_acknowledged_dts,
                                        ---------------------------
                                        package_name,
                                        procedure_name,
                                        exception_name,
                                        oracle_sqlerrm,
                                        last_email_sent_dts,
                                        email_alert_threshold_hours,
                                        first_current_common_error
                                FROM (
                                        SELECT  ---------------------------
                                                -- All common_error_alert columns
                                                e.id_common_error_alert,
                                                e.id_common_error_codes,
                                                e.first_id_common_errors ,
                                                e.first_queued_dts,
                                                e.last_queued_dts,
                                                e.number_of_occurences,
                                                e.email_sent_dts,
                                                e.alert_acknowledged_dts,
                                                ---------------------------
                                                oec.package_name,
                                                oec.procfunc AS procedure_name,
                                                oec.when_error AS exception_name,
                                                oec.email_alert_threshold_hours,
                                                MAX(email_sent_dts) OVER (PARTITION BY e.id_common_error_codes ) AS last_email_sent_dts,
                                                ROW_NUMBER() OVER (PARTITION BY e.id_common_error_codes ORDER BY e.email_sent_dts DESC NULLS FIRST) AS rn,
                                                oe.oracle_sqlerrm,
                                                MIN(oe.timestamp) OVER (PARTITION BY e.id_common_error_codes) AS first_current_common_error,
                                                ------------------------------------------------------------
                                                (CASE   -- check error level: for the lower values a delay is used before
                                                        -- sending any email alert to give the error a chance to recover
                                                WHEN oec.send_alert_email IS NOT NULL THEN oec.send_alert_email
                                                WHEN oec.error_level = c_error_level_1
                                                    AND ROUND((sysdate - CAST(oe.timestamp AS DATE) ) * 24 * 60) > c_error_threshold_mins_lvl1 THEN c_send_email_alert
                                                WHEN oec.error_level = c_error_level_2
                                                    AND ROUND((sysdate - CAST(oe.timestamp AS DATE) ) * 24 * 60) > c_error_threshold_mins_lvl2 THEN c_send_email_alert
                                                WHEN oec.error_level = c_error_level_3
                                                    AND ROUND((sysdate - CAST(oe.timestamp AS DATE) ) * 24 * 60) > c_error_threshold_mins_lvl3 THEN c_send_email_alert
                                                WHEN oec.error_level = c_error_level_4
                                                    AND ROUND((sysdate - CAST(oe.timestamp AS DATE) ) * 24 * 60) > c_error_threshold_mins_lvl4 THEN c_send_email_alert
                                                WHEN oec.error_level >= c_error_level_5 THEN c_send_email_alert
                                                ELSE
                                                     c_dont_send_email_alert
                                                END) AS send_email_alert
                                                ------------------------------------------------------------
                                        FROM    common_error_alert e,
                                                common_error_codes oec,
                                                common_errors oe
                                        WHERE   e.id_common_error_codes = oec.id_common_error_codes
                                        AND     e.first_id_common_errors = oe.id_common_errors
                                        AND     e.alert_acknowledged_dts IS NULL
                                        AND     (oec.error_level >= c_error_level_1 OR oec.send_alert_email = c_send_email_alert)
                                        )
                                WHERE rn = 1
                                AND send_email_alert = c_send_email_alert
                             )
                        WHERE send_email_flag = 1       )
        LOOP
            l_error_id_resolved := FALSE;
            -- threshold already checked and only rows where an email needs to be sent are in this cursor
--                -- pkg_app_manager.p_trace( p_name => 'id_common_error_alert', p_text => cur.id_common_error_alert);

            IF NOT l_error_id_resolved THEN
                -- populate local rowtype used for sending to subproc
                l_error_alert_rt.id_common_error_alert             := cur.id_common_error_alert;
                l_error_alert_rt.id_common_error_codes      := cur.id_common_error_codes;
                l_error_alert_rt.first_id_common_errors     := cur.first_id_common_errors;
                l_error_alert_rt.first_queued_dts           := cur.first_queued_dts;
                l_error_alert_rt.last_queued_dts            := cur.last_queued_dts;
                l_error_alert_rt.number_of_occurences       := cur.number_of_occurences;
                l_error_alert_rt.email_sent_dts             := cur.email_sent_dts;
                l_error_alert_rt.alert_acknowledged_dts     := cur.alert_acknowledged_dts;

                check_to_resend_emails ( p_error_alert_rt => l_error_alert_rt,
                                         po_return        => l_new_error_alert_flag );

                -- if we are resending the email then use the newly inserted row id_common_error_alert
                -- otherwise send the email for this current row
                IF l_new_error_alert_flag THEN

                    -- for this error instance add all attributes to payload
                    add_all_attribs_to_payload (p_group_id              => cur.first_id_common_errors,    -- send id_common_errors as group id
                                                p_id_common_error_codes => cur.id_common_error_codes,
                                                p_id_error_alert        => l_error_alert_rt.id_common_error_alert,
                                                p_number_of_occurences  => l_error_alert_rt.number_of_occurences,
                                                p_package_name          => cur.package_name,
                                                p_procedure_name        => cur.procedure_name,
                                                p_exception             => cur.exception_name,
                                                p_error_message         => cur.oracle_sqlerrm);

                    -- collect the primary key ids into collection so after the loop we can update the errors with the email id
                    -- do this for the newly created row
                    add_id_error_alert( p_id_error_alert    => l_error_alert_rt.id_common_error_alert);
                ELSE

                    -- for this error instance add all attributes to payload
                    add_all_attribs_to_payload (p_group_id              => cur.first_id_common_errors,    -- send id_common_errors as group id
                                                p_id_common_error_codes => cur.id_common_error_codes,
                                                p_id_error_alert        => cur.id_common_error_alert,
                                                p_number_of_occurences  => cur.number_of_occurences,
                                                p_package_name          => cur.package_name,
                                                p_procedure_name        => cur.procedure_name,
                                                p_exception             => cur.exception_name,
                                                p_error_message         => cur.oracle_sqlerrm);

                    -- collect the primary key ids into collection so after the loop we can update the errors with the email id
                    add_id_error_alert( p_id_error_alert    => cur.id_common_error_alert);
                END IF;

            END IF;

        END LOOP;

        email_utils.compileandsend (tbl_emailalerts, c_emailsubject);

        update_error_alert;
        COMMIT;

        ---- pkg_app_manager.p_trace_end;
    EXCEPTION
    WHEN OTHERS THEN
         error_utils.log_error( p_idsblocation_in     => 'UK',
                                p_package_name_in     => g_package_name,
                                p_procfunc_name_in    => g_procfunc_name,
                                p_when_error_in       => 'others',
                                p_oracle_sqlerrm_in   => SQLERRM || CHR(13) || dbms_utility.format_error_backtrace,
                                p_field_in            => NULL,
                                p_value_in            => NULL,
                                p_error_code_out      => l_error_code_out,
                                p_error_message_out   => l_error_message_out );




    END send_email_alert;

    /******************************************************************************
    NAME: update_autorun_status

    PURPOSE: update the status of any autoruns so that they dont get picked up after
            being acknowledged manually

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE update_autorun_status ( p_ora_err_codes_array   IN    dbms_utility.number_array )
    IS
    BEGIN

        FORALL i IN 1.. p_ora_err_codes_array.COUNT
            UPDATE common_errors_autorun
            SET status = c_autorun_resolved,
                modified_dts = SYSDATE
            WHERE id_common_error_codes = p_ora_err_codes_array(i);

    END update_autorun_status;
    /******************************************************************************
    NAME: acknowledge_email_alert

    PURPOSE: Once email has been received use this procedure to acknowledge it so that
             multiple emails are not sent.  If error is not fixed though another email will get sent eventually

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE acknowledge_email_alert ( p_id_common_error_codes       IN  common_error_alert.id_common_error_codes%TYPE )
    IS
        l_ora_err_codes_array   dbms_utility.number_array;
    BEGIN
        -- set date in table to acknowledge alert
        UPDATE common_error_alert
        SET alert_acknowledged_dts = SYSDATE
        WHERE id_common_error_codes = p_id_common_error_codes
        AND alert_acknowledged_dts IS NULL
        RETURNING id_common_error_codes BULK COLLECT INTO l_ora_err_codes_array;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR( -20001, 'The error code does not exists OR no errors');
        END IF;

        update_autorun_status ( p_ora_err_codes_array => l_ora_err_codes_array );

        COMMIT;
    END acknowledge_email_alert;

    /******************************************************************************
    NAME: acknowledge_email_alert

    PURPOSE: Once email has been received use this procedure to acknowledge  ALL the errors from that email
             in case you have fixed all errors and don't want to run the procedure for invididual errors
             Note though that you must pass in the last email alert id from the very latest email alert in order
             for this procedure to work.

             ***    Other errors may have occured since the last email was sent so they will not be acknowledged and you will
                    have to acknowledge them using their id_common_error_code OR wait for the next email to be sent or use the
                    acknowledge all emails procedure

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE acknowledge_last_email_alert
    IS
        l_ora_err_codes_array   dbms_utility.number_array;
    BEGIN
        -- set date in table to acknowledge alert
        UPDATE common_error_alert
        SET alert_acknowledged_dts = SYSDATE
        WHERE email_sent_dts = (SELECT MAX(email_sent_dts) FROM common_error_alert)
        AND alert_acknowledged_dts IS NULL
        RETURNING id_common_error_codes BULK COLLECT INTO l_ora_err_codes_array;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR( -20001, 'No emails were acknowledged');
        END IF;

        update_autorun_status ( p_ora_err_codes_array => l_ora_err_codes_array );

        COMMIT;
    END acknowledge_last_email_alert;

    /******************************************************************************
    NAME: acknowledge_all_email_alert

    PURPOSE: Use this procedure to acknowledge ALL email alerts regardless of status.
              Should be used in the rare case when you just want to reset the alert table
              if eg you have too many errors to acknowledge individually

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE acknowledge_all_email_alert
    IS
        l_ora_err_codes_array   dbms_utility.number_array;
    BEGIN
        -- set date in table to acknowledge alert
        UPDATE common_error_alert
        SET alert_acknowledged_dts = SYSDATE
        WHERE alert_acknowledged_dts IS NULL
        RETURNING id_common_error_codes BULK COLLECT INTO l_ora_err_codes_array;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR( -20001, 'No emails were acknowledged');
        END IF;

        update_autorun_status ( p_ora_err_codes_array => l_ora_err_codes_array );

        COMMIT;
    END acknowledge_all_email_alert;

    /******************************************************************************
    NAME: configure_error_alert

    PURPOSE: Use this procedure to configue an error alert ready for sending emails

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE configure_error_alert (   p_id_common_error_codes       IN  common_error_alert.id_common_error_codes%TYPE,
                                        p_error_level                 IN  common_error_codes.error_level%TYPE DEFAULT NULL,
                                        p_send_alert_email            IN  common_error_codes.send_alert_email%TYPE DEFAULT NULL)
    IS
    BEGIN
        -- set level in error codes table
        UPDATE common_error_codes e
        SET e.error_level = NVL(p_error_level, e.error_level),
            e.send_alert_email = NVL(p_send_alert_email, e.send_alert_email)
        WHERE id_common_error_codes = p_id_common_error_codes;


        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR( -20001, 'No error exists for this id_common_error_codes: ' || p_id_common_error_codes);
        END IF;

        COMMIT;
    END configure_error_alert;
END error_utils;
/
