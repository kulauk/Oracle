CREATE OR REPLACE PACKAGE BODY Common.md5_encrypting AS
------------------------------------------------------------------------------
--   COMPANY:    FINSOFT
--   NAME:       md5_encrypting
--   PURPOSE:    Encrypts
--   REVISIONS:
--   Ver        Date        Author           Description
--   ---------  ----------  ---------------  ------------------------------------
--   1.0        04.09.2000  Dejan Marjanovic 
--   1.1        01.11.2000  Dejan Marijanovic, Dusan Zivkovic (fixed it, yeah)
--   1.2        15.07.2003  Darren Stone     IN0349 - Hard code ASCII(128) into the first byte of inBuf as
--                                           Oracle 8i would appear to recognise the first byte
--                                           as ASCII(128), where as Oracle 9i does not. Therefore,
--                                           enabling the 8i and 9i versions of this package to return
--                                           the same result.
--   NOTES:
-------------------------------------------------------------------------------

   -- custom types
   TYPE UINT4 IS RECORD (
      value RAW(4)
   );

   TYPE MD5_CTX IS RECORD (
      i0   UINT4,    -- number of _bits_ handled mod 2^64
         i1   UINT4,

         buf0 UINT4,
         buf1 UINT4,
         buf2 UINT4,
         buf3 UINT4,

         inBuf  VARCHAR2(64), -- input buffer,
         digest VARCHAR2(129)  -- actual digest after MD5Final call
   );

   TYPE UINT4_Array IS TABLE OF UINT4 INDEX BY BINARY_INTEGER;

   TYPE Varchar2_Array IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;

   TYPE Number_Array IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;


   -- package constants
   pcTwoOn32     CONSTANT NUMBER      := 4294967296;
   pcByteOrder   CONSTANT VARCHAR2(2) := 'HL';
   pcZeroVarchar CONSTANT VARCHAR2(1) := UTL_RAW.CAST_TO_VARCHAR2(HEXTORAW('0'));
   pcSizeOfUINT4 CONSTANT NUMBER      := 4;

   S11 CONSTANT NUMBER := 7;
   S12 CONSTANT NUMBER := 12;
   S13 CONSTANT NUMBER := 17;
   S14 CONSTANT NUMBER := 22;

   S21 CONSTANT NUMBER := 5;
   S22 CONSTANT NUMBER := 9;
   S23 CONSTANT NUMBER := 14;
   S24 CONSTANT NUMBER := 20;

   S31 CONSTANT NUMBER := 4;
   S32 CONSTANT NUMBER := 11;
   S33 CONSTANT NUMBER := 16;
   S34 CONSTANT NUMBER := 23;

   S41 CONSTANT NUMBER := 6;
   S42 CONSTANT NUMBER := 10;
   S43 CONSTANT NUMBER := 15;
   S44 CONSTANT NUMBER := 21;


   gPadding VARCHAR2(100);

   PROCEDURE Show(pRaw RAW) IS
         i NUMBER;
         n NUMBER;
                        nHex VARCHAR2(3);
   BEGIN
         FOR i IN 1..UTL_RAW.LENGTH(pRaw) LOOP
            n := TO_NUMBER(RAWTOHEX(UTL_RAW.SUBSTR(pRaw, i, 1)), 'XX');
                                    nHex := TO_CHAR(n, 'XX');
         END LOOP;
   END Show;


   PROCEDURE ReverseVarchar2(pChar IN OUT VARCHAR2) IS
      i NUMBER;
         len NUMBER;
         tmp VARCHAR2(100);
   BEGIN
      tmp := '';
      len := LENGTH(pChar);

         FOR i IN 1..len LOOP
            tmp := CONCAT(tmp, SUBSTR(pChar, len - i + 1, 1));
         END LOOP;

         pChar := tmp;
   END ReverseVarchar2;



   ----------------------------------------------------------------------------
   -- Padding functions
   ----------------------------------------------------------------------------

   PROCEDURE NormalizeToFourByteLength(pRaw IN OUT RAW) IS
      i NUMBER;
   BEGIN
      i := UTL_RAW.LENGTH(pRaw);
         WHILE(i < 4) LOOP
            IF pcByteOrder = 'HL' THEN
            pRaw := UTL_RAW.CONCAT(HEXTORAW('0'), pRaw);
         END IF;
            i := i+1;
         END LOOP;

   END NormalizeToFourByteLength;



            PROCEDURE NormalizeToFourByteLength(pNum IN OUT NUMBER) IS
            BEGIN
               pNum := MOD(pNum, pcTwoOn32);
            END;



   PROCEDURE PadWithZeros(pRaw IN OUT RAW, len NUMBER) IS
      i NUMBER;
   BEGIN
      IF (i < 0) THEN
            RETURN;
         END IF;

      i := UTL_RAW.LENGTH(pRaw);
         WHILE (i < len) LOOP
            IF pcByteOrder = 'HL' THEN
            pRaw := UTL_RAW.CONCAT(HEXTORAW('0'), pRaw);
         END IF;
            i := i + 1;
         END LOOP;
   END PadWithZeros;


   PROCEDURE PadWithZeros(pChar IN OUT VARCHAR2, len NUMBER, dummy NUMBER) IS
      i NUMBER;
   BEGIN
      IF (i < 0) THEN
            RETURN;
         END IF;

                        IF pChar IS NULL THEN
                           pChar:= '';
                        END IF;

      i := LENGTH(pChar);
         WHILE (i < len) LOOP
            pChar := CONCAT(pChar, pcZeroVarchar);
              i := i + 1;
         END LOOP;
   END PadWithZeros;


   PROCEDURE CopyVarchar2ToVarchar2_Array(
                dest IN OUT Varchar2_Array,
                            destLen NUMBER,
                source VARCHAR2,
                            sourceLen NUMBER,
                      padChar VARCHAR2 DEFAULT NULL) IS
      i NUMBER;

   BEGIN
      IF(sourceLen >= destLen) THEN
            FOR i IN 1..destLen LOOP
                  dest(i) := SUBSTR(source, i, 1);
               END LOOP;

         ELSIF (sourceLen < destLen) THEN
            FOR i IN 1..sourceLen LOOP
                  dest(i) := SUBSTR(source, i, 1);
               END LOOP;
               FOR i IN sourceLen+1..destLen LOOP
                  dest(i) := padChar;
               END LOOP;

         END IF;
   END CopyVarchar2ToVarchar2_Array;


   PROCEDURE CopyVarchar2_ArrayToVarchar2(
                  dest IN OUT VARCHAR2,
               destLen NUMBER,
      source Varchar2_Array,
                  sourceLen NUMBER,
                  padChar VARCHAR2 DEFAULT NULL) IS

                        temp VARCHAR2(1);
   BEGIN
      dest := '';
      IF sourceLen >= destLen THEN
            FOR i IN 1..destLen LOOP
                                       temp := source(i);
            dest := CONCAT(dest, source(i));
            END LOOP;

         ELSIF sourceLen < destLen THEN
            FOR i IN 1..sourceLen LOOP
                                       temp := source(i);
                  dest := CONCAT(dest, source(i));
               END LOOP;
               FOR i IN sourceLen+1..destLen LOOP
                  dest := CONCAT(dest, padChar);
               END LOOP;

         END IF;
   END CopyVarchar2_ArrayToVarchar2;



            PROCEDURE FourByteNumberToBytes(
                         pNum IN     NUMBER,
                                                                b0   IN OUT NUMBER,
                                                                b1   IN OUT NUMBER,
                                                                b2   IN OUT NUMBER,
                                                                b3   IN OUT NUMBER
                                                                ) IS
      lTemp NUMBER;

   BEGIN
               lTemp := MOD(pNum, pcTwoOn32);

                        b0 := MOD(lTemp, 256);

                        lTemp := TRUNC(lTemp / 256);
                        b1 := MOD(lTemp, 256);

                        lTemp := TRUNC(lTemp / 256);
                        b2 := MOD(lTemp, 256);

                        lTemp := TRUNC(lTemp / 256);
                        b3 := MOD(lTemp, 256);
            END FourByteNumberToBytes;

   ---------------------------------------------------------------------------
   -- Raw <-> UINT4
   ---------------------------------------------------------------------------

   FUNCTION RawToFourByteNumber(pRaw RAW) RETURN NUMBER IS
      lHexRaw VARCHAR2(8);
   BEGIN
      lHexRaw := RAWTOHEX(pRaw);
      RETURN TO_NUMBER(lHexRaw, 'XXXXXXXX');
   END RawToFourByteNumber;



   FUNCTION FourByteNumberToRaw(pNum NUMBER) RETURN RAW IS
      lChar VARCHAR2(16);
         lRaw  RAW(4);
   BEGIN
      lChar := TO_CHAR(MOD(pNum, pcTwoOn32), 'XXXXXXXX');
                        lChar := RTRIM(lChar);
                        lChar := LTRIM(lChar);
         lRaw  := HEXTORAW(lChar);
         NormalizeToFourByteLength(lRaw);
         RETURN lRaw;
   END FourByteNumberToRaw;



   ----------------------------------------------------------------------------
   -- Varchar2 <-> UINT4
   ----------------------------------------------------------------------------

   FUNCTION FourByteNumberToHexString(pNumber NUMBER) RETURN VARCHAR2 IS
   BEGIN
      RETURN TO_CHAR(MOD(pNumber, pcTwoOn32), 'XXXXXXXX');
   END FourByteNumberToHexString;



   FUNCTION HexStringToFourByteNumber(pHexString VARCHAR2) RETURN NUMBER IS
   BEGIN
      RETURN TO_NUMBER(pHexString, 'XXXXXXXX');
   END HexStringToFourByteNumber;



   ----------------------------------------------------------------------------
   -- operator=, operator<<, operator>>, rotate right AND left for UINT4, Number
   ----------------------------------------------------------------------------

   PROCEDURE OperatorAssign(pLeft IN OUT RAW,
                            pRight IN RAW,
                                                 pLength IN NUMBER,
                                                 pPosition IN NUMBER DEFAULT 1,
                                                 pPaddingByte IN RAW DEFAULT NULL) IS
   BEGIN
      pLeft := UTL_RAW.OVERLAY(pRight, pLeft, pPosition, pLength, pPaddingByte);
   END OperatorAssign;


   FUNCTION OperatorShiftRightUINT4(pRaw RAW, pNum NUMBER) RETURN RAW IS
      lNumber NUMBER;
         lRaw RAW(4);
   BEGIN
      lRaw := pRaw;
      lNumber := RawToFourByteNumber(lRaw);
         lNumber := TRUNC(lNumber, POWER(2, pNum));

         lRaw := FourByteNumberToRaw(lNumber);
         NormalizeToFourByteLength(lRaw);
         RETURN lRaw;
   END OperatorShiftRightUINT4;


   FUNCTION OperatorShiftLeftUINT4(pRaw RAW, pNum NUMBER) RETURN RAW IS
      lNumber NUMBER;
      lRaw RAW(4);
   BEGIN
      lRaw := pRaw;
      lNumber := RawToFourByteNumber(lRaw);
         lNumber := lNumber * POWER(2, pNum);
         lNumber := TRUNC(lNumber, pcTwoOn32);

         lRaw := FourByteNumberToRaw(lNumber);
         NormalizeToFourByteLength(lRaw);
         RETURN lRaw;
   END OperatorShiftLeftUINT4;


   FUNCTION OperatorShiftLeftUINT4(pNumber NUMBER, pShift NUMBER) RETURN NUMBER IS
      lNumber NUMBER;
   BEGIN
      lNumber := pNumber;
      lNumber := lNumber * POWER(2, pShift);
         RETURN MOD(lNumber, pcTwoOn32);
   END OperatorShiftLeftUINT4;


   FUNCTION OperatorShiftRightUINT4(pNumber NUMBER, pShift NUMBER) RETURN NUMBER IS
   BEGIN
      RETURN TRUNC(pNumber / POWER(2, pShift));
   END OperatorShiftRightUINT4;


   FUNCTION OperatorRotateLeftUINT4(pNumber NUMBER, pRot NUMBER) RETURN NUMBER IS
      lOutPart NUMBER;
         lResult NUMBER;
   BEGIN
      lOutPart := OperatorShiftRightUINT4(pNumber, 8 * pcSizeOfUINT4 - pRot);
         lResult := OperatorShiftLeftUINT4(pNumber, pRot);
         lResult := lResult + lOutPart;

                        RETURN lResult;
   END OperatorRotateLeftUINT4;

   ----------------------------------------------------------------------------
   -- F, G, H, I
   ----------------------------------------------------------------------------
