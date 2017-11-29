--DROP TYPE common.obj_emailpayload;

CREATE OR REPLACE TYPE common.obj_emailpayload AS OBJECT
(
   groupid NUMBER,
   messagetype VARCHAR2 (100),
   attributename VARCHAR2 (100),
   attributevalue VARCHAR2 (100),
   columnorder NUMBER
)
/