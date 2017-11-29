CREATE TABLE application_manager_t (
    installed_applications VARCHAR2(50),
    application_object_name  VARCHAR2(30),
    grant_to_application    VARCHAR2(100),
    create_synonym_flag VARCHAR2(1),
    installation_dts    DATE,
 CONSTRAINT XPK_application_manager  
 PRIMARY KEY (installed_applications, application_object_name)
)
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING;
