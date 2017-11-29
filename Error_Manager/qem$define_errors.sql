/*
| This program is a part of the Quest Error Manager for Oracle.
| This product is freeware and is not supported by Quest.
|
| You may copy and change the data in these statements to meet
| your own application-specific requirements. That is, you can
| define your own errors in this script.
|
| www.quest.com
| 
| Copyright, Quest Software, Inc, 2007
| All rights reserved
*/

DECLARE
   c_support            CONSTANT  VARCHAR2(32767) := 'Please contact support on 01392 251289';
   c_recommendation     CONSTANT  VARCHAR2(32767) := 'An unexpected error has occured please contact the helpdesk on 01392 251289 quoting the following id: ';
   PROCEDURE ins(error_category_name_in  IN VARCHAR2
               , code_in                 IN NUMBER DEFAULT NULL
               , NAME_IN                 IN VARCHAR2 DEFAULT NULL
               , description_in          IN VARCHAR2 DEFAULT NULL
               , substitute_string_in    IN VARCHAR2 DEFAULT NULL
               , recommendation_in       IN VARCHAR2 DEFAULT NULL )
   IS
   BEGIN
      INSERT INTO q$error(
                             id
                           , error_category_name
                           , code
                           , name
                           , description
                           , substitute_string
                           , recommendation
                           , created_on
                           , created_by                           
                 )
      VALUES     (
                     q$error_seq.NEXTVAL
                   , error_category_name_in
                   , code_in
                   , NAME_IN
                   , description_in
                   , substitute_string_in
                   , recommendation_in
                   , SYSDATE
                   , 'QEM$DEFINE_ERRORS'
                 );
   EXCEPTION
      WHEN DUP_VAL_ON_INDEX
      THEN
         /* Running install over existing install. Just ignore. */
         NULL;
   END ins;
   
   
BEGIN

    -- set up your APP FATAL ERRORS -- these are errors you raise yourself explicitly but
    -- you want them to register as FATAL so that the GUI will stop and show a fatal  error 
    -- handling page asking the user to contact the helpdesk.


/***********************************************************************************
  	The following are standard errors that you may want to use.  You will need to set
	up pkg_constants with these error codes first.
************************************************************************************

   ins(
      error_category_name_in  => 'APP FATAL ERRORS'
    , code_in                 => (20000 + pkg_constants.gc_err_app_error) * -1
    , NAME_IN                 => 'JAVA APP ERROR'
    , description_in          => 'A fatal error has been raised explicitly by the application due to an error raised in the application layer'
    , recommendation_in       => c_recommendation
    , substitute_string_in    => ''
   );   

   ins(
      error_category_name_in  => 'APP FATAL ERRORS'
    , code_in                 => (20000 + pkg_constants.gc_err_no_data_found) * -1
    , NAME_IN                 => 'DATA MISSING ERROR'
    , description_in          => 'A fatal error has been raised explicitly by the application due to missing data'
    , recommendation_in       => c_recommendation
    , substitute_string_in    => ''
   );   

   ins(
      error_category_name_in  => 'APP FATAL ERRORS'
    , code_in                 => (20000 + pkg_constants.gc_err_invalid_sort_col) * -1
    , NAME_IN                 => 'INVALID SORT COLUMN'
    , description_in          => 'A fatal error has been raised explicitly by the application due to an invalid sort column passed in'
    , recommendation_in       => c_recommendation
    , substitute_string_in    => ''
   );   

   ins(
      error_category_name_in  => 'APP FATAL ERRORS'
    , code_in                 => (20000 + pkg_constants.gc_err_invalid_sort_dir) * -1
    , NAME_IN                 => 'INVALID SORT DIRECTION'
    , description_in          => 'A fatal error has been raised explicitly by the application due to an invalid sort direction passed in'
    , recommendation_in       => c_recommendation
    , substitute_string_in    => ''
   );   


   ins(
      error_category_name_in  => 'APP FATAL ERRORS'
    , code_in                 => (20000 + pkg_constants.gc_err_validation) * -1
    , NAME_IN                 => 'VALIDATION ERROR'
    , description_in          => 'A fatal error has been raised explicitly by the application due to a validation error'
    , recommendation_in       => c_recommendation
    , substitute_string_in    => ''
   );   


   ins(
      error_category_name_in  => 'APP FATAL ERRORS'
    , code_in                 => (20000 + pkg_constants.gc_err_invalid_parameter) * -1
    , NAME_IN                 => 'INVALID PARAMETER'
    , description_in          => 'A fatal error has been raised explicitly by the application due to an invalid parameter'
    , recommendation_in       => c_recommendation
    , substitute_string_in    => ''
   );   
 
   

    -- set up your APPLICATION ERRORS -- these are errors you raise yourself explicitly but
    -- you want them to register as non fatal APPLICATION ERRORS so that the GUI will NOT stop and  
    -- will just ask the user how to handle and resolve this error...then continue as normal.

   ins(
      error_category_name_in  => 'APPLICATION ERRORS'
    , code_in                 =>  (20000 + pkg_constants.gc_err_lock_row_modified) * -1
    , NAME_IN                 => 'ROW MODIFIED'
    , description_in          => 'A row that is being saved has been modified by another user'
    , recommendation_in       => 'Your data has been modified by another user please refresh the page and resubmit your update'
    , substitute_string_in    => ''
   );   

**********************************************************************************************************************/

    -- These are the QUEST supplied errors....

   ins(
      error_category_name_in  => 'GENERAL ADMINISTRATION'
    , code_in                 => 10000001
    , NAME_IN                 => 'ASSERTION-FAILURE'
    , description_in          => 'This exception is raised when you:
*  call q$error_manager.assert
* pass it a Boolean expression that evaluates to FALSE or NULL
* and do not provide a specific error code or name to be raised for you.
There are no pre-defined context values used in the error message. Instead, if you set any name-value pairs when you call q$error_manager.assert, these will be displayed.'
    , recommendation_in       => ''
    , substitute_string_in    => 'The Boolean expression provided evaluated to FALSE or NULL. The condition checked by the assertion program has failed.'
   );
   ins(
      error_category_name_in  => 'GENERAL ADMINISTRATION'
    , code_in                 => 10000003
    , NAME_IN                 => 'DEPRECATED-FUNCTIONALITY'
    , description_in          => 'The user tried to run a program that has been deprecated.'
    , recommendation_in       => 'This is NOT a user error. ' || c_support
    , substitute_string_in    => 'The application attempted to run a program named "$program_name" that has been deprecated; that is, it is no longer available and should not be executed.'
   );
   ins(error_category_name_in  => 'GENERAL ADMINISTRATION'
     , code_in                 => 10000000
     , NAME_IN                 => 'NOEXCEPTION'
     , description_in          => 'No exception has been raised.'
     , recommendation_in       => ''
     , substitute_string_in    => c_support);
   ins(
      error_category_name_in  => 'GENERAL ADMINISTRATION'
    , code_in                 => 10000002
    , NAME_IN                 => 'UNANTICIPATED-ERROR'
    , description_in          => 'This exception should be used in a PL/SQL WHEN OTHERS clause or other similar ''catch all'' handler for errors. You could not in advance know that this error was raised, and therefore could not handle it specifically. Instead, you will pass as much information possible and hope that the user or tester can figure out the problem.'
    , recommendation_in       => 'If you cannot figure out the cause of the difficulty, ' || c_support
    , substitute_string_in    => 'An unanticipated error has occurred. Please review the information below and see if it will help you resolve the problem.'
   );
   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => -2290
    , NAME_IN                 => 'CHECK-CONSTRAINT-FAILURE'
    , description_in          => 'A check constraint failed.'
    , recommendation_in       => 'Determine the logic of the constraint and change the data so that it will not fail.'
    , substitute_string_in    => 'The constaint named $constaint_name, defined on table $table_name and owned by $owner, failed. This means that a rule that was defined on this table was violated in the process of inserting or updating a row of data.'
   );
   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => -1400
    , NAME_IN                 => 'COLUMN-CANNOT-BE-NULL'
    , description_in          => 'The column has been defined to be NOT NULL, yet a DML operation attempted to set it to NULL.'
    , recommendation_in       => 'If you can change the value to something that is not blank, do so. If this is not under your control, '
                                || c_support
    , substitute_string_in    => 'You have tried to set the column $COLUMN_NAME of table $OWNER.$TABLE_NAME to NULL or a blank line; this is not allowed.'
   );

