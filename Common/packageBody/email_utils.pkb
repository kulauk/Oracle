CREATE OR REPLACE PACKAGE BODY common.email_utils
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
    --      PRIVATE PROCEDURES AND FUNCTIONS
    --
    --=============================================================================
    --==========================================================================
    -- Function to return the package name (to avoid storing state in the package body)
    -- .......
    FUNCTION get_package_name
    RETURN VARCHAR2
    IS
    BEGIN
        RETURN 'EMAIL_UTILS';
    END get_package_name; 

    --=============================================================================
    -- Initialise system preferences variables
    --..........................
    FUNCTION f_get_email_address
    RETURN system_config.data%TYPE
    IS
         c_sysprefs_section_alert     CONSTANT VARCHAR2 (22) := 'ALERT MAIL';
         c_sysprefs_name_alert        CONSTANT VARCHAR2 (22) := 'BET FEED'; 
         l_default_value              VARCHAR2(30) := 'MISDBA@sportingindex.com';      
    BEGIN
        RETURN common.utils.get_system_config ( p_section         => c_sysprefs_section_alert, 
                                                p_name            => c_sysprefs_name_alert, 
                                                p_default_value   => l_default_value);    
    END f_get_email_address;
    --=============================================================================
    FUNCTION filter_email_address ( p_email_address  IN VARCHAR2)
    RETURN VARCHAR2
    IS
        l_return   VARCHAR2(500);
        l_error_level   PLS_INTEGER := 0;
        l_errormsg_out  VARCHAR2(1000);
        e_illegal_domain    EXCEPTION;

        c_production_db_name        CONSTANT VARCHAR2(3) := 'MIS';
        c_domain_sporting_solutions CONSTANT VARCHAR2 (21) := 'SPORTINGSOLUTIONS.COM';
        c_domain_sporting_index     CONSTANT VARCHAR2 (17) := 'SPORTINGINDEX.COM';
        c_spin_identifier           CONSTANT VARCHAR2 (4) := 'SPIN';
        
        l_procfunc_name    VARCHAR2(30) := 'FILTER_EMAIL_ADDRESS';
    BEGIN
        

        IF UPPER((SYS_CONTEXT ('USERENV', 'DB_NAME'))) = c_production_db_name THEN
            -- if the db IS the production database then don't apply filter
            l_return := p_email_address;

        ELSE
            -- if the email address contains either sporting index or solutions domain name then
            -- in a non production database that is ok we can send the email
            -- if its not got these domains then we dont want to send it ever from a non production database
            IF  INSTR( UPPER(p_email_address), c_domain_sporting_solutions) > 0 OR
                INSTR( UPPER(p_email_address), c_domain_sporting_index) > 0 THEN

                -- also ensure that the email address is never sent to the global spin address from non prod db
                l_return := REPLACE( UPPER(p_email_address), c_spin_identifier, '');
                l_return := p_email_address;
            ELSE
                -- email address does not contain the valid domains for non prod db then null the email address
                RAISE e_illegal_domain;
            END IF;

        END IF;

        RETURN l_return;
