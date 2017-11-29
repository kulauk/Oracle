
-- use this to find out what hints you need to create the same execution plan
-- when you run this the results will contain outline date eg

--Outline Data                                                                                                                                                                                                                                                                                                
---------------                                                                                                                                                                                                                                                                                               
--
--  /*+                                                                                                                                                                                                                                                                                                       
--      BEGIN_OUTLINE_DATA                                                                                                                                                                                                                                                                                    
--      USE_NL(@"SEL$5DA710D3" "EM2"@"SEL$2")                                                                                                                                                                                                                                                                 
--      LEADING(@"SEL$5DA710D3" "EM"@"SEL$1" "EM2"@"SEL$2")                                                                                                                                                                                                                                                   
--      INDEX_RS_ASC(@"SEL$5DA710D3" "EM2"@"SEL$2" ("SBEVENT_MESSAGE"."IDSBEVENT"))                                                                                                                                                                                                                           
--      INDEX_RS_ASC(@"SEL$5DA710D3" "EM"@"SEL$1" ("SBEVENT_MESSAGE"."PROCESSEDID"))                                                                                                                                                                                                                          
--      OUTLINE(@"SEL$2")                                                                                                                                                                                                                                                                                     
--      OUTLINE(@"SEL$1")                                                                                                                                                                                                                                                                                     
--      UNNEST(@"SEL$2")                                                                                                                                                                                                                                                                                      
--      OUTLINE_LEAF(@"SEL$5DA710D3")                                                                                                                                                                                                                                                                         
--      ALL_ROWS                                                                                                                                                                                                                                                                                              
--      DB_VERSION('11.2.0.1')                                                                                                                                                                                                                                                                                
--      OPTIMIZER_FEATURES_ENABLE('11.2.0.1')                                                                                                                                                                                                                                                                 
--      IGNORE_OPTIM_EMBEDDED_HINTS                                                                                                                                                                                                                                                                           
--      END_OUTLINE_DATA                                                                                                                                                                                                                                                                                      
--  */                                                                                                                                                                                                                                                                                                        


set lines 400
set pages 50000
set time on
set timing on
--set autotrace traceonly

explain plan
set statement_id = 'sj_hinted'
for
 SELECT         
        idsbevent, sequence_id
       FROM sbevent_message em
      WHERE     processedid = 0
            AND ROWNUM <= 20000
            AND NOT EXISTS
                       (SELECT 1 
                          FROM spin_d.sbevent_message em2
                         WHERE     em2.idsbevent = em.idsbevent
                               AND (    em2.processedid <> 0
                                    AND em2.processeddate IS NOT NULL)
                               AND em2.enqueuetimestamp > em.enqueuetimestamp)
   ORDER BY enqueuetimestamp ASC;
   
select * from table(dbms_xplan.display(null,'sj_hinted','outline'));   


-- now can check the OUTLINE DATA in the results and see what hints are needed to recreate your plan