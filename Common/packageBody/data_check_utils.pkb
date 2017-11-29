CREATE OR REPLACE PACKAGE BODY common.data_check_utils
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


   --==========================================================================
   --
   --      PRIVATE PROCEDURES AND FUNCTIONS
   --
   --==========================================================================
   --==========================================================================
   -- Function to return the package name (to avoid storing state in the package body)
   -- .......
   FUNCTION get_package_name
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN 'DATA_CHECK_UTILS';
   END get_package_name;
   --==========================================================================
   -- Function to return the package name (to avoid storing state in the package body)
   -- .......
   FUNCTION get_context
      RETURN VARCHAR2
   IS
   BEGIN
      RETURN NULL;
   END get_context;
   --==========================================================================
   --  
   -- .......
   PROCEDURE get_data_for_validation ( p_unique_id       IN NUMBER, 
                                       p_data_source     IN VARCHAR2,
                                       p_col_name        IN VARCHAR2, 
                                       p_col_datatype    IN VARCHAR2,
                                       po_source_data       OUT VARCHAR2,
                                       po_target_data       OUT VARCHAR2) 
   IS
      l_sql                VARCHAR2(2000);
      l_source_data        VARCHAR2(2000);
      l_target_data        VARCHAR2(2000);
      --===========================================================================
      PROCEDURE set_sql_cmd
      IS
      BEGIN
         -- set base query
         l_sql := 'SELECT  source_data,
                           target_data
                  FROM (         
                           SELECT   ROW_NUMBER() OVER (ORDER BY source) AS rn,  
                                    source,
                                    [[COLUMN_NAME]] AS source_data, 
                                    LEAD([[COLUMN_NAME]], 1, NULL) OVER (ORDER BY source) AS target_data
                           FROM [[DATA_SOURCE]]
                           WHERE unique_id = :p_unique_id
                           )
                  WHERE rn = 1';          
         
         -- add data source, column name to sql cmd
         l_sql := REPLACE(l_sql, '[[DATA_SOURCE]]', p_data_source);
         l_sql := REPLACE(l_sql, '[[COLUMN_NAME]]', p_col_name);
            
         pkg_app_manager.p_trace (p_level => 1, p_name => 'l_sql = :', p_text => l_sql);
         
      END set_sql_cmd;
      --===========================================================================
      PROCEDURE fetch_data
      IS       
         l_source_data_VARCHAR   VARCHAR2(2000); 
         l_target_data_VARCHAR   VARCHAR2(2000);

         l_source_data_NUMBER    NUMBER; 
         l_target_data_NUMBER    NUMBER;

         l_source_data_DATE      DATE; 
         l_target_data_DATE      DATE;                 
      BEGIN   
         CASE p_col_datatype
         WHEN data_check_types.c_data_type_varchar THEN
         
            EXECUTE IMMEDIATE l_sql INTO l_source_data_VARCHAR, l_target_data_VARCHAR USING p_unique_id;
            l_source_data := l_source_data_VARCHAR;
            l_target_data := l_target_data_VARCHAR;
         
         WHEN data_check_types.c_data_type_number THEN
         
            EXECUTE IMMEDIATE l_sql INTO l_source_data_NUMBER, l_target_data_NUMBER USING p_unique_id;
            l_source_data := TO_CHAR(l_source_data_NUMBER);
            l_target_data := TO_CHAR(l_target_data_NUMBER);
         
         WHEN data_check_types.c_data_type_date THEN
         
            EXECUTE IMMEDIATE l_sql INTO l_source_data_DATE, l_target_data_DATE USING p_unique_id;
            l_source_data := TO_CHAR(l_source_data_DATE, data_check_types.c_date_format);
            l_target_data := TO_CHAR(l_target_data_DATE, data_check_types.c_date_format);
         END CASE;            
         
         pkg_app_manager.p_trace (p_level => 3, p_name => 'l_source_data = :', p_text => l_source_data);
         pkg_app_manager.p_trace (p_level => 3, p_name => 'l_target_data = :', p_text => l_target_data);
         
      END fetch_data;         
      --===========================================================================
      --===========================================================================
   BEGIN
      pkg_app_manager.p_trace (p_level => 1, p_name => 'START:', p_text => 'get_data_for_validation');
      
      set_sql_cmd;
      fetch_data;

      po_source_data := l_source_data;
      po_target_data := l_target_data;
      
   END get_data_for_validation;
   --===========================================================================
   FUNCTION is_equal (  p_source_data  IN VARCHAR2,
                        p_target_data  IN VARCHAR2)
   RETURN BOOLEAN
   IS
      l_result  BOOLEAN;
   BEGIN    
      
      IF NVL(p_source_data, '[[DUMMY_VALUE]]') <> NVL(p_target_data, '[[DUMMY_VALUE]]')
      THEN
         l_result := FALSE;            
      ELSE
         l_result := TRUE;
      END IF;
      
      RETURN l_result;                
   END is_equal;                                                     
   --==========================================================================
   -- End of PRIVATE PROCEDURES AND FUNCTIONS
   --==========================================================================


   --==========================================================================
   --
   --      PUBLIC PROCEDURES AND FUNCTIONS
   --
   --==========================================================================
   --  
   -- .......
   PROCEDURE validate_data (  p_unique_id       IN NUMBER, 
                              p_data_source     IN VARCHAR2,
                              p_col_name        IN VARCHAR2, 
                              p_col_datatype    IN VARCHAR2,
                              po_is_data_equal     OUT BOOLEAN,
                              po_source_data       OUT VARCHAR2,
                              po_target_data       OUT VARCHAR2)                                 
   IS
      l_result       BOOLEAN;
      l_source_data  VARCHAR2(2000);
      l_target_data  VARCHAR2(2000);
         
      l_procfunc_name VARCHAR2(30) := 'VALIDATE_DATA';
   BEGIN
      -- call procedure to start the trace.
      -- Pass the client id to identify exactly your instance of tracing
      -- pass the config id of the entry in the trace_config table which needs to exist in order for tracing to work
      pkg_app_manager.p_trace_start (p_client_id => p_col_name, p_package_name => get_package_name, p_procedure_name => l_procfunc_name);
   
      pkg_app_manager.p_trace (p_level => 1, p_name => 'p_unique_id = :', p_text => p_unique_id);
      pkg_app_manager.p_trace (p_level => 1, p_name => 'p_data_source = :', p_text => p_data_source);
      pkg_app_manager.p_trace (p_level => 1, p_name => 'p_col_name = :', p_text => p_col_name);
      pkg_app_manager.p_trace (p_level => 1, p_name => 'p_col_datatype = :', p_text => p_col_datatype);
      
      -- call procedure to fetch the source and target data for this column 
      -- from table data source
      get_data_for_validation (  p_unique_id    => p_unique_id, 
                                 p_data_source  => p_data_source, 
                                 p_col_name     => p_col_name, 
                                 p_col_datatype => p_col_datatype,
                                 po_source_data => l_source_data,
                                 po_target_data => l_target_data);
                           
      -- call function to validate if the source and target data are equal or not
      IF is_equal(l_source_data, l_target_data) THEN
         -- if equal then set result only 
         pkg_app_manager.p_trace (p_level => 5, p_name => 'Data IS equal....', p_text => 'continue');
         l_result := TRUE;
      ELSE
         pkg_app_manager.p_trace (p_level => 5, p_name => 'Data is NOT equal....');
         -- if not equal then format the source and target data into a string
         l_result := FALSE;         
      END IF;         
         
      po_is_data_equal := l_result;
      po_source_data := l_source_data;
      po_target_data := l_target_data;
      
      pkg_app_manager.p_trace_end;
                   
   END validate_data; 
   --=====================================================
   -- END OF Public procedures
   --=====================================================

------------------
--................

BEGIN
   NULL;
END data_check_utils;
/
