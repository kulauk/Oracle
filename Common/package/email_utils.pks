CREATE OR REPLACE PACKAGE common.email_utils
AS

    /******************************************************************************
      NAME:        common.email_utils
      PURPOSE:    Provides procedures used for sending email alerts for
                 the ERROR_UTILS package

      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        01/03/2013  Rana Sastry      First Draft
      1.1        08/08/2013  Duncan Lucas     Refactoring
    ******************************************************************************/
    --=============================================================================
    --
    --      Declaration section
    --
    -- (Place your private package level variables and declarations here )
    --=============================================================================



    --=============================================================================
    --
    --      PUBLIC PROCEDURES AND FUNCTIONS
    --
    --=============================================================================

    /******************************************************************************
    NAME: send_email

    PURPOSE:

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             01/03/2013  Rama Sastry    First Draft
    ******************************************************************************/

    PROCEDURE send_email (  p_message IN VARCHAR2, p_subject IN VARCHAR2);

    /******************************************************************************
    NAME: compileandsend

    PURPOSE:

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             01/03/2013  Rama Sastry    First Draft
    ******************************************************************************/
   PROCEDURE compileandsend (   p_tabemailpayload_in    IN tab_emailpayload,
                                p_email_subject_in      IN VARCHAR2 );


   PROCEDURE testMail;


   PROCEDURE send_email_html (p_recipient_email_address         IN VARCHAR2,
                              p_sender_email_address            IN VARCHAR2,
                              p_email_subject                   IN VARCHAR2,
                              p_text                            IN VARCHAR2 DEFAULT NULL,
                              p_email_body                      IN CLOB DEFAULT NULL,
                              p_smtp_hostname                   IN VARCHAR2 DEFAULT 'localhost',
                              p_smtp_portnum                    IN VARCHAR2 DEFAULT '25');

    PROCEDURE send_email_attachment (   p_to          IN VARCHAR2,
                                        p_from        IN VARCHAR2,
                                        p_subject     IN VARCHAR2,
                                        p_text_msg    IN VARCHAR2 DEFAULT NULL,
                                        p_attach_name IN VARCHAR2 DEFAULT NULL,
                                        p_attach_mime IN VARCHAR2 DEFAULT NULL,
                                        p_attach_clob IN CLOB DEFAULT NULL,
                                        p_smtp_host   IN VARCHAR2 DEFAULT 'localhost',
                                        p_smtp_port   IN NUMBER DEFAULT 25);
END email_utils;
/
