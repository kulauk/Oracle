CREATE OR REPLACE PACKAGE COMMON.utils_types
AS
   /***************************************************************************
    NAME:        utils_types
    PURPOSE:    Provides constants for UTILS package

    REVISIONS:
    Ver        Date        Author           Description
    ---------  ----------  ---------------  -----------------------------------
    1.0       06/01/2017  Duncan Lucas     First Draft
   ***************************************************************************/
   --==========================================================================
   --
   --      Declaration section
   --
   -- (Place your private package level variables and declarations here )
   --==========================================================================

   c_SysConfSec_DynSamp             CONSTANT VARCHAR2(30) := 'DYNAMIC_SAMPLING_FIX';
   c_dynSampling_fix_control_on     CONSTANT NUMBER(1) := 1;   
   c_dynSampling_fix_control_off    CONSTANT NUMBER(1) := 0;

END utils_types;
/
