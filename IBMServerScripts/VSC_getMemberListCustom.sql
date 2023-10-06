cl:chgcurlib ILEDITOR;
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
create or replace function ILEDITOR.VSC_getMemberListCustom
( 
  IN_LIB  char(10)  
 ,IN_SRCF char(10) default null
 ,IN_MBR  varchar(1200) default null 
 ,IN_MBR_TYPE char(10) default null
 ,IN_DEBUG_PARMS char(1) default null
) 
returns table ( 
 MBMXRL bigint  -- Max Rec Len
,MBASP  smallint -- File iASP
,MBLIB  varchar(10) 
,MBFILE varchar(10) 
,MBNAME varchar(10)
,MBSEU2 varchar(10) -- Member type longer version
,MBMTXT varchar(180) 
,MBNRCD int
,CREATED bigint
,CHANGED bigint
,USERCONTENT varchar(132) -- user textual data for use in tooltip
,OUT_FILE varchar(64) -- Filtering format value
,OUT_FILTER_STYLE_F int -- Filtering format type
,OUT_MBR varchar(64) -- Filtering format value
,OUT_FILTER_STYLE_M int -- Filtering format type
,OUT_MBR_TYPE varchar(64) -- Filtering format value
,OUT_FILTER_STYLE_MT int -- Filtering format type
) 
 language sql 
 specific VSC00AFN11 
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
begin 
  return with 
  FILTER_STYLES (FILTER_STYLE_F ,FILTER_STYLE_M ,FILTER_STYLE_MT) as (
      values ( case when locate( '*' ,trim(IN_SRCF)) > 0 then 1 else 0 end
              ,case when substring(IN_MBR_TYPE, 1,4) = '$HWK' then 9 -- CUSTOM FILTERING - HAWKEYE 
                  when substring(IN_MBR, 1,7) = '#PCRPRJ' then 4 -- CUSTOM FILTERING - CMS BY PROJECT
                  when substring(IN_MBR, 1,4) = '#PCR' then 3 -- CUSTOM FILTERING - CMS
                  when substring(IN_MBR, 1,1) = '^'    then 2 -- REGEXP_LIKE
                  when locate('*',IN_MBR)     > 0      then 1 -- GENERICS
                  when locate('%',IN_MBR)     > 0      then 1 
                  else 0 end   
              ,case when substring(IN_MBR_TYPE, 1,4) = '$HWK' then 9 -- CUSTOM FILTERING - HAWKEYE 
                  when substring(IN_MBR_TYPE, 1,7) = '#PCRPRJ' then 4 -- CUSTOM FILTERING - CMS BY PROJECT
                  when substring(IN_MBR_TYPE, 1,4) = '#PCR' then 3 -- CUSTOM FILTERING - CMS
                  when substring(IN_MBR_TYPE, 1,1) = '^'    then 2 -- REGEXP_LIKE
                  when locate('*',IN_MBR_TYPE)     > 0      then 1 -- GENERICS
                  when locate('%',IN_MBR_TYPE)     > 0      then 1 
                  else 0 end   
          )
  )
  ,FILTER_STRINGS ( FILTER_STYLE_F ,FILTER_STRING_F ,FILTER_STYLE_M ,FILTER_STRING_M ,FILTER_STYLE_MT ,FILTER_STRING_MT ) as (
    select FILTER_STYLE_F ,case when FILTER_STYLE_F = 1 then replace(trim(IN_SRCF),'*','%') else IN_SRCF end
    ,FILTER_STYLE_M ,case when FILTER_STYLE_M = 3 then substr(IN_MBR,2,10) when FILTER_STYLE_M = 4 then substr(IN_MBR,8,5) when FILTER_STYLE_M = 9 then replace(trim(IN_MBR),'%','*') else IN_MBR end 
    ,FILTER_STYLE_MT ,case when FILTER_STYLE_MT = 1 then replace(trim(IN_MBR_TYPE),'*','%') else IN_MBR_TYPE end 
          
    from FILTER_STYLES )
  ,HAWK_FILTERS (LIB,FIL) as (
    select case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,1,(locate('/', FILTER_STRING_M)-1)) else 'x' end
          ,case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,(locate('/', FILTER_STRING_M)+1)  ) else 'y' end
    from FILTER_STRINGS
  )                
  ,NO_RESULTS (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
        values (0,0,'','','','','*** Empty list ***',0,bigint(0),bigint(0),'')
  )
  ,CUSTOM_FILTER_HAWKEYE (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as ( 
      select 0,0,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT ,0 as MBNRCD ,bigint(0) CREATED ,bigint(0) CHANGED,'' MBUCNTXT
      from FILTER_STRINGS F inner join HAWK_FILTERS HWK on FILTER_STYLE_M = 9 and substr(IN_MBR_TYPE,5,4) = '$FSU'
      inner join table( ILEDITOR.VSC_getHawkeyeFileSetUseList(IN_LIB=> HWK.LIB ,IN_FILE=> HWK.FIL ) ) x on MBFILE = IN_SRCF
      union
      select 0,0,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT ,0 as MBNRCD ,bigint(0) CREATED ,bigint(0) CHANGED,'' MBUCNTXT
      from FILTER_STRINGS F inner join HAWK_FILTERS HWK on FILTER_STYLE_M = 9 and substr(IN_MBR_TYPE,5,4) = '$DOU' 
      inner join table( ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> HWK.LIB ,IN_OBJ=> HWK.FIL ) ) x on MBFILE = IN_SRCF
      union
      select 0,0,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT ,0 as MBNRCD ,bigint(0) CREATED ,bigint(0) CHANGED,'' MBUCNTXT
      from FILTER_STRINGS F inner join HAWK_FILTERS HWK on FILTER_STYLE_M = 9 and substr(IN_MBR_TYPE,5,4) = '$DPO' 
      inner join table( ILEDITOR.VSC_getHawkeyeProgramObjectsList(IN_LIB=> HWK.LIB ,IN_OBJ=> HWK.FIL ) ) x on MBFILE = IN_SRCF
  )         
  ,CUSTOM_FILTER_CMS (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
      select 
      (TP.avgrowsize - 12) as MBMXRL
      ,ST.iasp_number as MBASP
      ,PCR.LIBRARY_
      ,PCR.SRCF MBFILE
      ,PCR.SRCM as MBNAME
      ,TP.SOURCE_TYPE as MBSEU2
      ,varchar(ifnull(TP.PARTITION_TEXT,'') /*||' (of '||grp||'/'||prd||'/'||rel||') ['||
      overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1)||']'*/) as MBMTXT
      ,TP.NUMBER_ROWS as MBNRCD
      ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
      ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
      ,' release '||grp||'/'||prd||'/'||rel||' ['||
      overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1)||']' as MBUCNTXT
      from FILTER_STRINGS F
      inner join table ( ILEDITOR.CMS_GETPCROBJECTS( IN_TASK => FILTER_STRING_M ) ) PCR on 1=1 and FILTER_STYLE_M = 3 
      inner join QSYS2.SYSTABLES ST on ST.TABLE_SCHEMA = LIBRARY_ and ST.TABLE_NAME = SRCF
      inner join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = ST.TABLE_SCHEMA and TP.TABLE_NAME = ST.TABLE_NAME 
                  and TP.SYSTEM_TABLE_MEMBER = PCR.SRCM
      where ( IN_LIB = LIBRARY_ )
        and FILTER_STYLE_M = 3 
        and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
            or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
            )
        and ( 1=2 
            or FILTER_STRING_MT is null 
            or FILTER_STYLE_MT = 0 and PCR.OBJATTR = FILTER_STRING_MT
            or FILTER_STYLE_MT = 1 and PCR.OBJATTR like FILTER_STRING_MT 
            )
        
      group by avgrowsize,iasp_number,LIBRARY_,SRCF,SRCM,SOURCE_TYPE,PARTITION_TEXT,GRP,PRD,REL, OBJFMLY, TP.NUMBER_ROWS, TP.CREATE_TIMESTAMP,TP.LAST_SOURCE_UPDATE_TIMESTAMP
  )
  ,CUSTOM_FILTER_CMS_BYP (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
      select 
      (TP.avgrowsize - 12) as MBMXRL
      ,ST.iasp_number as MBASP
      ,PCR.LIBRARY_
      ,PCR.SRCF MBFILE
      ,PCR.SRCM as MBNAME
      ,TP.SOURCE_TYPE as MBSEU2
      ,varchar(ifnull(TP.PARTITION_TEXT,'') ||' (of '||grp||'/'||prd||'/'||rel||') ['||
      overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1)||']') as MBMTXT
      ,TP.NUMBER_ROWS as MBNRCD
      ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
      ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
      ,' release '||grp||'/'||prd||'/'||rel||' ['||
      overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1)||']' as MBUCNTXT
      from FILTER_STRINGS F
      inner join table ( ILEDITOR.CMS_GETPCROBJECTS( IN_PRJ_NUM => FILTER_STRING_M) ) PCR on 1=1 and FILTER_STYLE_M = 4
      inner join QSYS2.SYSTABLES ST on ST.TABLE_SCHEMA = LIBRARY_ and ST.TABLE_NAME = SRCF
      inner join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = ST.TABLE_SCHEMA and TP.TABLE_NAME = ST.TABLE_NAME 
                  and TP.SYSTEM_TABLE_MEMBER = PCR.SRCM
      where ( IN_LIB = LIBRARY_ )
        and FILTER_STYLE_M = 4 
        and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
            or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
            )
        and ( 1=2 
            or FILTER_STRING_MT is null 
            or FILTER_STYLE_MT = 0 and PCR.OBJATTR = FILTER_STRING_MT
            or FILTER_STYLE_MT = 1 and PCR.OBJATTR like FILTER_STRING_MT 
            )
        
      group by avgrowsize,iasp_number,LIBRARY_,SRCF,SRCM,SOURCE_TYPE,PARTITION_TEXT,GRP,PRD,REL, OBJFMLY, TP.NUMBER_ROWS, TP.CREATE_TIMESTAMP,TP.LAST_SOURCE_UPDATE_TIMESTAMP
  )
  ,CUSTOM_FILTER_REGEXPR (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
  select distinct 
      (TP.AVGROWSIZE-12)as MBMXRL
      ,ST.IASP_NUMBER as MBASP
      ,TP.TABLE_SCHEMA as MBLIB
      ,TP.SYSTEM_TABLE_NAME as MBFILE
      ,TP.SYSTEM_TABLE_MEMBER as MBNAME
      ,TP.SOURCE_TYPE as MBSEU2
      ,varchar(ifnull(PARTITION_TEXT,'') || case when TP.SYSTEM_TABLE_SCHEMA like 'PG%' and TP.SYSTEM_TABLE_SCHEMA <> 'PGMT' then ' ('||TP.SYSTEM_TABLE_SCHEMA||')' else '' end) as MBMTXT 
      ,TP.NUMBER_ROWS as MBNRCD
      ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
      ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
      ,' ' MBUCNTXT
      from FILTER_STRINGS F
      left join QSYS2.SYSTABLES as ST on 1=1 and FILTER_STYLE_M = 2
      left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA=ST.TABLE_SCHEMA and TP.TABLE_NAME=ST.TABLE_NAME 
            and TP.SOURCE_TYPE is not null
      where FILTER_STYLE_M = 2 and TP.TABLE_SCHEMA = IN_LIB
        and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = TP.SYSTEM_TABLE_NAME )
            or FILTER_STYLE_F = 1 and ( TP.SYSTEM_TABLE_NAME like FILTER_STRING_F )
            )
        and regexp_like( TP.SYSTEM_TABLE_MEMBER ,case when FILTER_STYLE_M = 2 then FILTER_STRING_M end ,1,'c')
        and ( 1=2 
            or FILTER_STRING_MT is null 
            or FILTER_STYLE_MT = 0 and TP.SOURCE_TYPE = FILTER_STRING_MT
            or FILTER_STYLE_MT = 1 and TP.SOURCE_TYPE like FILTER_STRING_MT 
            )
  )
  ,BASE_FILTER (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
      select distinct 
      (TP.AVGROWSIZE-12)as MBMXRL
      ,A.IASP_NUMBER as MBASP
      ,TP.TABLE_SCHEMA as MBLIB
      ,TP.SYSTEM_TABLE_NAME as MBFILE
      ,TP.SYSTEM_TABLE_MEMBER as MBNAME
      ,TP.SOURCE_TYPE as MBSEU2
      ,varchar(ifnull(PARTITION_TEXT,'') || case when TP.SYSTEM_TABLE_SCHEMA like 'PG%' and TP.SYSTEM_TABLE_SCHEMA <> 'PGMT' then ' ('||trim(TP.SYSTEM_TABLE_SCHEMA)||')' else '' end) as MBMTXT 
      ,TP.NUMBER_ROWS as MBNRCD
      ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
      ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
      ,' ' MBUCNTXT
      from FILTER_STRINGS F
      left join QSYS2.SYSTABLES as A on FILTER_STYLE_M in (0,1)
      left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA=A.TABLE_SCHEMA and TP.TABLE_NAME=A.TABLE_NAME 
            and TP.SOURCE_TYPE is not null
      where TP.TABLE_SCHEMA = IN_LIB
        and ( FILTER_STYLE_F = 1 and TP.TABLE_NAME      like (replace(trim(FILTER_STRING_F),'*','%'))
            or FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = TP.TABLE_NAME )
            )
        and ( FILTER_STYLE_M = 1 and TP.TABLE_PARTITION like (replace(trim(FILTER_STRING_M),'*','%'))
            or FILTER_STYLE_M = 0 and ( FILTER_STRING_M is null or TP.TABLE_PARTITION = FILTER_STRING_M )
            )
        and ( 1=2 
            or FILTER_STRING_MT is null 
            or FILTER_STYLE_MT = 0 and TP.SOURCE_TYPE = FILTER_STRING_MT
            or FILTER_STYLE_MT = 1 and TP.SOURCE_TYPE like FILTER_STRING_MT 
            )
    )    
    ,COMBINED_GROUPS (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
        select MBMXRL ,MBASP ,MBLIB ,MBFILE ,ifnull( MBNAME ,' ' ) ,ifnull( MBSEU2 ,' ' ) ,MBMTXT ,MBNRCD,CREATED,CHANGED ,MBUCNTXT  from BASE_FILTER
        union
        select MBMXRL ,MBASP ,MBLIB ,MBFILE ,ifnull( MBNAME ,' ' ) ,ifnull( MBSEU2 ,' ' ) ,MBMTXT ,MBNRCD,CREATED,CHANGED ,MBUCNTXT  from CUSTOM_FILTER_CMS
        union
        select MBMXRL ,MBASP ,MBLIB ,MBFILE ,ifnull( MBNAME ,' ' ) ,ifnull( MBSEU2 ,' ' ) ,MBMTXT ,MBNRCD,CREATED,CHANGED ,MBUCNTXT  from CUSTOM_FILTER_CMS_BYP
        union
        select MBMXRL ,MBASP ,MBLIB ,MBFILE ,ifnull( MBNAME ,' ' ) ,ifnull( MBSEU2 ,' ' ) ,MBMTXT ,MBNRCD,CREATED,CHANGED ,MBUCNTXT  from CUSTOM_FILTER_REGEXPR
        union
        select MBMXRL ,MBASP ,MBLIB ,MBFILE ,ifnull( MBNAME ,' ' ) ,ifnull( MBSEU2 ,' ' ) ,MBMTXT ,MBNRCD,CREATED,CHANGED ,MBUCNTXT  from CUSTOM_FILTER_HAWKEYE
    )
    ,COMBINED_GROUP_QTY as ( select count(*) CG_QTY from COMBINED_GROUPS )
    ,COMBINE_GROUPS_2 (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT) as (
        select * from COMBINED_GROUPS 
        union 
        select * from NO_RESULTS where (select CG_QTY from COMBINED_GROUP_QTY) = 0 and IN_DEBUG_PARMS is not null
        )
    select CG2.* 
    ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
    ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
    ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT 
    from FILTER_STRINGS cross join COMBINE_GROUPS_2 CG2 