-- #define F(x, y, z) (((x) AND (y)) | ((~x) AND (z)))
   FUNCTION F(x NUMBER, y NUMBER, z NUMBER) RETURN NUMBER IS
      xRaw RAW(4);
         yRaw RAW(4);
         zRaw RAW(4);

         xNot     RAW(4);
         xAndY    RAW(4);
         xNotAndZ RAW(4);

                        lTemp NUMBER;
   BEGIN
      xRaw := FourByteNumberToRaw(x);
         yRaw := FourByteNumberToRaw(y);
         zRaw := FourByteNumberToRaw(z);

         xNot     := UTL_RAW.BIT_COMPLEMENT(xRaw);
         xAndY    := UTL_RAW.BIT_AND(xRaw, yRaw);
         xNotAndZ := UTL_RAW.BIT_AND(xNot, zRaw);

               lTemp := RawToFourByteNumber(UTL_RAW.BIT_OR(xAndY, xNotAndZ));
         RETURN RawToFourByteNumber(UTL_RAW.BIT_OR(xAndY, xNotAndZ));
   END F;

-- #define G(x, y, z) (((x) AND (z)) | ((y) AND (~z)))
   FUNCTION G(x NUMBER, y NUMBER, z NUMBER) RETURN NUMBER IS
      xRaw RAW(4);
         yRaw RAW(4);
         zRaw RAW(4);

         zNot     RAW(4);
         xAndZ    RAW(4);
         zNotAndY RAW(4);
   BEGIN
      xRaw := FourByteNumberToRaw(x);
         yRaw := FourByteNumberToRaw(y);
         zRaw := FourByteNumberToRaw(z);

         zNot := UTL_RAW.BIT_COMPLEMENT(zRaw);
         xAndZ := UTL_RAW.BIT_AND(xRaw, zRaw);
         zNotAndY := UTL_RAW.BIT_AND(zNot, yRaw);

         RETURN RawToFourByteNumber(UTL_RAW.BIT_OR(xAndZ, zNotAndY));
   END G;


