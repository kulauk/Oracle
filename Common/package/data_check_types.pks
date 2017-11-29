CREATE OR REPLACE PACKAGE common.data_check_types
AS
   /***************************************************************************
    NAME:        data_check_utils
    PURPOSE:    Provides procedures used to check data from source and target tables

    REVISIONS:
    Ver        Date        Author           Description
    ---------  ----------  ---------------  -----------------------------------
    1.0       11/08/2016  Duncan Lucas     First Draft
   ***************************************************************************/
   --==========================================================================
   --
   --      Declaration section
   --
   -- (Place your private package level variables and declarations here )
   --==========================================================================
                               
   c_data_type_varchar              CONSTANT VARCHAR2 (8) := 'VARCHAR2';
   c_data_type_number               CONSTANT VARCHAR2 (6) := 'NUMBER';
   c_data_type_date                 CONSTANT VARCHAR2 (4) := 'DATE';
   
   c_date_format                    CONSTANT VARCHAR2 (30) := 'DD/MM/YYYY hh24:mi:ss';

END data_check_types;
/
