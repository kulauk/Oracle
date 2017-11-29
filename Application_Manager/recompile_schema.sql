-- sys privileges  
DEFINE schema_name=&1

PROMPT  
PROMPT Recompiling schema  
PROMPT  
alter session set current_schema = SYS;  
PROMPT  
exec DBMS_UTILITY.COMPILE_SCHEMA ( '&schema_name' );  
PROMPT  

EXIT