--     where FILTER_STYLE_M in (0,1,2,3)
--     where FILTER_STYLE_M in (9)
    order by MBMXRL,MBASP,MBFILE,MBNAME,MBSEU2,MBMTXT
          
;
end; 
comment on specific function VSC00AFN11 is 'Return list of source members for VS Code - Custom Code'; 
  label on specific function VSC00AFN11 is 'Return list of source members for VS Code-Custom'; 
/* Testing query */
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'QTXTSRC' ,IN_MBR => '#PCR1959800'  ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '#PCR1959800'  ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'Q*SRC' ,IN_MBR => '#PCR1959800'  ))
/* */
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1970000', IN_LIB => 'PGMT' ,IN_SRCF=>'Q*') )

;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ) )

;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*RG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*RG', IN_LIB => 'D2WFIINTG' ) )

;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ) )

;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '*', IN_LIB => 'PGMT' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '*', IN_LIB => 'PGMT', IN_SRCF => 'Q*SRC' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^CVT19355', IN_LIB => 'PGMT' ) )

;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1824200', IN_LIB => 'WFIQUAL' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'CVTQUAL' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '^CVT19700'  ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFICVT' ,IN_SRCF => 'Q*' ,IN_MBR => 'CVT19700%'  ) )
-- ;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'Q*' ,IN_MBR => '*'  ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1960600', IN_LIB => 'CVTQUAL' ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_SRCF => '*ALL' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )

