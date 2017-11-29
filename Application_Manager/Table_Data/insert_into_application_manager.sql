SET DEFINE ON

DEFINE application_name=&1
DEFINE application_object_name=&2
DEFINE grant_to_application=&3
DEFINE create_synonym_flag=&4

INSERT INTO application_manager_t( installed_applications
                                 , application_object_name
                                 , grant_to_application
                                 , create_synonym_flag
                                 , installation_dts )
VALUES (    '&application_name', 
            '&application_object_name', 
            NVL('&grant_to_application', 'EXECUTE'), 
            '&create_synonym_flag', 
            SYSDATE );