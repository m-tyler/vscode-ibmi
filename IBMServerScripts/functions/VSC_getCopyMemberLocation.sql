/*============================================================================ 
   SPECIFIC NAME..: VCS000FN10                                                 
   FUNCTION NAME..: VSC_getCopyMemberLocation                                          
   AUTHOR.........: Matt Tyler                                                 
   DATE...........: 06/07/2022                                                 
   PCR #..........: XXXXX 00                                                   
   FUNCTION/DESC..: Return list of objects checked out to PCR                  
                                                                               
  ---------------------------------------------------------------------------- 
     MODIFICATIONS:                                                            
  ---------------------------------------------------------------------------- 
   MOD#  PCR     PGMR   DATE   DESCRIPTION                                     
  ============================================================================*/
;cl:chgcurlib ILEDITOR;
;set current path ILEDITOR, SYSTEM PATH
-- ;cl:chgcurlib [USER];
-- ;set path [USER]
-- ;select * from LIBRARY_LIST_INFO
 
;create or replace function VSC_getCopyMemberLocation 
(
    IN_FILE char(10)
   ,IN_MBR char(10)
)
returns char(10)
 specific VCS000FN10
 language sql
 deterministic
 returns null on null input
set option  alwblk = *ALLREAD ,
            alwcpydta = *OPTIMIZE ,
            datfmt = *ISO,
            commit = *NONE ,
            dbgview = *SOURCE ,
            decresult = (31, 31, 00) ,
            dftrdbcol = *NONE ,
            dyndftcol = *NO ,
            dynusrprf = *USER ,
            srtseq = *HEX
begin
    return
    ( select PT.TABLE_SCHEMA
--     ,PT.SYSTEM_TABLE_NAME,PT.SYSTEM_TABLE_MEMBER 
    from QSYS2.SYSPARTITIONSTAT PT 
    inner join QSYS2.LIBRARY_LIST_INFO LL on LL.SCHEMA_NAME = PT.TABLE_SCHEMA 
    and PT.SYSTEM_TABLE_NAME= ucase(IN_FILE) and PT.SYSTEM_TABLE_MEMBER = ucase(IN_MBR)
    order by ORDINAL_POSITION
    limit 1
    );
end;

/* Testing scripts
; values VSC_getCopyMemberLocation('QCPYSRC','HRM65ORGPR')
; cl:CHGLIBL ILEDITOR;
; select COPY_LIB from table(values VSC_getCopyMemberLocation('QTOOLS','GENCMDXML')) CL (COPY_LIB)
; cl:TAATOOL/CHGLBLJOBD QGPL/QDFTJOBD;
; cl:TAATOOL/CHGLBLJOBD BASEINTG;
*/
; select COPY_LIB from table(values VSC_getCopyMemberLocation('qcpysrc','HRM65ORGPR')) CL (COPY_LIB)
; select COPY_LIB from table(values VSC_getCopyMemberLocation('QCPYSRC','hrm65ORGPR')) CL (COPY_LIB)
; select COPY_LIB from table(values VSC_getCopyMemberLocation('QRPGSRC','PRP04VRG')) CL (COPY_LIB)
--  */