--    EXCEPTION
--    WHEN e_illegal_domain THEN
--        ROLLBACK;
--        common.error_utils.log_error_alert (get_package_name,
--                                            l_procfunc_name,
--                                            'e_illegal_domain',
--                                            SQLERRM,
--                                            l_errormsg_out,
--                                            error_utils.init_error_nvp (p_name1 => 'p_email_address', p_value1 => p_email_address),
--                                            l_error_level);
--
--        -- just log the error and return a null so that no email is sent
--        -- error is not required to alert just to log
--        RETURN NULL;
    END filter_email_address;
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

    PROCEDURE send_email (  p_message       IN VARCHAR2,
                            p_subject       IN VARCHAR2)
    IS
        l_mailaddress   system_config.data%TYPE;
        l_procfunc_name VARCHAR2(30) := 'SEND_EMAIL';
    BEGIN
        -----------------------------------------------------------------------
        


        pkg_app_manager.p_trace (p_name => 'START:', p_text => 'SEND_EMAIL');

        IF (p_message IS NOT NULL)
        THEN
            -- fetch email send address
            l_mailaddress := f_get_email_address;

            -- filter email addresses depending on db environment
            l_mailaddress := filter_email_address ( p_email_address => l_mailaddress);

            IF l_mailaddress IS NOT NULL THEN
                -- use email send address for from and to address.. spoofs the mail box
                UTL_MAIL.send ( sender       => l_mailaddress,
                                recipients   => l_mailaddress,
                                mime_type    => 'text/html; charset=us-ascii',
                                subject      => UPPER ( (SYS_CONTEXT ('USERENV', 'DB_NAME'))) || ': ' || p_subject,
                                MESSAGE      => SUBSTR(p_message, 1, 32000));

                pkg_app_manager.p_trace (p_name => 'Email Sent');
            ELSE
                pkg_app_manager.p_trace (p_name => 'Email address is null...NO Email Sent!');
            END IF;
        ELSE
            pkg_app_manager.p_trace (p_name => 'Message is null...NO Email Sent!');
        END IF;

        COMMIT;

      -------------------------------------------------------------------------
    END send_email;

    /******************************************************************************
    NAME: compileandsend

    PURPOSE:

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             01/03/2013  Rama Sastry    First Draft
    ******************************************************************************/
    PROCEDURE compileandsend (   p_tabemailpayload_in    IN tab_emailpayload,
                                p_email_subject_in      IN VARCHAR2 )
    AS
        TYPE rowrec IS TABLE OF VARCHAR2 (500);
        l_procfunc_name           VARCHAR2(30) := 'COMPILEANDSEND';

        l_messagebody             VARCHAR2 (5000) := NULL;
        l_messageheader           VARCHAR2 (500) := NULL;
        l_groupidold              NUMBER := NULL;
        l_messagetype             VARCHAR2 (100) := NULL;
        c_email_header            CONSTANT VARCHAR2 (300) := '<table border="1">';
        l_isfirstgroup            BOOLEAN := TRUE;

        l_EmailBody               VARCHAR2 (32000) := NULL;

        --=======================================================================
        -- ...............
        PROCEDURE append_to_header( p_item      IN      VARCHAR2,
                                    pio_header  IN OUT  VARCHAR2    )

        IS
        BEGIN
            pio_header := pio_header || '<th>' || p_item || '</th>';
            pkg_app_manager.p_trace (p_name => 'Append to Header:', p_text => pio_header);
        END append_to_header;
        --=======================================================================
        -- ...............
        PROCEDURE create_row (  p_item    IN      VARCHAR2,
                                pio_row   IN OUT  VARCHAR2    )

        IS
        BEGIN
            pio_row := pio_row || '<tr><td>' || p_item || '</td></tr>';
            pkg_app_manager.p_trace (p_name => 'Create Row:', p_text => pio_row);
        END create_row;

--        --=======================================================================
--        -- ...............
--        PROCEDURE append_to_row ( p_item    IN      VARCHAR2,
--                                  pio_row   IN OUT  VARCHAR2    )
--
--        IS
--        BEGIN
--            pio_row := REPLACE (pio_row, '</tr>', '<td>' || p_item || '</td></tr>');
--            pkg_app_manager.p_trace (p_name => 'Append to Row:', p_text => pio_row);
--        END append_to_row;
        --=======================================================================
        -- ...............
        PROCEDURE append_to_row(   p_item    IN      VARCHAR2,
                                    pio_row   IN OUT  VARCHAR2     )

        IS
        BEGIN
            pio_row := REGEXP_REPLACE ( pio_row,
                                        '</tr>',
                                        '<td>' || p_item || '</td></tr>',
                                        INSTR (pio_row,
                                            '</tr>',
                                            -1,
                                            1));
            pkg_app_manager.p_trace (p_name => 'Append to row2:', p_text => pio_row);
        END append_to_row;
        --=======================================================================

    --------------
    -- Start Main:
    -------------
    BEGIN