-- #define H(x, y, z) ((x) ^ (y) ^ (z))
   FUNCTION H(x NUMBER, y NUMBER, z NUMBER) RETURN NUMBER IS
      xRaw RAW(4);
         yRaw RAW(4);
         zRaw RAW(4);

      xXorY RAW(4);
   BEGIN
      xRaw := FourByteNumberToRaw(x);
         yRaw := FourByteNumberToRaw(y);
         zRaw := FourByteNumberToRaw(z);

         xXorY := UTL_RAW.BIT_XOR(xRaw, yRaw);
         RETURN RawToFourByteNumber(UTL_RAW.BIT_XOR(xXorY, zRaw));
   END H;


-- #define I(x, y, z) ((y) ^ ((x) | (~z)))
   FUNCTION I(x NUMBER, y NUMBER, z NUMBER) RETURN NUMBER IS
      xRaw RAW(4);
         yRaw RAW(4);
         zRaw RAW(4);

         zNot     RAW(4);
         zNotOrX RAW(4);
   BEGIN
      xRaw := FourByteNumberToRaw(x);
         yRaw := FourByteNumberToRaw(y);
         zRaw := FourByteNumberToRaw(z);

         zNot := UTL_RAW.BIT_COMPLEMENT(zRaw);
         zNotOrX := UTL_RAW.BIT_OR(zNot, xRaw);

         RETURN RawToFourByteNumber(UTL_RAW.BIT_XOR(zNotOrX, yRaw));
   END I;


   ----------------------------------------------------------------------------
   -- FF, GG, HH ,II
   ----------------------------------------------------------------------------
   PROCEDURE FF(a IN OUT NUMBER, b NUMBER, c NUMBER, d NUMBER, x NUMBER, s NUMBER, ac NUMBER) IS
   BEGIN
      a := a + F(b, c, d) + x + ac;
                        NormalizeToFourByteLength(a);

         a := OperatorRotateLeftUINT4(a, s);
         a := a + b;
                        NormalizeToFourByteLength(a);
   END FF;


   PROCEDURE GG(a IN OUT NUMBER, b NUMBER, c NUMBER, d NUMBER, x NUMBER, s NUMBER, ac NUMBER) IS
   BEGIN
      a := a + G(b, c, d) + x + ac;
                        NormalizeToFourByteLength(a);

         a := OperatorRotateLeftUINT4(a, s);
         a := a + b;
                        NormalizeToFourByteLength(a);
   END GG;


   PROCEDURE HH(a IN OUT NUMBER, b NUMBER, c NUMBER, d NUMBER, x NUMBER, s NUMBER, ac NUMBER) IS
   BEGIN
      a := a + H(b, c, d) + x + ac;
                        NormalizeToFourByteLength(a);

         a := OperatorRotateLeftUINT4(a, s);
         a := a + b;
                        NormalizeToFourByteLength(a);
   END HH;


   PROCEDURE II(a IN OUT NUMBER, b NUMBER, c NUMBER, d NUMBER, x NUMBER, s NUMBER, ac NUMBER) IS
   BEGIN
      a := a + I(b, c, d) + x + ac;
                        NormalizeToFourByteLength(a);

         a := OperatorRotateLeftUINT4(a, s);
         a := a + b;
                        NormalizeToFourByteLength(a);
   END II;


   ----------------------------------------------------------------------------
   -- Transform function and functions needed for its implementation
   ----------------------------------------------------------------------------
   PROCEDURE Transform(
                ar IN OUT UINT4,
                br IN OUT UINT4,
                            cr IN OUT UINT4,
                            dr IN OUT UINT4,
                            pInArray Number_Array) IS
      a NUMBER;
      b NUMBER;
         c NUMBER;
         d NUMBER;

         aOld NUMBER;
         bOld NUMBER;
         cOld NUMBER;
         dOld NUMBER;
   BEGIN
      a := RawToFourByteNumber(ar.value );
         b := RawToFourByteNumber(br.value );
         c := RawToFourByteNumber(cr.value );
         d := RawToFourByteNumber(dr.value );

         aOld := a;
         bOld := b;
         cOld := c;
         dOld := d;

      -- C array is zero indexed and pInArray indexed from 1
      FF ( a, b, c, d, pInArray( 0+1), S11, TO_NUMBER('D76AA478', 'XXXXXXXX')); -- 1
      FF ( d, a, b, c, pInArray( 1+1), S12, TO_NUMBER('E8C7B756', 'XXXXXXXX')); -- 2
      FF ( c, d, a, b, pInArray( 2+1), S13, TO_NUMBER('242070DB', 'XXXXXXXX')); -- 3
      FF ( b, c, d, a, pInArray( 3+1), S14, TO_NUMBER('C1BDCEEE', 'XXXXXXXX')); -- 4
      FF ( a, b, c, d, pInArray( 4+1), S11, TO_NUMBER('F57C0FAF', 'XXXXXXXX')); -- 5
      FF ( d, a, b, c, pInArray( 5+1), S12, TO_NUMBER('4787C62A', 'XXXXXXXX')); -- 6
      FF ( c, d, a, b, pInArray( 6+1), S13, TO_NUMBER('A8304613', 'XXXXXXXX')); -- 7
      FF ( b, c, d, a, pInArray( 7+1), S14, TO_NUMBER('FD469501', 'XXXXXXXX')); -- 8
      FF ( a, b, c, d, pInArray( 8+1), S11, TO_NUMBER('698098D8', 'XXXXXXXX')); -- 9
      FF ( d, a, b, c, pInArray( 9+1), S12, TO_NUMBER('8B44F7AF', 'XXXXXXXX')); -- 10
      FF ( c, d, a, b, pInArray(10+1), S13, TO_NUMBER('FFFF5BB1', 'XXXXXXXX')); -- 11
      FF ( b, c, d, a, pInArray(11+1), S14, TO_NUMBER('895CD7BE', 'XXXXXXXX')); -- 12
      FF ( a, b, c, d, pInArray(12+1), S11, TO_NUMBER('6B901122', 'XXXXXXXX')); -- 13
      FF ( d, a, b, c, pInArray(13+1), S12, TO_NUMBER('FD987193', 'XXXXXXXX')); -- 14
      FF ( c, d, a, b, pInArray(14+1), S13, TO_NUMBER('A679438E', 'XXXXXXXX')); -- 15
      FF ( b, c, d, a, pInArray(15+1), S14, TO_NUMBER('49B40821', 'XXXXXXXX')); -- 16

      GG ( a, b, c, d, pInArray( 1+1), S21, TO_NUMBER('F61E2562', 'XXXXXXXX')); -- 17
      GG ( d, a, b, c, pInArray( 6+1), S22, TO_NUMBER('C040B340', 'XXXXXXXX')); -- 18
      GG ( c, d, a, b, pInArray(11+1), S23, TO_NUMBER('265E5A51', 'XXXXXXXX')); -- 19
      GG ( b, c, d, a, pInArray( 0+1), S24, TO_NUMBER('E9B6C7AA', 'XXXXXXXX')); -- 20
      GG ( a, b, c, d, pInArray( 5+1), S21, TO_NUMBER('D62F105D', 'XXXXXXXX')); -- 21
      GG ( d, a, b, c, pInArray(10+1), S22, TO_NUMBER('02441453', 'XXXXXXXX')); -- 22
      GG ( c, d, a, b, pInArray(15+1), S23, TO_NUMBER('D8A1E681', 'XXXXXXXX')); -- 23
      GG ( b, c, d, a, pInArray( 4+1), S24, TO_NUMBER('E7D3FBC8', 'XXXXXXXX')); -- 24
      GG ( a, b, c, d, pInArray( 9+1), S21, TO_NUMBER('21E1CDE6', 'XXXXXXXX')); -- 25
      GG ( d, a, b, c, pInArray(14+1), S22, TO_NUMBER('C33707D6', 'XXXXXXXX')); -- 26
      GG ( c, d, a, b, pInArray( 3+1), S23, TO_NUMBER('F4D50D87', 'XXXXXXXX')); -- 27
      GG ( b, c, d, a, pInArray( 8+1), S24, TO_NUMBER('455A14ED', 'XXXXXXXX')); -- 28
      GG ( a, b, c, d, pInArray(13+1), S21, TO_NUMBER('A9E3E905', 'XXXXXXXX')); -- 29
      GG ( d, a, b, c, pInArray( 2+1), S22, TO_NUMBER('FCEFA3F8', 'XXXXXXXX')); -- 30
      GG ( c, d, a, b, pInArray( 7+1), S23, TO_NUMBER('676F02D9', 'XXXXXXXX')); -- 31
      GG ( b, c, d, a, pInArray(12+1), S24, TO_NUMBER('8D2A4C8A', 'XXXXXXXX')); -- 32

      HH ( a, b, c, d, pInArray( 5+1), S31, TO_NUMBER('FFFA3942', 'XXXXXXXX')); -- 33
      HH ( d, a, b, c, pInArray( 8+1), S32, TO_NUMBER('8771F681', 'XXXXXXXX')); -- 34
      HH ( c, d, a, b, pInArray(11+1), S33, TO_NUMBER('6D9D6122', 'XXXXXXXX')); -- 35
      HH ( b, c, d, a, pInArray(14+1), S34, TO_NUMBER('FDE5380C', 'XXXXXXXX')); -- 36
      HH ( a, b, c, d, pInArray( 1+1), S31, TO_NUMBER('A4BEEA44', 'XXXXXXXX')); -- 37
      HH ( d, a, b, c, pInArray( 4+1), S32, TO_NUMBER('4BDECFA9', 'XXXXXXXX')); -- 38
      HH ( c, d, a, b, pInArray( 7+1), S33, TO_NUMBER('F6BB4B60', 'XXXXXXXX')); -- 39
      HH ( b, c, d, a, pInArray(10+1), S34, TO_NUMBER('BEBFBC70', 'XXXXXXXX')); -- 40
      HH ( a, b, c, d, pInArray(13+1), S31, TO_NUMBER('289B7EC6', 'XXXXXXXX')); -- 41
      HH ( d, a, b, c, pInArray( 0+1), S32, TO_NUMBER('EAA127FA', 'XXXXXXXX')); -- 42
      HH ( c, d, a, b, pInArray( 3+1), S33, TO_NUMBER('D4EF3085', 'XXXXXXXX')); -- 43
      HH ( b, c, d, a, pInArray( 6+1), S34, TO_NUMBER('04881D05', 'XXXXXXXX')); -- 44
      HH ( a, b, c, d, pInArray( 9+1), S31, TO_NUMBER('D9D4D039', 'XXXXXXXX')); -- 45
      HH ( d, a, b, c, pInArray(12+1), S32, TO_NUMBER('E6DB99E5', 'XXXXXXXX')); -- 46
      HH ( c, d, a, b, pInArray(15+1), S33, TO_NUMBER('1FA27CF8', 'XXXXXXXX')); -- 47
      HH ( b, c, d, a, pInArray( 2+1), S34, TO_NUMBER('C4AC5665', 'XXXXXXXX')); -- 48

      II ( a, b, c, d, pInArray( 0+1), S41, TO_NUMBER('F4292244', 'XXXXXXXX')); -- 49
      II ( d, a, b, c, pInArray( 7+1), S42, TO_NUMBER('432AFF97', 'XXXXXXXX')); -- 50
      II ( c, d, a, b, pInArray(14+1), S43, TO_NUMBER('AB9423A7', 'XXXXXXXX')); -- 51
      II ( b, c, d, a, pInArray( 5+1), S44, TO_NUMBER('FC93A039', 'XXXXXXXX')); -- 52
      II ( a, b, c, d, pInArray(12+1), S41, TO_NUMBER('655B59C3', 'XXXXXXXX')); -- 53
      II ( d, a, b, c, pInArray( 3+1), S42, TO_NUMBER('8F0CCC92', 'XXXXXXXX')); -- 54
      II ( c, d, a, b, pInArray(10+1), S43, TO_NUMBER('FFEFF47D', 'XXXXXXXX')); -- 55
      II ( b, c, d, a, pInArray( 1+1), S44, TO_NUMBER('85845DD1', 'XXXXXXXX')); -- 56
      II ( a, b, c, d, pInArray( 8+1), S41, TO_NUMBER('6FA87E4F', 'XXXXXXXX')); -- 57
      II ( d, a, b, c, pInArray(15+1), S42, TO_NUMBER('FE2CE6E0', 'XXXXXXXX')); -- 58
      II ( c, d, a, b, pInArray( 6+1), S43, TO_NUMBER('A3014314', 'XXXXXXXX')); -- 59
      II ( b, c, d, a, pInArray(13+1), S44, TO_NUMBER('4E0811A1', 'XXXXXXXX')); -- 60
      II ( a, b, c, d, pInArray( 4+1), S41, TO_NUMBER('F7537E82', 'XXXXXXXX')); -- 61
      II ( d, a, b, c, pInArray(11+1), S42, TO_NUMBER('BD3AF235', 'XXXXXXXX')); -- 62
      II ( c, d, a, b, pInArray( 2+1), S43, TO_NUMBER('2AD7D2BB', 'XXXXXXXX')); -- 63
      II ( b, c, d, a, pInArray( 9+1), S44, TO_NUMBER('EB86D391', 'XXXXXXXX')); -- 64

         a := a + aOld;
         b := b + bOld;
         c := c + cOld;
         d := d + dOld;

               NormalizeToFourByteLength(a);
                        NormalizeToFourByteLength(b);
                        NormalizeToFourByteLength(c);
                        NormalizeToFourByteLength(d);

         ar.value := FourByteNumberToRaw(a);
         br.value := FourByteNumberToRaw(b);
         cr.value := FourByteNumberToRaw(c);
         dr.value := FourByteNumberToRaw(d);

   END Transform;



            FUNCTION ExtractDigestedMessage(
                        pN0 NUMBER,
                                                            pN1 NUMBER,
                                                            pN2 NUMBER,
                                                            pN3 NUMBER)
                                                            RETURN VARCHAR2 IS
               lTemp0 NUMBER;
                        lTemp1 NUMBER;
                        lTemp2 NUMBER;
                        lTemp3 NUMBER;

                        lRetVal VARCHAR2(200);
            BEGIN
               lRetVal := '';

      FourByteNumberToBytes(pN0, lTemp0, lTemp1, lTemp2, lTemp3);
      lRetVal := TO_CHAR(lTemp0,'0X') || TO_CHAR(lTemp1,'0X') || TO_CHAR(lTemp2,'0X') || TO_CHAR(lTemp3,'0X');
      FourByteNumberToBytes(pN1, lTemp0, lTemp1, lTemp2, lTemp3);
      lRetVal := lRetVal || TO_CHAR(lTemp0,'0X') || TO_CHAR(lTemp1,'0X') || TO_CHAR(lTemp2,'0X') || TO_CHAR(lTemp3,'0X');
      FourByteNumberToBytes(pN2, lTemp0, lTemp1, lTemp2, lTemp3);
      lRetVal := lRetVal || TO_CHAR(lTemp0,'0X') || TO_CHAR(lTemp1,'0X') || TO_CHAR(lTemp2,'0X') || TO_CHAR(lTemp3,'0X');
      FourByteNumberToBytes(pN3, lTemp0, lTemp1, lTemp2, lTemp3);
      lRetVal := lRetVal || TO_CHAR(lTemp0,'0X') || TO_CHAR(lTemp1,'0X') || TO_CHAR(lTemp2,'0X') || TO_CHAR(lTemp3,'0X');
                        RETURN lRetVal;

            END ExtractDigestedMessage;


   ----------------------------------------------------------------------------
   -- InitContext, UpdateContext, FinishContext
   ----------------------------------------------------------------------------


   PROCEDURE InitContext(pMdContext IN OUT MD5_CTX) IS
      zeroAsUINT4 RAW(4);
                        dummy NUMBER;
   BEGIN
               zeroAsUINT4 := HEXTORAW('0');
         NormalizeToFourByteLength(zeroAsUINT4);

                        pMdContext.i0.value := zeroAsUINT4;
                        pMdContext.i1.value := zeroAsUINT4;

                        pMdContext.buf0.value := zeroAsUINT4;
                        pMdContext.buf1.value := zeroAsUINT4;
                        pMdContext.buf2.value := zeroAsUINT4;
                        pMdContext.buf3.value := zeroAsUINT4;

      -- mdContext->i[0] = mdContext->i[1] = (UINT4)0;
      OperatorAssign(pMdContext.i0.value, zeroAsUINT4, 4);
         OperatorAssign(pMdContext.i1.value, zeroAsUINT4, 4);

         -- mdContext->buf[0] = (UINT4)0x67452301L;
         OperatorAssign(pMdContext.buf0.value, HEXTORAW('67452301'), 4);

         -- mdContext->buf[1] = (UINT4)0xefcdab89L;
      OperatorAssign(pMdContext.buf1.value, HEXTORAW('EFCDAB89'), 4);

      -- mdContext->buf[2] = (UINT4)0x98badcfeL;
         OperatorAssign(pMdContext.buf2.value, HEXTORAW('98BADCFE'), 4);

         -- mdContext->buf[3] = (UINT4)0x10325476L;
         OperatorAssign(pMdContext.buf3.value, HEXTORAW('10325476'), 4);

                        -- initialize gPadding
                        gPadding := CHR(128);
                        PadWithZeros(gPadding, 64, dummy);

   END InitContext;



   PROCEDURE UpdateContext(pMdContext IN OUT MD5_CTX, pInBuf IN OUT VARCHAR2, pInLen NUMBER) IS
      lMdContextI0 NUMBER;
         lMdContextI1 NUMBER;
         lInLen       NUMBER;
         lMdi         NUMBER;
         lCnt         NUMBER;
         ii           NUMBER;
         i            NUMBER;

         lInArray Number_Array;
         lChars   Varchar2_Array;

         lFirstByte  NUMBER;
         lSecondByte NUMBER;
         lThirdByte  NUMBER;
         lFourthByte NUMBER;
         lWholeValue NUMBER;

               lTemp NUMBER;
   BEGIN
      lInLen := pInLen;

      lMdContextI0 := RawToFourByteNumber(pMdContext.i0.value);
      lMdContextI1 := RawToFourByteNumber(pMdContext.i1.value);

      -- lMdi = (int)((mdContext->i[0] >> 3) AND 0x3F);
         lMdi := MOD(OperatorShiftRightUINT4(lMdContextI0, 3), 64);


      -- if ((mdContext->i[0] + ((UINT4)inLen << 3)) < mdContext->i[0])
         IF (lMdContextI0 + TRUNC(pInLen/8)) < lMdContextI0 THEN
            -- mdContext->i[1]++;
            lMdContextI1 := lMdContextI1 + 1;
         END IF;


      -- mdContext->i[0] += ((UINT4)inLen << 3);
      lMdContextI0 := lMdContextI0 + OperatorShiftLeftUINT4(pInLen, 3);

         --  mdContext->i[1] += ((UINT4)inLen >> 29);
         lMdContextI1 := lMdContextI1 + OperatorShiftRightUINT4(pInLen, 29);

         lCnt := 1;
         CopyVarchar2ToVarchar2_Array(lChars, 64, pMdContext.inBuf, 64);

         --  while (inLen--) {
         WHILE (lInLen > 0) LOOP
            lInLen := lInLen - 1;

            -- add new character to buffer, increment lMdi
            -- mdContext->in[lMdi++] = *inBuf++;
                                    lTemp := ASCII(SUBSTR(pInBuf, lCnt, 1));

            lChars(lMdi + 1) := SUBSTR(pInBuf, lCnt, 1);
               lCnt := lCnt + 1;
               lMdi := lMdi + 1;

               -- if (lMdi == 0x40) {
               IF (lMdi = 64) THEN
            -- for (i = 0, ii = 0; i < 16; i++, ii += 4)
                                 ii := 1;
                                                i:= 1;
               WHILE (i <= 16) LOOP
--             in[i] = (((UINT4)mdContext->in[ii+3]) << 24) |
--                     (((UINT4)mdContext->in[ii+2]) << 16) |
--                     (((UINT4)mdContext->in[ii+1]) << 8) |
--                     ((UINT4)mdContext->in[ii]);
               lFirstByte  := ASCII(lChars(ii + 3));
                        lSecondByte := ASCII(lChars(ii + 2));
                        lThirdByte  := ASCII(lChars(ii + 1));
                        lFourthByte := ASCII(lChars(ii + 0));

                        lWholeValue := OperatorShiftLeftUINT4(lFirstByte, 24) +
                                       OperatorShiftLeftUINT4(lSecondByte,16) +
                                                   OperatorShiftLeftUINT4(lThirdByte, 8) +
                                                   OperatorShiftLeftUINT4(lFourthByte,0);

               lInArray(i) := lWholeValue;
               ii := ii + 4;
                                                            i := i + 1;
                     END LOOP;

            -- Transform (mdContext->buf, in);
                     Transform(pMdContext.buf0, pMdContext.buf1, pMdContext.buf2, pMdContext.buf3, lInArray);

            -- lMdi = 0;
            lMdi := 0;
         -- }
               END IF;
      -- }
         END LOOP;

               -- back to pMdContext object
         CopyVarchar2_ArrayToVarchar2(pMdContext.inBuf, 64, lChars, 64);

         OperatorAssign(pMdContext.i0.value, FourByteNumberToRaw(lMdContextI0), 4);
                        OperatorAssign(pMdContext.i1.value, FourByteNumberToRaw(lMdContextI1), 4);

   END UpdateContext;



   PROCEDURE FinishContext(pMdContext IN OUT MD5_CTX) IS
      lMdContextI0 NUMBER;
         lMdContextI1 NUMBER;
      lPadLen      NUMBER;
         lMdi         NUMBER;
                        ii           NUMBER;
                        i            NUMBER;

         lFirstByte  NUMBER;
         lSecondByte NUMBER;
         lThirdByte  NUMBER;
         lFourthByte NUMBER;
         lWholeValue NUMBER;

                        lMdContextBuf0 NUMBER;
                        lMdContextBuf1 NUMBER;
                        lMdContextBuf2 NUMBER;
                        lMdContextBuf3 NUMBER;

         lInArray Number_Array;

                        lChars Varchar2_Array;

                        lChar VARCHAR2(200);
                        lRaw  RAW(20);
   BEGIN
      lMdContextI0 := RawToFourByteNumber(pMdContext.i0.value);
         lMdContextI1 := RawToFourByteNumber(pMdContext.i1.value);

      -- in[14] = mdContext->i[0];
      lInArray(15) := lMdContextI0;

      -- in[15] = mdContext->i[1];
         lInArray(16) := lMdContextI1;

      -- lMdi = (int)((mdContext->i[0] >> 3) AND 0x3F);
         lMdi := MOD(OperatorShiftRightUINT4(lMdContextI0, 3), 64);

      -- padLen = (lMdi < 56) ? (56 - lMdi) : (120 - lMdi);
         IF (lMdi < 56) THEN
            lPadLen := 56 - lMdi;
         ELSE
            lPadLen := 120 - lMdi;
         END IF;

         -- MD5Update (pMdContext, PADDING, padLen);
         UpdateContext(pMdContext, gPadding, lPadLen);

         -- for (i = 0, ii = 0; i < 14; i++, ii += 4)
         ii := 1;
                        i := 1;
         WHILE (i <= 14) LOOP
         -- in[i] = (((UINT4)mdContext->in[ii+3]) << 24) |
                 -- (((UINT4)mdContext->in[ii+2]) << 16) |
                 -- (((UINT4)mdContext->in[ii+1]) << 8) |
                 -- ((UINT4)mdContext->in[ii]);
         lFirstByte  := ASCII(SUBSTR(pMdContext.inBuf, ii + 3, 1));
            lSecondByte := ASCII(SUBSTR(pMdContext.inBuf, ii + 2, 1));
         lThirdByte  := ASCII(SUBSTR(pMdContext.inBuf, ii + 1, 1));
         lFourthByte := ASCII(SUBSTR(pMdContext.inBuf, ii + 0, 1));
         -- DS 15/07/2003 IN0349 - If first time through, hard code fourth byte to
         --                        be 128 (ascii). Fixes 8i to 9i migration problem - START
         If i = 1 And lFourthByte = 0 Then
            lFourthByte := 128;
         End If;
         -- DS 15/07/2003 IN0349 - If first time through, hard code fourth byte to
         --                        be 128 (ascii). Fixes 8i to 9i migration problem - END

         lWholeValue := OperatorShiftLeftUINT4(lFirstByte, 24) +
                                 OperatorShiftLeftUINT4(lSecondByte,16) +
                                 OperatorShiftLeftUINT4(lThirdByte, 8)  +
                                       OperatorShiftLeftUINT4(lFourthByte,0);

         lInArray(i) := lWholeValue;

            ii := ii + 4;
                                    i := i + 1;
         END LOOP;

                        -- Transform (mdContext->buf, in);
                        Transform(pMdContext.buf0, pMdContext.buf1, pMdContext.buf2, pMdContext.buf3, lInArray);

                        lMdContextBuf0 := RawToFourByteNumber(pMdContext.buf0.value);
                        lMdContextBuf1 := RawToFourByteNumber(pMdContext.buf1.value);
                        lMdContextBuf2 := RawToFourByteNumber(pMdContext.buf2.value);
                        lMdContextBuf3 := RawToFourByteNumber(pMdContext.buf3.value);

                          pMdContext.digest := REPLACE(ExtractDigestedMessage(
                                          lMdContextBuf0,
                                                                                                                                                                        lMdContextBuf1,
                                                                                                                                                                        lMdContextBuf2,
                                                                                                                                                                        lMdContextBuf3),' ','');
/*
                        lRaw := UTL_RAW.CAST_TO_RAW(lChar);
                        pMdContext.digest := RAWTOHEX(lRaw);
*/
   END FinishContext;


   FUNCTION  Encrypt (pInput IN VARCHAR2, pOutput IN OUT VARCHAR2) RETURN NUMBER IS
      lCtx  MD5_CTX;
                        lInput VARCHAR2(130);
         dummy NUMBER;
                        lRaw  RAW(32);
   BEGIN
      lInput := pInput;
                        PadWithZeros(lInput, 128, dummy);
      InitContext(lCtx);
      UpdateContext(lCtx, lInput, 128);
         FinishContext(lCtx);

                        pOutput := lCtx.digest;

                        --dbms_output.put_line('pOutput = ' || pOutput);
      RETURN 1;
   END Encrypt;



   FUNCTION Encrypt(pInput IN VARCHAR2) RETURN VARCHAR2 IS
      lOutput VARCHAR2(35);
         dummy NUMBER;

   BEGIN
      dummy := Encrypt(pInput, lOutput);
         RETURN lOutput;
   END Encrypt;

END md5_encrypting;
/
