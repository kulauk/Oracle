/*
| This program is a part of the Quest Error Manager for Oracle.
| This product is freeware and is not supported by Quest.
| 
| www.quest.com
| 
| Copyright, Quest Software, Inc, 2007
| All rights reserved

© 2008 Quest Software, Inc.
ALL RIGHTS RESERVED.

Redistribution and use of the Quest Error Manager for Oracle software in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1.    Redistributions of source code must retain (i) the following copyright notice: "©2008 Quest Software, Inc. All rights reserved," (ii) this list of conditions, and (iii) the disclaimer below. 

2.    Redistributions in binary form must reproduce (i) the following copyright notice: "©2008 Quest Software, Inc. All rights reserved," (ii) this list of conditions, and (iii) the disclaimer below, in the documentation and/or other materials provided with the distribution. 

3.    All advertising materials mentioning features or use of the Quest Error Manager for Oracle software must display the following acknowledgement: 

This product includes software developed by Quest Software, Inc. and its contributors.

4.    Neither the name of Quest Software, Inc. nor the name its affiliates, subsidiaries or contributors may be used to endorse or promote products derived from the Quest Error Manager for Oracle software without specific prior written permission from Quest Software, Inc. 

Disclaimer:

THIS SOFTWARE IS PROVIDED BY QUEST SOFTWARE, INC. AND ITS CONTRIBUTORS ``AS IS'' 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, 
AND NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL QUEST SOFTWARE OR ITS 
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, 
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE 
QUEST ERROR MANAGER SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

SPOOL qem$install.log

CREATE SEQUENCE q$error_seq
/

CREATE SEQUENCE q$log_seq
/

CREATE SEQUENCE q$error_context_seq
/

CREATE SEQUENCE q$error_instance_seq
/

CREATE TABLE q$error_context
(
   id                  INTEGER
 , error_instance_id   INTEGER
 , name                VARCHAR2 (500) NOT NULL
 , VALUE               VARCHAR2 (4000)
 , created_on          DATE
 , created_by          VARCHAR2 (100)
 , changed_on          DATE
 , changed_by          VARCHAR2 (100)
)
/

COMMENT ON TABLE q$error_context IS
'Actual value for the named context for a given error instance.'
/

CREATE TABLE q$error
(
   id                    INTEGER
 , error_category_name   VARCHAR2 (500)
 , code                  INTEGER
 , name                  VARCHAR2 (500)
 , description           VARCHAR2 (4000)
 , substitute_string     VARCHAR2 (4000)
 , recommendation        VARCHAR2 (4000)
 , created_on            DATE
 , created_by            VARCHAR2 (100)
 , changed_on            DATE
 , changed_by            VARCHAR2 (100)
)
/

COMMENT ON TABLE q$error IS
'The set of pre-defined errors copied from sa_error when app was deployed'
/

CREATE TABLE q$error_instance
(
   id                     INTEGER
 , error_id               INTEGER
 , error_stack            VARCHAR2 (4000)
 , call_stack             VARCHAR2 (4000)
 , MESSAGE                VARCHAR2 (4000)
 , system_error_code      INTEGER
 , system_error_message   VARCHAR2 (4000)
 , environment_info       VARCHAR2 (4000)
 , created_on             DATE
 , created_by             VARCHAR2 (100)
 , changed_on             DATE
 , changed_by             VARCHAR2 (100)
)
/

COMMENT ON TABLE q$error_instance IS
'A particular instance of an error that occurs in the application'
/

CREATE TABLE q$log
(
   id           INTEGER
 , context      VARCHAR2 (500)
 , text         VARCHAR2 (4000)
 , call_stack   VARCHAR2 (4000)
 , created_on   TIMESTAMP(9)                      NOT NULL
 , created_by   VARCHAR2 (100)
 , changed_on   DATE
 , changed_by   VARCHAR2 (100)
)
/

CREATE UNIQUE INDEX q$error_context_un
   ON q$error_context (error_instance_id, name)
/

CREATE UNIQUE INDEX q$error_context_pk
   ON q$error_context (id)
/

CREATE UNIQUE INDEX q$error_pk
   ON q$error (id)
/

CREATE UNIQUE INDEX q$error_code_pk
   ON q$error (code)
/

CREATE UNIQUE INDEX q$error_instance_pk
   ON q$error_instance (id)
/

CREATE UNIQUE INDEX q$log_pk
   ON q$log (id)
/

ALTER TABLE q$error_context ADD (
  CONSTRAINT q$error_context_pk PRIMARY KEY (id))
/
ALTER TABLE q$error ADD (
  CONSTRAINT q$error_pk PRIMARY KEY (id))
/
ALTER TABLE q$error_instance ADD (
  CONSTRAINT q$error_instance_pk PRIMARY KEY (id))
/
ALTER TABLE q$log ADD (
  CONSTRAINT q$log_pk PRIMARY KEY (id))
/
ALTER TABLE q$error_context ADD (
  CONSTRAINT q$error_context_errinst_fk FOREIGN KEY (error_instance_id)
    REFERENCES q$error_instance (id)
    ON DELETE CASCADE)
/
ALTER TABLE q$error_instance ADD (
  CONSTRAINT q$error_instance_err_fk FOREIGN KEY (error_id)
    REFERENCES q$error (id)
    ON DELETE CASCADE)
/

/* 1.2.17 Provided by Filipe de Silva; add env info. */