--        -----------------------------------------------------------------------
--
--        -- call procedure to start the trace.
--        -- Pass the client id to identify exactly your instance of tracing
--        -- pass the config id of the entry in the trace_config table
--        -- which needs to exist in order for tracing to work
--        pkg_app_manager.p_trace_start ( p_client_id         => NULL,  --TO_CHAR(p_debug)
--                                        p_package_name      => get_package_name,
--                                        p_procedure_name    => l_procfunc_name);
--        ------------------------------------------------------------------------

      IF (p_tabemailpayload_in.COUNT > 0)
      THEN
         pkg_app_manager.p_trace (p_name => 'Email Payload count:', p_text => p_tabemailpayload_in.COUNT);

         FOR cur_message IN (  SELECT c.groupid,
                                      c.messagetype,
                                      c.attributename,
                                      c.attributevalue,
                                      c.ColumnOrder
                                 FROM TABLE (CAST (p_tabemailpayload_in AS tab_emailpayload)) c
                             ORDER BY c.messagetype, c.groupid, c.ColumnOrder)
         LOOP

            pkg_app_manager.p_trace (p_name => '********************************');
            pkg_app_manager.p_trace (p_name => 'groupid:', p_text => cur_message.groupid);
            pkg_app_manager.p_trace (p_name => 'messagetype:', p_text => cur_message.messagetype);
            pkg_app_manager.p_trace (p_name => 'attributename:', p_text => cur_message.attributename);
            pkg_app_manager.p_trace (p_name => 'attributevalue:', p_text => cur_message.attributevalue);
            pkg_app_manager.p_trace (p_name => 'columnOrder:', p_text => cur_message.ColumnOrder);
            pkg_app_manager.p_trace (p_name => '-----------');

            IF (l_messagetype = cur_message.messagetype)
            THEN
               IF (l_groupidold = cur_message.groupid AND l_isfirstgroup)
               THEN
                  l_isfirstgroup := TRUE;
               ELSE
                  l_isfirstgroup := FALSE;
               END IF;

               IF (l_isfirstgroup)
               THEN
                  -- part of first group (row) so add to the html table header
                  pkg_app_manager.p_trace (p_name => 'Appending attribute name to table header:');
                  append_to_header( p_item      => cur_message.attributename,
                                    pio_header  => l_messageheader );
               END IF;

               IF (l_groupidold = cur_message.groupid)
               THEN
                  -- if part of same group (row) then append to the row
                  pkg_app_manager.p_trace (p_name => 'Appending attribute value to table row:');
                  append_to_row(   p_item  => cur_message.attributevalue,
                                    pio_row => l_messagebody );
               ELSE
                  -- else if part of new group (row) then create a new row and add to that
                  pkg_app_manager.p_trace (p_name => 'Creating new table row and appending attribute value:');
                  create_row (  p_item  => cur_message.messagetype,
                                pio_row => l_messagebody);
                  append_to_row(   p_item  => cur_message.attributevalue,
                                    pio_row => l_messagebody );
               END IF;

               l_groupidold := cur_message.groupid;
            ELSE
               --New message type

               IF (l_messagebody IS NULL)
               THEN
                  -- Found new message type so create new header and table row
                  pkg_app_manager.p_trace (p_name => 'Found new message type:');
                  pkg_app_manager.p_trace (p_name => 'Creating new table row and appending attribute value:');
                  append_to_header( p_item      => 'Alert Message',
                                    pio_header  => l_messageheader );
                  append_to_header( p_item      => cur_message.attributename,
                                    pio_header  => l_messageheader );
                  create_row (  p_item  => cur_message.messagetype,
                                pio_row => l_messagebody);

                  append_to_row (   p_item  => cur_message.attributevalue,  ---- used to be just append_to_row commented out
                                    pio_row => l_messagebody);
                  l_groupidold := cur_message.groupid;
               ELSE
                  -- Found new group (row) so create new header and table row
                  pkg_app_manager.p_trace (p_name => 'Found new group id (row):');
                  pkg_app_manager.p_trace (p_name => 'Creating new table row and appending attribute value:');

                  -- first save existing data in email body variable
                  l_EmailBody :=    l_EmailBody ||
                                    c_email_header ||
                                    l_messageheader ||
                                    l_messagebody ||
                                    '</table>';

                  pkg_app_manager.p_trace (p_name => 'Email body so far:', p_text => l_EmailBody);

                  -- reset message header
                  l_messageheader := NULL;
                  append_to_header( p_item      => 'Alert Message',
                                    pio_header  => l_messageheader );
                  append_to_header( p_item      => cur_message.attributename,
                                    pio_header  => l_messageheader );

                  -- reset message row
                  l_messagebody := NULL;
                  create_row (  p_item  => cur_message.messagetype,
                                pio_row => l_messagebody);
                  append_to_row (   p_item  => cur_message.attributevalue,  ---- used to be just append_to_row commented out
                                    pio_row => l_messagebody);
                  l_groupidold := cur_message.groupid;
                  l_isfirstgroup := TRUE;

               END IF;
            END IF;

            l_messagetype := cur_message.messagetype;
         END LOOP;
      END IF;

      IF (l_messagebody IS NOT NULL)
      THEN
         l_EmailBody := l_EmailBody     ||
                        c_email_header  ||
                        l_messageheader ||
                        l_messagebody   ||
                        '</table>';

         pkg_app_manager.p_trace (p_name => 'l_EmailBody', p_text => l_EmailBody);

         send_email (l_EmailBody, p_email_subject_in);
      END IF;

      -------------------------------------------------------------------------
      -- call procedure to log the end of this procedure run
