--BEGIN
--  SYS.DBMS_SCHEDULER.DROP_SCHEDULE
--    (schedule_name  => 'COMMON.ONEMINSCHEDULE');
--END;
--/

BEGIN
  SYS.DBMS_SCHEDULER.CREATE_SCHEDULE
    (
      schedule_name    => 'COMMON.ONEMINSCHEDULE'
     ,start_date       => TO_TIMESTAMP_TZ('2016/04/01 13:08:17.000000 +00:00','yyyy/mm/dd hh24:mi:ss.ff tzr')
     ,repeat_interval  => 'freq=minutely;interval=1'
     ,end_date         => NULL
     ,comments         => 'oneminschedule'
    );
END;
/


--BEGIN
--  DBMS_SCHEDULER.DROP_PROGRAM
--    (program_name          => 'COMMON.PROGRAM_ERROR_ALERT');
--END;
--/

BEGIN
  SYS.DBMS_SCHEDULER.CREATE_PROGRAM
    (
      program_name         => 'COMMON.PROGRAM_ERROR_ALERT'
     ,program_type         => 'STORED_PROCEDURE'
     ,program_action       => 'COMMON.ERROR_UTILS.SEND_EMAIL_ALERT'
     ,number_of_arguments  => 0
     ,enabled              => FALSE
     ,comments             => 'PROGRAM TO CHECK ERROR TABLE AND SEND ALERTS'
    );

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'COMMON.PROGRAM_ERROR_ALERT');
END;
/


--
--BEGIN
--  SYS.DBMS_SCHEDULER.DROP_JOB
--    (job_name  => 'COMMON.JOB_ERROR_ALERT');
--END;
--/

BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'COMMON.JOB_ERROR_ALERT'
      ,schedule_name   => 'COMMON.ONEMINSCHEDULE'
      ,program_name    => 'COMMON.PROGRAM_ERROR_ALERT'
      ,comments        => 'JOB TO CHECK FOR ERROR ALERTS'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'COMMON.JOB_ERROR_ALERT'
     ,attribute => 'AUTO_DROP'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'COMMON.JOB_ERROR_ALERT');
END;
/
