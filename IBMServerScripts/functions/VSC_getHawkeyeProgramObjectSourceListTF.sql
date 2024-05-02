/*============================================================================*/ 
/* SPECIFIC NAME..: VSC00APC83                                                */ 
/* FUNCTION NAME..: VSC_getHawkeyeProgramObjectSourceListTF                   */ 
/* AUTHOR.........: Matt Tyler                                                */ 
/* DATE...........: 10/13/2022                                                */ 
/* PCR #..........: 19700 00                                                  */ 
/* FUNCTION/DESC..: HWK - Return actual source for some SQL DB items          */ 
/*                                                                            */ 
/*----------------------------------------------------------------------------*/ 
/*   MODIFICATIONS:                                                           */ 
/*----------------------------------------------------------------------------*/ 
/* MOD#  PCR     PGMR   DATE   DESCRIPTION                                    */ 
/*============================================================================*/ 
;cl:chgcurlib ILEDITOR;
;set current path ILEDITOR, SYSTEM PATH
-- ;cl:chgcurlib [USER];
-- ;set path [USER]
-- ;select * from LIBRARY_LIST_INFO
;create or replace function VSC_getHawkeyeProgramObjectSourceListTF
( 
 APITYP char(2)
,APIOPT char(2)
,APIOB  char(10)
,APIOBL char(10)
,APIOBM char(10)
,APIOBA char(10)
)
returns table (
 APISF  char(10)
,APISFL char(10)
,APISFM char(10)
) 
language sql 
 specific VSC00AFN84 
 not deterministic 
 called on null input 
 no external action 
 modifies sql data
 not fenced
 
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
VSC00AFN84: begin             
    declare APISTS  char(1) default ' ';
    declare APISF  char(10) default ' ';
    declare APISFL char(10) default ' ';
    declare APISFM char(10) default ' ';
    call VSC_getHawkeyeProgramObjectSourceList(APITYP,APIOPT,APIOB,APIOBL,APIOBM,APIOBA,APISTS,APISF,APISFL,APISFM);
    return select * from table( values(APISF,APISFL,APISFM) ) x (APISF,APISFL,APISFM);
end VSC00AFN84;
comment on specific function VSC00AFN84 is 'HWK - Return actual source for SQL DB item';
  label on specific function VSC00AFN84 is 'HWK - Return actual source for SQL DB item';

/* Testing code 
*/
;select * from table ( VSC_getHawkeyeProgramObjectSourceListTF(APITYP => '20' ,APIOPT => '80',APIOB => 'PRPBATI0', APIOBL => 'WFIDTA', APIOBM => ' ', APIOBA => '*FILE') );
;select * from table ( VSC_getHawkeyeProgramObjectSourceListTF(APITYP => '20' ,APIOPT => '80',APIOB => 'UTL25SCL', APIOBL => 'WFIOBJ', APIOBM => ' ', APIOBA => '*PGM ') );
/*
;select * from VSC_T$DPO inner join table( ILEDITOR.VSC_getHawkeyeProgramObjectSourceListTF(APITYP => '20' ,APIOPT => '80',APIOB => PODOBJ, APIOBL => PODLIB, APIOBM => ' ', APIOBA => PODTYP) ) a on 1=1
-- where PODSFL = 'Z_INTSQL_Z'

;update VSC_T$DPO o 
set (PODSFL,PODSLB,PODSMB) = (select APISF,APISFL,APISFM from table ( ILEDITOR.VSC_getHawkeyeProgramObjectSourceListTF(APITYP => '20' ,APIOPT => '80',APIOB => o.PODOBJ, APIOBL => o.PODLIB, APIOBM => ' ', APIOBA => o.PODTYP) ))
where PODSFL = 'Z_INTSQL_Z' 
*/