--      pkg_app_manager.p_trace_end;

   END compileandsend;


   PROCEDURE testMail
   AS
      l_data   common.tab_emailPayLoad := common.tab_emailPayLoad ();
   BEGIN
      l_data.EXTEND ();
      l_data (l_data.LAST) :=
         common.obj_emailPayLoad (1,
                                  '1st Msg',
                                  'Attr1',
                                  'AttrVal1_1',
                                  3);

      l_data.EXTEND ();
      l_data (l_data.LAST) :=
         common.obj_emailPayLoad (1,
                                  '1st Msg',
                                  'Attr2',
                                  'AttrVal1_2',
                                  2);

      l_data.EXTEND ();
      l_data (l_data.LAST) :=
         common.obj_emailPayLoad (2,
                                  '1st Msg',
                                  'Attr1',
                                  'AttrVal2_1',
                                  3);

      l_data.EXTEND ();
      l_data (l_data.LAST) :=
         common.obj_emailPayLoad (2,
                                  '1st Msg',
                                  'Attr2',
                                  'AttrVal2_2',
                                  2);

            l_data.EXTEND ();
            l_data (l_data.LAST) :=
               common.obj_emailPayLoad (1,
                                        '2nd Msg',
                                        'A1',
                                        'V3_1',1);

            l_data.EXTEND ();
            l_data (l_data.LAST) :=
               common.obj_emailPayLoad (1,
                                        '2nd Msg',
                                        'A2',
                                        'V3_2',2);

            l_data.EXTEND ();
            l_data (l_data.LAST) :=
               common.obj_emailPayLoad (1,
                                        '2nd Msg',
                                        'A3',
                                        'V3_3',3);

            l_data.EXTEND ();
            l_data (l_data.LAST) :=
               common.obj_emailPayLoad (2,
                                        '2nd Msg',
                                        'A1',
                                        'V4_1',1);

            l_data.EXTEND ();
            l_data (l_data.LAST) :=
               common.obj_emailPayLoad (2,
                                        '2nd Msg',
                                        'A2',
                                        'V4_2',2);

            l_data.EXTEND ();
            l_data (l_data.LAST) :=
               common.obj_emailPayLoad (2,
                                        '2nd Msg',
                                        'A3',
                                        'V4_3',3);

      --
      --      l_data.EXTEND ();
      --      l_data (l_data.LAST) := common.obj_emailPayLoad (1,'2nd Msg','Attr1','AttrVal1_3');
      --
      --      l_data.EXTEND ();
      --      l_data (l_data.LAST) := common.obj_emailPayLoad (1,'2nd Msg','Attr2','AttrVal2_3');

      CompileAndSend (l_data, 'Testing');
   END testMail;


   --==========================================================================
   --==========================================================================
   --==========================================================================
   --==========================================================================
    /******************************************************************************
    NAME: send_email_html

    PURPOSE:  This can be used to send emails via UTL_SMTP package
              This is less restrictive than eg UTL_MAIL as it can send more than
              32K characters in the email body, hence the input to this package is a CLOB
              Note: content type defaults to text/html

    REVISIONS:
    Ver     Patch   Date        Author         Description
    ------  ------  ----------  -------------  ------------------------------------
    1.0             22/07/2014  Duncan Lucas    First Draft
    ******************************************************************************/
   PROCEDURE send_email_html (p_recipient_email_address         IN VARCHAR2,
                              p_sender_email_address            IN VARCHAR2,
                              p_email_subject                   IN VARCHAR2,
                              p_text                            IN VARCHAR2 DEFAULT NULL,
                              p_email_body                      IN CLOB DEFAULT NULL,
                              p_smtp_hostname                   IN VARCHAR2 DEFAULT 'localhost',
                              p_smtp_portnum                    IN VARCHAR2 DEFAULT '25')
    IS
        l_boundary       VARCHAR2 (255) DEFAULT 'a1b2c3d4e3f2g1';
        l_connection   UTL_SMTP.connection;
        l_body_html    CLOB := EMPTY_CLOB;                                                                          --This LOB will be the email message
        l_offset       NUMBER;
        l_ammount       NUMBER;
        l_temp           VARCHAR2 (32767) DEFAULT NULL;
        l_recipient_email_address   VARCHAR2(500);
    BEGIN
        -- filter email addresses depending on db environment and only proceed if not null
        l_recipient_email_address := filter_email_address ( p_email_address => p_recipient_email_address);

        IF l_recipient_email_address IS NOT NULL THEN
            l_connection := UTL_SMTP.open_connection (p_smtp_hostname, p_smtp_portnum);
            UTL_SMTP.helo (l_connection, p_smtp_hostname);
            UTL_SMTP.mail (l_connection, p_sender_email_address);
            UTL_SMTP.rcpt (l_connection, p_recipient_email_address);

            l_temp        := l_temp || 'MIME-Version: 1.0' || CHR (13) || CHR (10);
            l_temp        := l_temp || 'To: ' || p_recipient_email_address || CHR (13) || CHR (10);
            l_temp        := l_temp || 'From: ' || p_sender_email_address || CHR (13) || CHR (10);
            l_temp        := l_temp || 'Subject: ' || p_email_subject || CHR (13) || CHR (10);
            l_temp        := l_temp || 'Reply-To: ' || p_sender_email_address || CHR (13) || CHR (10);
            l_temp        := l_temp || 'Content-Type: multipart/alternative; boundary=' || CHR (34) || l_boundary || CHR (34) || CHR (13) || CHR (10);

            ----------------------------------------------------
            -- Write the headers
            DBMS_LOB.createtemporary (l_body_html, FALSE, 10);
            DBMS_LOB.write (l_body_html, LENGTH (l_temp), 1, l_temp);


            ----------------------------------------------------
            -- Write the text boundary
            l_offset    := DBMS_LOB.getlength (l_body_html) + 1;
            l_temp        := '--' || l_boundary || CHR (13) || CHR (10);
            l_temp        := l_temp || 'content-type: text/plain; charset=us-ascii' || CHR (13) || CHR (10) || CHR (13) || CHR (10);
            DBMS_LOB.write (l_body_html, LENGTH (l_temp), l_offset, l_temp);

            ----------------------------------------------------
            -- Write the plain text portion of the email if it exists
            IF p_text IS NOT NULL THEN
                l_offset    := DBMS_LOB.getlength (l_body_html) + 1;
                DBMS_LOB.write (l_body_html, LENGTH (p_text), l_offset, p_text);
            END IF;

            ----------------------------------------------------
            -- Write the HTML boundary
            l_temp        := CHR (13) || CHR (10) || CHR (13) || CHR (10) || '--' || l_boundary || CHR (13) || CHR (10);
            l_temp        := l_temp || 'content-type: text/html;' || CHR (13) || CHR (10) || CHR (13) || CHR (10);
            l_offset    := DBMS_LOB.getlength (l_body_html) + 1;
            DBMS_LOB.write (l_body_html, LENGTH (l_temp), l_offset, l_temp);

            ----------------------------------------------------
            -- Write the HTML portion of the message
            -- append the clob with email body which is also a clob
            -- can't use DBMS_LOB.write since that accepts a varchar2
            l_body_html := l_body_html || p_email_body;
    --        l_offset    := DBMS_LOB.getlength (l_body_html) + 1;
    --        DBMS_LOB.write (l_body_html, LENGTH (p_email_body), l_offset, p_email_body);

            ----------------------------------------------------
            -- Write the final html boundary
            l_temp        := CHR (13) || CHR (10) || '--' || l_boundary || '--' || CHR (13);
            l_offset    := DBMS_LOB.getlength (l_body_html) + 1;
            DBMS_LOB.write (l_body_html, LENGTH (l_temp), l_offset, l_temp);


            ----------------------------------------------------
            -- Send the email in 1900 byte chunks to UTL_SMTP
            l_offset    := 1;
            l_ammount    := 1900;
            UTL_SMTP.open_data (l_connection);

            WHILE l_offset < DBMS_LOB.getlength (l_body_html)
            LOOP
                UTL_SMTP.write_data (l_connection, DBMS_LOB.SUBSTR (l_body_html, l_ammount, l_offset));
                l_offset    := l_offset + l_ammount;
                l_ammount    := LEAST (1900, DBMS_LOB.getlength (l_body_html) - l_ammount);
            END LOOP;

            UTL_SMTP.close_data (l_connection);
            UTL_SMTP.quit (l_connection);
            DBMS_LOB.freetemporary (l_body_html);
        END IF;
    END send_email_html;

    PROCEDURE send_email_attachment (   p_to          IN VARCHAR2,
                                        p_from        IN VARCHAR2,
                                        p_subject     IN VARCHAR2,
                                        p_text_msg    IN VARCHAR2 DEFAULT NULL,
                                        p_attach_name IN VARCHAR2 DEFAULT NULL,
                                        p_attach_mime IN VARCHAR2 DEFAULT NULL,
                                        p_attach_clob IN CLOB DEFAULT NULL,
                                        p_smtp_host   IN VARCHAR2 DEFAULT 'localhost',
                                        p_smtp_port   IN NUMBER DEFAULT 25)
    AS
      l_mail_conn   UTL_SMTP.connection;
      l_boundary    VARCHAR2(50) := '----=*#abc1234321cba#*=';
      l_step        PLS_INTEGER  := 12000; -- make sure you set a multiple of 3 not higher than 24573
    BEGIN
      l_mail_conn := UTL_SMTP.open_connection(p_smtp_host, p_smtp_port);
      UTL_SMTP.helo(l_mail_conn, p_smtp_host);
      UTL_SMTP.mail(l_mail_conn, p_from);
      UTL_SMTP.rcpt(l_mail_conn, p_to);

      UTL_SMTP.open_data(l_mail_conn);

      UTL_SMTP.write_data(l_mail_conn, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'To: ' || p_to || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'From: ' || p_from || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Subject: ' || p_subject || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Reply-To: ' || p_from || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'MIME-Version: 1.0' || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Content-Type: multipart/mixed; boundary="' || l_boundary || '"' || UTL_TCP.crlf || UTL_TCP.crlf);

      IF p_text_msg IS NOT NULL THEN
        UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
        UTL_SMTP.write_data(l_mail_conn, 'Content-Type: text/plain; charset="iso-8859-1"' || UTL_TCP.crlf || UTL_TCP.crlf);

        UTL_SMTP.write_data(l_mail_conn, p_text_msg);
        UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
      END IF;

      IF p_attach_name IS NOT NULL THEN
        UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
        UTL_SMTP.write_data(l_mail_conn, 'Content-Type: ' || p_attach_mime || '; name="' || p_attach_name || '"' || UTL_TCP.crlf);
        UTL_SMTP.write_data(l_mail_conn, 'Content-Disposition: attachment; filename="' || p_attach_name || '"' || UTL_TCP.crlf || UTL_TCP.crlf);

        FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_attach_clob) - 1 )/l_step) LOOP
          UTL_SMTP.write_data(l_mail_conn, DBMS_LOB.substr(p_attach_clob, l_step, i * l_step + 1));
        END LOOP;

        UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
      END IF;

      UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || '--' || UTL_TCP.crlf);
      UTL_SMTP.close_data(l_mail_conn);

      UTL_SMTP.quit(l_mail_conn);
    END send_email_attachment;

END email_utils;
/
