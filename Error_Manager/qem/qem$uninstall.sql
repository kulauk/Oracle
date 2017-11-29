/*
| This program is a part of the Quest Error Manager for Oracle.
| This product is freeware and is not supported by Quest.
| 
| www.quest.com
| 
| Copyright, Quest Software, Inc, 2007
| All rights reserved
*/

DROP SEQUENCE q$error_seq
/
DROP SEQUENCE q$log_seq
/
DROP SEQUENCE q$error_context_seq
/
DROP SEQUENCE q$error_instance_seq
/

DROP TABLE q$error_context
/

DROP TABLE q$error_instance
/

DROP TABLE q$error
/

DROP TABLE q$log
/

DROP PACKAGE q$error_manager
/
