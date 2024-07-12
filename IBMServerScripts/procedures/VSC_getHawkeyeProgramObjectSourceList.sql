/*============================================================================ 
   SPECIFIC NAME..: VSC00APC83                                                 
   PROCEDURE NAME.: VSC_getHawkeyeProgramObjectSourceList                      
   AUTHOR.........: Matt Tyler                                                 
   DATE...........: 10/13/2022                                                 
   PCR #..........: 19700 00                                                   
   PROCEDURE/DESC.: HWK - Return actual source for some SQL DB items           
                                                                               
  ---------------------------------------------------------------------------- 
     MODIFICATIONS:                                                            
  ---------------------------------------------------------------------------- 
   MOD#  PCR     PGMR   DATE   DESCRIPTION                                     
  ============================================================================*/ 
set path *libl ; 
create or replace procedure VSC_getHawkeyeProgramObjectSourceList
( 
 in APITYP char(2)
,in APIOPT char(2)
,in APIOB  char(10)
,in APIOBL char(10)
,in APIOBM char(10)
,in APIOBA char(10)
,inout APISTS char(1)
,inout APISF  char(10)
,inout APISFL char(10)
,inout APISFM char(10)
) 
 language cl
 specific VSC00APC83 
 external name 'HAWKEYE/H$APISRC'
 parameter style general
 
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
;
comment on specific procedure VSC00APC83 is 'HWK - Return actual source for SQL DB item';
  label on specific procedure VSC00APC83 is 'HWK - Return actual source for SQL DB item';

/* Testing code */
;create or replace variable APITYP char(2)
;create or replace variable APIOPT char(2)
;create or replace variable APIOB  char(10)
;create or replace variable APIOBL char(10)
;create or replace variable APIOBM char(10)
;create or replace variable APIOBA char(10)
;create or replace variable APISTS char(1)
;create or replace variable APISF  char(10)
;create or replace variable APISFL char(10)
;create or replace variable APISFM char(10)
;set APITYP = '20'
;set APIOPT = '80'
;set APIOB  = 'PRPBATI0'
;set APIOBL = 'WFIDTA'
;set APIOBM = ''

;set APIOBA = '*FILE '
;set APIOB  = 'UTL25ACL'
;set APIOBL = 'WFIOBJ'
;set APIOBA = '*PGM '
;set APIOBM = ''

;set APISTS = ''
;set APISF  = ''
;set APISFL = ''
;set APISFM = ''
;call VSC_getHawkeyeProgramObjectSourceList(APITYP,APIOPT,APIOB,APIOBL,APIOBM,APIOBA,APISTS,APISF,APISFL,APISFM)
;values (APISTS,APISF,APISFL,APISFM)