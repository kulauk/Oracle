CREATE OR REPLACE PACKAGE common.data_check_utils
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

   --< TRY NOT TO CREATE ANY PACKAGE LEVEL VARIABLES SO THAT THE PACKAGE    >--
   --< DOES NOT HAVE STATE. USE AMS_TYPES FOR VARIABLES INSTEAD             >--

    --=====================================================================

   PROCEDURE validate_data (  p_unique_id       IN NUMBER, 
                              p_data_source     IN VARCHAR2,
                              p_col_name        IN VARCHAR2, 
                              p_col_datatype    IN VARCHAR2,
                              po_is_data_equal     OUT BOOLEAN,
                              po_source_data       OUT VARCHAR2,
                              po_target_data       OUT VARCHAR2);                                 

END data_check_utils;
/