;select * from SYSPARTITIONSTAT where TABLE_SCHEMA = 'PGMT' and TABLE_NAME like (replace(trim('Q*SRC    '),'*','%'))

;values replace(trim('CVT19700%'),'*','%')

;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'QRPGSRC'  ,IN_MBR => '#PCR1970000'  ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'TSTSRC'   ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'QCLSRC'   ,IN_MBR => '#PCR1708800'  ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QTXTSRC'   ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'Q*'       ,IN_MBR => '#PCR2030600'  ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'QTXTSRC'  ,IN_MBR => '#PCR2030600' , IN_DEBUG_PARMS => '1' ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFIQUAL',IN_SRCF => 'QRPGSRC'  ,IN_MBR => '#PCR2030600' , IN_DEBUG_PARMS => '1' ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFIDTA' ,IN_SRCF => 'PRPJTCTB' ,IN_MBR => '$HWK',  ) )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'  ,IN_MBR => 'WFIDTA/PRPTJCTB' , IN_MBR_TYPE => '$HWK' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QCLSRC '   ,IN_MBR => 'WFIDTA/PRPPTOTH' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIDTA/PRPPTOTH' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QDDSSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QCLSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '*ALL/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/EML10ACL' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '*ALL/EML10ACL' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '%ALL/PRINTPR' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QCLSRC'   ,IN_MBR => '%ALL/PRINTPR' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'D2WFIQUAL' ,IN_SRCF => 'QDDSSRC' ,IN_MBR => '#PCR1708800'  ))
;select * from table ( ILEDITOR.VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'D2WFIQUAL' ,IN_SRCF => 'QDDSSRC' ,IN_MBR => '#PCRPRJ00101'  ))