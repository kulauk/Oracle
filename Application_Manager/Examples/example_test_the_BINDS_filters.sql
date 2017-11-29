variable rc0_PO_RESULTS_CUR refcursor
set autoprint on
set serveroutput on

DECLARE
    p_id                     NUMBER;
    p_id_array               VARCHAR2( 32767 );
    p_description_filter     VARCHAR2( 32767 );
    p_plsql_constant_filter  VARCHAR2( 32767 );
    po_results_cur           sys_refcursor;
BEGIN
    -- set whatever parameters you like here
    p_id                       := '';
    p_id_array                 := '210|211';
    p_description_filter       := 'Invalid';
    p_plsql_constant_filter    := '';

    dulu.p_example_set_filters_binds( p_id, p_id_array, p_description_filter, p_plsql_constant_filter, po_results_cur );

    :rc0_po_results_cur        := po_results_cur;

    COMMIT;
END;