/*============================================================================*/ 
/* SPECIFIC NAME..: VSC00APC01                                                */ 
/* FUNCTION NAME..: VSC_buildFileSetUXref                                     */ 
/* AUTHOR.........: Matt Tyler                                                */ 
/* DATE...........: 10/13/2022                                                */ 
/* PCR #..........: 19700 00                                                  */ 
/* FUNCTION/DESC..: Return check status for Emp and Run                       */ 
/*                                                                            */ 
/*----------------------------------------------------------------------------*/ 
/*   MODIFICATIONS:                                                           */ 
/*----------------------------------------------------------------------------*/ 
/* MOD#  PCR     PGMR   DATE   DESCRIPTION                                    */ 
/*============================================================================*/ 
set path *libl ; 
create or replace procedure VSC_buildFileSetUXref
( 
  in IN_EMP  dec(6, 0) -- PRPEBRPF :: EGEMP# 
 ,in IN_CHECK_RUN dec(5, 0) -- PRPEBRPF :: EGRUN# 
 ,in IN_RUN_YEAR dec(4, 0) default null -- PRPEBRPF :: EGYR 
 ,out OUT_STATUS char(1) -- PRPEBRPF :: EGCSTA
) 
 language sql 
 specific VSC00APC01 
 deterministic 
 -- returns null on null input //not recognized by compiler but doesnt fail
 called on null input
 no external action 
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
    declare STMTSQL varchar(4096);
    declare lRUNYEAR char(4);
    declare lYELIB varchar(11) default '';
    declare lSTATUS char(1) default null;
    declare SQLSTATE char(5);
    
    declare CHECK_STATUS_CSR cursor for RUNSTMT;
    
    set STMTSQL = '';
    if IN_RUN_YEAR is null or IN_RUN_YEAR < 1990
    then
        select substr( lDUPEDT ,1 ,4 ) into lRUNYEAR 
                from PRPPRMST where DURUN# = IN_CHECK_RUN;
    else
        lRUNYEAR = digits( IN_RUN_YEAR ); 
    end if;
    
    set lRUNYEAR = substr( lDUPEDT ,1 ,4 );
--     call systools.lprintf('Value of lRUNYEAR = ' ||lRUNYEAR);
    if dec( lRUNYEAR ) < year(now())
    then
       set lYELIB = 'WFIPR'||lRUNYEAR||'/';
--        call systools.lprintf('Value of lYELIB = ' ||lYELIB);
    end if;
    
    set STMTSQL = 'select EGCSTA from '||lYELIB||'PRPEBRPF where EGRUN# = ' 
                  ||ifnull( IN_CHECK_RUN ,0 )||' and EGEMP# = '||ifnull( IN_EMP ,0 );
    call systools.lprintf('Value of STMTSQL = ' ||STMTSQL);
    
    prepare RUNSTMT from STMTSQL;
--     call systools.lprintf('Value of SQLSTATE in PREPARE statement = ' ||SQLSTATE);
    
    open CHECK_STATUS_CSR; 
--     call systools.lprintf('Value of SQLSTATE in OPEN statement = ' ||SQLSTATE);   
    
    fetch from CHECK_STATUS_CSR into lSTATUS;
--     call systools.lprintf('Value of SQLSTATE in FETCH statement = ' ||SQLSTATE);
    call systools.lprintf('Value of lSTATUS = ' ||lSTATUS);
    
    close CHECK_STATUS_CSR;    
    set OUT_STATUS = lSTATUS;
    
    return;   
end;

comment on specific procedure VSC00APC01 is 'Return check status for Emp and Run';
  label on specific procedure VSC00APC01 is 'Return check status for Emp and Run';

;set val = ''
;call VSC_buildFileSetUXref( 178374, 12413 ,VAL) ;values VAL
;call VSC_buildFileSetUXref( 178374, 12402 ,VAL) ;values VAL
;call VSC_buildFileSetUXref( 178374, 22402 ,VAL) ;values VAL
;call VSC_buildFileSetUXref( 178374, null   ,VAL) ;values VAL
;call VSC_buildFileSetUXref( 215003, 12247 ,VAL) ;values VAL
;call VSC_buildFileSetUXref( 215003, 12247 ,2021 ,VAL) ;values VAL

;select distinct EGRUN# ,EGEMP# ,EGCSTA from  WFIPR2021/PRPEBRPF where EGCSTA <> ' '