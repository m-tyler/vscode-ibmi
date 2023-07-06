/*============================================================================*/ 
/* SPECIFIC NAME..: VSC00AFN02                                                */ 
/* FUNCTION NAME..: VSC_getSourceFileList                                     */ 
/* AUTHOR.........: Matt Tyler                                                */ 
/* DATE...........: 09/22/2022                                                */ 
/* PCR #..........: XXXXX 00                                                  */ 
/* FUNCTION/DESC..: Return list of source files for VS Code                   */ 
/*                                                                            */ 
/*----------------------------------------------------------------------------*/ 
/*   MODIFICATIONS:                                                           */ 
/*----------------------------------------------------------------------------*/ 
/* MOD#  PCR     PGMR   DATE   DESCRIPTION                                    */ 
/*============================================================================*/ 
set path *libl ; 
create or replace function VSC_getSourceFileList_Shipped
( 
  IN_LIB  char(10)  
 ,IN_SRCF char(10) default null
 ,IN_MBR varchar(64) default null
 ,IN_MBR_TYPE varchar(64) default null
       ) 
returns table ( 
 PHLIB varchar(10)
,PHFILE varchar(10)
,PHFILA varchar(10)
,PHDTAT char(1)
,PHTXT varchar(128)
,PHNOMB int
) 
 language sql 
 specific VSC00AFN92 
 deterministic 
 called on null input 
 no external action 
 modifies sql data -- <<-- Needed if customer calls a feature that is defined as `modifies sql data`
 not fenced --<<-- Needed if customer calls a function that is not thread safe 
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
    return with 
    NO_RESULTS (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN) as (
         values (nullif(' ',' '),x'A1','*PHY ','S',0 ,' ',0)
     )
    select PHLIB ,PHFILE ,PHFILA ,PHDTAT ,char(' ',50) PHTXT,PHNOMB from NO_RESULTS where 1=2
    
;
end; 
comment on specific function VSC00AFN92 is 'Return list of source files for VS Code-Shipped'; 
  label on specific function VSC00AFN92 is 'Return list of source files for VS Code-Shipped'; 
/* Testing query 
;select * from table ( VSC_GETSOURCEFILELIST_SHIPPED(IN_MBR => 'KRN05*'   ,IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
 */