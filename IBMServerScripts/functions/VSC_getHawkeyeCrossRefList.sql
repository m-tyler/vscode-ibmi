/*============================================================================ 
   SPECIFIC NAME..: VSC00AFN80                                                 
   FUNCTION NAME..: VSC_getHawkeyeCrossRefList                                          
   AUTHOR.........: Matt Tyler                                                 
   DATE...........: 06/07/2022                                                 
   PCR #..........: XXXXX 00                                                   
   FUNCTION/DESC..:              
                                                                               
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

;create or replace function VSC_getHawkeyeCrossRefList
(
  IN_LIB  char(10)  
 ,IN_FILE char(10) 
 ,IN_MBR varchar(64) default null
 ,IN_MBR_TYPE varchar(64) default null
 ,IN_DEBUG_PARMS char(1) default null

       ) 
returns table ( 
 OUXREF varchar(10)
,PHLIB varchar(10)
,PHFILE varchar(10)
,PHFILA varchar(10)
,PHDTAT char(1)
,PHTXT varchar(128)
,MBLIB varchar(10) 
,MBFILE varchar(10) 
,MBNAME varchar(10)
,MBSEU2 varchar(10) -- Member type longer version
,MBMTXT varchar(180) 
)

 language sql 
 specific VSC00AFN80
 deterministic 
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
VSC00AFN80: begin 
    declare cmdstring varchar(256);
    

    declare HWK_ERROR condition for sqlstate '38501';
    declare continue handler for HWK_ERROR
    begin
    end;
 

    case when IN_MBR_TYPE = '$HWK$DOU' then 
      
    case when IN_MBR_TYPE = '$HWK$DOU' then 
    end;
 

    
end VSC00AFN80;

-- ;select * from table(VSC_getHawkeyeObjecOUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPTJCTB' ,IN_TLIB=>'PGMT' ,IN_TFILE=>'VSC_T12345')) x 
;select * from table(VSC_getHawkeyeCrossRefList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPTJCTB')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeCrossRefList(IN_LIB=> 'WFIOBJ',IN_FILE=>'EML10HCL')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeCrossRefList(IN_LIB=> ' ',IN_FILE=>' ')) x 