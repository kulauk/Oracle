CREATE OR REPLACE PACKAGE common.error_utils
AS
    TYPE error_nvp_rec IS RECORD (field VARCHAR2(1000), field_value VARCHAR2(1000));
    TYPE error_nvp_tbl IS TABLE OF error_nvp_rec INDEX BY PLS_INTEGER;

    -- set the max number of autoruns for each execution of the autorun job
    c_max_number_autoruns   CONSTANT PLS_INTEGER := 10;


--    TYPE error_nvp_tbl IS TABLE OF VARCHAR2(1000) INDEX BY VARCHAR2(1000);

   FUNCTION get_success_message (p_idsblocation_in VARCHAR2)
      RETURN common_error_codes.error_message%TYPE;


   ---------------------------------------------------------------------------
   -- Original log_error procs and functions
   --SD Overloaded version bugz 2726
   PROCEDURE log_error (p_idsblocation_in     IN     VARCHAR2,
                        p_package_name_in     IN     VARCHAR2,
                        p_procfunc_name_in    IN     VARCHAR2,
                        p_when_error_in       IN     VARCHAR2,
                        p_oracle_sqlerrm_in   IN     VARCHAR2,
                        p_field_in            IN     VARCHAR2,
                        p_value_in            IN     VARCHAR2,
                        p_error_code_out         OUT NUMBER,
                        p_error_message_out      OUT VARCHAR2);

   FUNCTION log_error (p_package_name_in        IN     VARCHAR2,
                       p_procfunc_name_in       IN     VARCHAR2,
                       p_when_error_in          IN     VARCHAR2,
                       p_oracle_sqlerrm_in      IN     VARCHAR2,
                       p_error_message_in_out   IN OUT VARCHAR2,
                       p_field_in               IN     VARCHAR2,
                       p_value_in               IN     VARCHAR2 )
      RETURN NUMBER;
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    -- New log_error function and procedure that can accept a collection of name value pairs
    -- so you can specify multiple field values
   FUNCTION log_error_alert (  p_package_name_in        IN     VARCHAR2,
                               p_procfunc_name_in       IN     VARCHAR2,
                               p_when_error_in          IN     VARCHAR2,
                               p_oracle_sqlerrm_in      IN     VARCHAR2,
                               p_error_message_in_out   IN OUT VARCHAR2,
                               p_error_nvp_tbl          IN     error_nvp_tbl,
                               p_error_level            IN     NUMBER DEFAULT NULL,
                               p_autorun_command        IN     VARCHAR2 DEFAULT NULL)
      RETURN NUMBER;

   PROCEDURE log_error_alert  ( p_package_name_in        IN     VARCHAR2,
                                p_procfunc_name_in       IN     VARCHAR2,
                                p_when_error_in          IN     VARCHAR2,
                                p_oracle_sqlerrm_in      IN     VARCHAR2,
                                p_error_message_in       IN     VARCHAR2,
                                p_error_nvp_tbl          IN     error_nvp_tbl,
                                p_error_level            IN     NUMBER DEFAULT NULL,
                                p_autorun_command        IN     VARCHAR2 DEFAULT NULL);

    ---------------------------------------------------------------------------
    -- function is used to initialise name value pairs collection for use with function and procedure above
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
    RETURN error_nvp_tbl;

    FUNCTION format_errmsg ( p_error_message    IN  VARCHAR2,
                             p_error_nvp_tbl    IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp())
    RETURN VARCHAR2;

    PROCEDURE log_and_raise (   p_package_name      IN  VARCHAR2,
                                p_procedure_name    IN  VARCHAR2,
                                p_when_error        IN  VARCHAR2,
                                p_error_code        IN  NUMBER DEFAULT SQLCODE,
                                p_error_message     IN  VARCHAR2 DEFAULT SQLERRM,
                                p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                                p_error_level       IN  PLS_INTEGER DEFAULT 0,
                                p_trace_level       IN  PLS_INTEGER DEFAULT 1 );

    PROCEDURE log_no_raise (    p_package_name      IN  VARCHAR2,
                                p_procedure_name    IN  VARCHAR2,
                                p_when_error        IN  VARCHAR2,
                                p_error_message     IN  VARCHAR2 DEFAULT SQLERRM,
                                p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                                p_error_level       IN  PLS_INTEGER DEFAULT 0,
                                p_trace_level       IN  PLS_INTEGER DEFAULT 1 );

    PROCEDURE raise_error ( p_error_code        IN  NUMBER,
                            p_error_message     IN  VARCHAR2,
                            p_error_value       IN  VARCHAR2,
                            p_trace_level       IN  PLS_INTEGER DEFAULT 1 );

    PROCEDURE raise_error ( p_error_code        IN  NUMBER,
                            p_error_message     IN  VARCHAR2,
                            p_error_nvp_tbl     IN  error_nvp_tbl DEFAULT error_utils.init_error_nvp(),
                            p_trace_level       IN  PLS_INTEGER DEFAULT 1 );

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    FUNCTION set_autorun_command (  p_id_common_errors        IN  common_errors.id_common_errors%TYPE,
                                    p_autorun_command         IN  common_errors_autorun.autorun_command%TYPE    )
    RETURN common_errors_autorun.autorun_command%TYPE;

    PROCEDURE execute_error_autorun (   p_id_common_errors_autorun  IN  common_errors_autorun.id_common_errors_autorun%TYPE,
                                        p_id_common_error_codes     IN  common_errors_autorun.id_common_error_codes%TYPE,
                                        p_autorun_command           IN  common_errors_autorun.autorun_command%TYPE );

    PROCEDURE generate_error_autorun ( p_max_num_of_autoruns    IN NUMBER DEFAULT c_max_number_autoruns);
    /******************************************************************************
    NAME: send_email_alert

    PURPOSE: Called by batch job eg every 1 minute . Checks the email_alerts table
              to see if any emails need to be sent

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE send_email_alert;

    /******************************************************************************
    NAME: acknowledge_email_alert

    PURPOSE: Once email has been received use this procedure to acknowledge it so that
             multiple emails are not sent.  If error is not fixed though another email will get sent eventually

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE acknowledge_email_alert ( p_id_common_error_codes       IN  common_error_alert.id_common_error_codes%TYPE );


    /******************************************************************************
    NAME: acknowledge_email_alert

    PURPOSE: Once email has been received use this procedure to acknowledge  ALL the errors from that email
             in case you have fixed all errors and don't want to run the procedure for invididual errors
             Note though that you must pass in the last email alert id from the very latest email alert in order
             for this procedure to work

             ***    Other errors may have occured since the last email was sent so they will not be acknowledged and you will
                    have to acknowledge them using their id_common_error_code OR wait for the next email to be sent or use the
                    acknowledge all emails procedure

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             15/02/2013  Duncan Lucas   First Draft
    ******************************************************************************/
    PROCEDURE acknowledge_last_email_alert;

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
    PROCEDURE acknowledge_all_email_alert;

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
                                        p_send_alert_email            IN  common_error_codes.send_alert_email%TYPE DEFAULT NULL);

END error_utils;
/
