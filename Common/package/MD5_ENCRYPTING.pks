CREATE OR REPLACE PACKAGE Common.md5_encrypting IS

------------------------------------------------------------------------------
--   COMPANY:    FINSOFT
--   NAME:       md5_encrypting
--   PURPOSE:    Encrypts
--   REVISIONS:
--   Ver        Date        Author           Description
--   ---------  ----------  ---------------  ------------------------------------ 
--   1.0        04.09.2000  Dejan Marjanovic
--   1.1        01.11.2000  Dejan Marijanovic, Dusan Zivkovic (fixed it, yeah)
--   NOTES:
-------------------------------------------------------------------------------

   FUNCTION Encrypt(pInput IN VARCHAR2, pOutput IN OUT VARCHAR2) RETURN NUMBER;

   FUNCTION Encrypt(pInput IN VARCHAR2) RETURN VARCHAR2;

END md5_encrypting;
/
