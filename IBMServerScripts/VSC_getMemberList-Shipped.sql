/*============================================================================*/ 
/* SPECIFIC NAME..: VSC00AFN01                                                */ 
/* FUNCTION NAME..: VSC_getMemberListCustom                                   */ 
/* AUTHOR.........: Matt Tyler                                                */ 
/* DATE...........: 09/22/2022                                                */ 
/* PCR #..........: XXXXX 00                                                  */ 
/* FUNCTION/DESC..: Return list of source members for VS Code - Custom Code   */ 
/*                                                                            */ 
/*----------------------------------------------------------------------------*/ 
/*   MODIFICATIONS:                                                           */ 
/*----------------------------------------------------------------------------*/ 
/* MOD#  PCR     PGMR   DATE   DESCRIPTION                                    */ 
/*============================================================================*/ 
set path *libl ; 
create or replace function VSC_getMemberList_Shipped
( 
  IN_LIB  char(10)  
 ,IN_SRCF char(10) default null
 ,IN_MBR  varchar(12) default null 
 ,IN_MBR_TYPE char(10) default null
) 
returns table ( 
 MBMXRL bigint  -- Max Rec Len
,MBASP  smallint -- File iASP
,MBFILE varchar(10) 
,MBNAME varchar(12)
,MBSEU2 varchar(10) -- Member type longer version
,MBMTXT varchar(180) 
) 
 language sql 
 specific VSC00AFN91 
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
    NO_RESULTS (MBMXRL   ,MBASP      ,MBFILE  ,MBNAME ,MBSEU2,MBMTXT) as (
        values (bigint(0),smallint(0),IN_SRCF ,IN_MBR ,'  '  ,char('*** Empty list ***',50))
         )        
        select * from NO_RESULTS where 1=2

    order by MBMXRL,MBASP,MBFILE,MBNAME,MBSEU2,MBMTXT
          
;
end; 
comment on specific function VSC00AFN91 is 'Return list of source members for VS Code - Shipped'; 
  label on specific function VSC00AFN91 is 'Return list of source members for VS Code-Shipped'; 
/* Testing query */
;select * from table (VSC_getMemberList_Shipped(IN_LIB => 'PGMT' ,IN_SRCF => 'QTXTSRC' ,IN_MBR => '#PCR1959800'  ))
;select * from table (VSC_getMemberList_Shipped(IN_LIB => 'PGMT' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '#PCR1959800'  ))
;select * from table (VSC_getMemberList_Shipped(IN_LIB => 'PGMT' ,IN_SRCF => 'Q*SRC' ,IN_MBR => '#PCR1959800'  ))
/* */
;select * from table ( VSC_getMemberList_Shipped(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ) )
;select * from table ( VSC_getMemberList_Shipped(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) )
;select * from table ( VSC_getMemberList_Shipped(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( VSC_getMemberList_Shipped(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( VSC_getMemberList_Shipped(IN_MBR => '#PCR2030600', IN_LIB => 'PGMT' ,IN_SRCF=>'Q*') )