--   /* V1.2.11 Error number is changed to -1. Remove existing row. */
--   DELETE FROM   q$error
--   WHERE         name = 'DUPLICATE-VALUE';

   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => -1
    , NAME_IN                 => 'DUPLICATE-VALUE'
    , description_in          => 'A duplicate value on index error (ORA-00001) was raised for an insert or update'
    , recommendation_in       => 'This means that either the primary key is a repeated value, which is almost certainly a software error, or you are repeating a value in a column that must be unique. For example, in many applications the NAME will be unique. Perhaps you entered a name that is already in use.'
    , substitute_string_in    => 'We tried to insert or update a row of data, and ran into the following problem: at least one of the values are already in the database and you are not allowed to have duplicates.
This error occurred on the table named $table_name, which is owned by $owner. The name of this unique constraint is $constraint_name. In some cases, we may be able to also display the columns and values that triggered the conflict. If available, they follow below.'
   );
   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => -2266
    , NAME_IN                 => 'EXISTING-FKY-REFERENCE'
    , description_in          => 'An DROP TABLE, TRUNCATE TABLE or DELETE statement attempted to remove a row in which the primary key or unique values are referenced by the foreign key value in another table.'
    , recommendation_in       => c_support
    , substitute_string_in    => 'We were unable to remove a row from table $owner.$table because it contains a primary key or unique value that is referenced by the foreign key value in another table.'
   );
   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => -24381
    , NAME_IN                 => 'FORALL-INSERT-FAILURE'
    , description_in          => 'An error occurred while performing a bulk insert operation.'
    , recommendation_in       => ''
    , substitute_string_in    => 'An attempt to perform a FORALL on table $TABLE_NAME failed. The incoming array had $ROW_COUNT'' rows in it. The last action taken during that procedure''s execution was:
$PROGRESS_INDICATOR'
   );
   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => -2291
    , NAME_IN                 => 'INTEGRITY-CONSTRAINT-FAILURE'
    , description_in          => 'An integrity constraint (primary key, foreign key, etc.) failed.'
    , recommendation_in       => 'Make sure that you are entering data correctly. If that seems to be the case, '
                                || c_support
    , substitute_string_in    => 'The constraint named $constraint_name, defined on table $table_name and owned by $owner, failed.'
   );
   ins(
      error_category_name_in  => 'QDA DML ERRORS'
    , code_in                 => 10010008
    , NAME_IN                 => 'SEQUENCE-GENERATION-FAILURE'
    , description_in          => 'An attempt to generate a sequence with the next primary key function resulted in failure.'
    , recommendation_in       => 'Make sure the sequence exists and that you have the authority necessary (SELECT) to obtain the next value from this sequence.'
    , substitute_string_in    => 'An attempt to obtain the next sequence value from $sequence failed.'
   );


   
   COMMIT;
END;
/