CREATE OR REPLACE TRIGGER q$error_instance_ir
   BEFORE INSERT
   ON q$error_instance
   REFERENCING OLD AS old NEW AS new
   FOR EACH ROW
BEGIN
   :new.created_on := SYSDATE;
   :new.created_by := SYS_CONTEXT ('USERENV', 'SESSION_USER');

   :new.environment_info :=
         'instance: '
      || SYS_CONTEXT ('USERENV', 'INSTANCE')
      || '/'
      || SYS_CONTEXT ('USERENV', 'INSTANCE_NAME')
      || CHR (10)
      || 'db_name: '
      || SYS_CONTEXT ('USERENV', 'DB_NAME')
      || CHR (10)
      || 'db_domain: '
      || SYS_CONTEXT ('USERENV', 'DB_DOMAIN')
      || CHR (10)
      || 'host: '
      || SYS_CONTEXT ('USERENV', 'SERVER_HOST')
      || CHR (10)
      || 'service_name: '
      || SYS_CONTEXT ('USERENV', 'SERVICE_NAME')
      || CHR (10)
      || '--'
      || CHR (10)
      || 'session_user: '
      || SYS_CONTEXT ('USERENV', 'SESSION_USER')
      || CHR (10)
      || 'session_id: '
      || SYS_CONTEXT ('USERENV', 'SESSIONID')
      || CHR (10)
      || '--'
      || CHR (10)
      || 'host: '
      || SYS_CONTEXT ('USERENV', 'HOST')
      || CHR (10)
      || 'ip_address: '
      || SYS_CONTEXT ('USERENV', 'IP_ADDRESS')
      || CHR (10)
      || 'os_user: '
      || SYS_CONTEXT ('USERENV', 'OS_USER')
      || CHR (10)
      || '--'
      || CHR (10)
      || 'module: '
      || SYS_CONTEXT ('USERENV', 'MODULE')
      || CHR (10)
      || 'action: '
      || SYS_CONTEXT ('USERENV', 'ACTION')
      || CHR (10)
      || 'client_identifier: '
      || SYS_CONTEXT ('USERENV', 'CLIENT_IDENTIFIER')
      || CHR (10)
      || 'client_info: '
      || SYS_CONTEXT ('USERENV', 'CLIENT_INFO')
      || CHR (10)
      || '--'
      || CHR (10)
      || 'bg_job_id: '
      || SYS_CONTEXT ('USERENV', 'BG_JOB_ID')
      || CHR (10)
      || 'fg_job_id: '
      || SYS_CONTEXT ('USERENV', 'FG_JOB_ID')
      || CHR (10);
END;
/

@@q$error_manager.pks

@@q$error_manager.pkb

SPOOL OFF