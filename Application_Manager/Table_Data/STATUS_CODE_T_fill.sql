DELETE FROM status_code_t;

--==============================================================================
-- Standard error codes  0 - 99
--..............................................................................

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 0, 'Successful', 'gc_successful' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 1, 'Fatal Error', 'gc_ferr_fatal_error' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 2, 'JAVA FATAL application error', 'gc_ferr_app_error' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 3, 'JAVA NON FATAL application error', 'gc_err_app_error' );

--==============================================================================
-- General errors of type: FATAL 100 - 199
--..............................................................................

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 100, 'Row has been modified', 'gc_ferr_lock_row_modified' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 101, 'Assertion: FATAL', 'gc_ferr_assertion' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 102, 'Validation error', 'gc_ferr_validation' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 103, 'Missing data error', 'gc_ferr_missing_data' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 104, 'Duplicate data error', 'gc_ferr_duplicate_data' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 105, 'Invalid record status', 'gc_ferr_invalid_record_status' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 106, 'Out of Range', 'gc_ferr_out_of_range' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 107, 'Invalid parameter', 'gc_ferr_invalid_parameter' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 108, 'Invalid date range', 'gc_ferr_invalid_date_range' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 109, 'Invalid date', 'gc_ferr_invalid_date' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 110, 'Invalid number', 'gc_ferr_invalid_number' );


--==============================================================================
-- General errors of type: NON-FATAL ( Application errors )  200 - 299
--..............................................................................

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 200, 'Row has been modified', 'gc_err_lock_row_modified', 'Your data has been modified by another user please refresh the page and resubmit your update' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 201, 'Assertion: NON FATAL', 'gc_err_assertion', 'An error occured, please try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 202, 'Validation error', 'gc_err_validation', 'Validation failed, please try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 203, 'Missing data error', 'gc_err_missing_data', 'Mandatory data missing, please try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 204, 'Duplicate data error', 'gc_err_duplicate_data', 'Duplicate data found, please try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 205, 'Invalid record status', 'gc_err_invalid_record_status', 'Your record is in an invalid state. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 206, 'Out of Range', 'gc_err_out_of_range', 'Data is out of range. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 207, 'Invalid parameter', 'gc_err_invalid_parameter', 'Invalid parameter found. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 208, 'Invalid sort column', 'gc_err_invalid_sort_col', 'Invalid sort column. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 209, 'Invalid sort direction', 'gc_err_invalid_sort_dir', 'Invalid sort direction. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 210, 'Invalid date range', 'gc_err_invalid_date_range', 'Invalid date range. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 211, 'Invalid date', 'gc_err_invalid_date', 'Invalid date found. Please correct and try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 212, 'Invalid number', 'gc_err_invalid_number', 'Invalid number found. Please correct and try again' );


--==============================================================================
-- Session errors:  500 - 599
--..............................................................................
-- FATAL errors:

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 500, 'Use Login Code not unique', 'gc_ferr_non_unique_login_code' );


INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 501, 'MASTER/SLAVE error', 'gc_ferr_master_slave' );

-- NON-FATAL errors:

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 550, 'Invalid database Session', 'gc_err_invalid_db_session', 'Invalid database session. Please login again' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 551, 'Password expired error', 'gc_err_pwd_expired' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 552, 'Session has expired', 'gc_err_expired_db_session', 'Your session has expired. Please login again' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 553, 'Session has been locked', 'gc_err_user_locked_out' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 554, 'Invalid user account status', 'gc_err_invalid_account_status' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 555, 'Invalid password format', 'gc_err_invalid_password_format' );

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 556, 'User identifier / User password conflict', 'gc_err_invalid_user_or_pwd', 'Invalid username or password. Please try again' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 557, 'MASTER/SLAVE error', 'gc_err_master_slave' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 558, 'SYSTEM STATUS IS CLOSED', 'gc_err_system_status_closed' );


--==============================================================================
-- Download manager errors:  600 - 699
--..............................................................................
-- FATAL errors:

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 600, 'Invalid download id', 'gc_ferr_invalid_download_id' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 601, 'Invalid download status id', 'gc_ferr_invalid_status_id' );

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 602, 'Invalid download data arrays', 'gc_ferr_invalid_dload_arrays' );


-- NON-FATAL errors:

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 650, 'Download error', 'gc_err_download_error', 'An error occured during download. Please try again.' );



--==============================================================================
-- Email manager errors:  700 - 799
--..............................................................................
-- FATAL errors:

INSERT INTO status_code_t( id, description, plsql_constant_name )
VALUES ( 700, 'Failed to send email', 'gc_ferr_email_failed_send' );


-- NON-FATAL errors:

INSERT INTO status_code_t( id, description, plsql_constant_name, qem_recommendation )
VALUES ( 750, 'Failed to send email', 'gc_err_email_failed_send', 'An error occured whilst sending the email. Please try again.' );

--==============================================================================
--==============================================================================
COMMIT;
