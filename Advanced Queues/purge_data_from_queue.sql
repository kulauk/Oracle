-- To purge a single message from a queue you need to specify a filter
-- using the purge_condition.  The filter must have qtview as a qualifier.
-- The column msg_id comes from the VIEW of the queuetable not the queuetable itself.
-- so eg find the primary key msg_id and set that in the purge command as below: 
-- the delivery mode will purge both persistent AND buffered... if you dont specify this
-- then the default is just persistent which your queue might not be.
-- if the command doesn't affect any data then no errors are raised so its hard to see what it actually did.



DECLARE
po dbms_aqadm.aq$_purge_options_t;
BEGIN
   po.block := FALSE;
   po.delivery_mode := DBMS_AQADM.PERSISTENT_OR_BUFFERED;
   DBMS_AQADM.PURGE_QUEUE_TABLE(
     queue_table     => 'RT_REP.QUEUETABLE_SBTRANS_BET',
     purge_condition => 'qtview.msg_id = ''DB2D60FE546E4C7AE0400B0A0E236802''',
     purge_options   => po);
END;
/

-- to purge all data then don't specify a condition but do specify the delivery mode