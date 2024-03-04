/*============================================================================ 
   SPECIFIC NAME..: VSC00APC11                                                 
   procedure NAME..: VSC_getMemberListCustom                                  
   AUTHOR.........: Matt Tyler                                                
   DATE...........: 09/22/2022                                                
   PCR #..........: XXXXX 00                                                  
   procedure/DESC..: Return list of source members for VS Code - Custom Code  
                                                                               
  ---------------------------------------------------------------------------- 
     MODIFICATIONS:                                                            
  ---------------------------------------------------------------------------- 
   MOD#  PCR     PGMR   DATE   DESCRIPTION                                     
  ============================================================================*/ 
/*NOTE: Change the qualifier library on SP call below */

;cl:chgcurlib ILEDITOR;
;set current path ILEDITOR, SYSTEM PATH
-- ;cl:chgcurlib [USER];
-- ;set path [USER]
-- ;select * from LIBRARY_LIST_INFO
  
;create or replace procedure VSC_getMemberListCustom_SP
( 
  IN_LIB  char(10) default null
 ,IN_SRCF char(10) default '*'
 ,IN_MBR  varchar(1200) default '*' 
 ,IN_MBR_TYPE char(10) default '*'
 ,IN_DEBUG_PARMS char(1) default null
) 
 language sql 
 specific VSC00APC11 
 result set 1
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
    declare FILTER_STYLE_F integer;
    declare FILTER_STRING_F varchar(10);
    declare FILTER_STYLE_M integer;
    declare FILTER_STRING_M varchar(256);
    declare FILTER_STYLE_MT integer;
    declare FILTER_STRING_MT varchar(64);
    declare HWKLIB varchar(256);
    declare HWKFIL varchar(256);
  
    declare QUERY_STYLE_CSR cursor for
    with FILTER_STYLES (FILTER_STYLE_F ,FILTER_STYLE_M ,FILTER_STYLE_MT) as (
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
         select 
           FILTER_STYLE_F ,case when FILTER_STYLE_F = 1 then replace(replace(trim(IN_SRCF), '*ALL', '%'), '*', '%') else IN_SRCF end
          ,FILTER_STYLE_M ,case when FILTER_STYLE_M = 3 then substr(IN_MBR,2,10) when FILTER_STYLE_M = 4 then substr(IN_MBR,8,5) when FILTER_STYLE_M = 9 then replace(trim(IN_MBR),'%','*') else IN_MBR end 
          ,FILTER_STYLE_MT ,case when FILTER_STYLE_MT = 1 then replace(trim(IN_MBR_TYPE),'*','%') else IN_MBR_TYPE end 
               
        from FILTER_STYLES )
    ,HAWK_FILTERS (HWKLIB,HWKFIL) as (select case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,1,(locate('/', FILTER_STRING_M)-1)) else 'x' end
                                      ,case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,(locate('/', FILTER_STRING_M)+1)  ) else 'y' end
                                from FILTER_STRINGS
     )
    select FILTER_STYLE_F,FILTER_STRING_F ,FILTER_STYLE_M,FILTER_STRING_M,FILTER_STYLE_MT,FILTER_STRING_MT,HWKLIB,HWKFIL 
    from FILTER_STRINGS cross join HAWK_FILTERS;
--     
--     
--     
--     
    declare C9_FSU cursor with return for 
    with CUSTOM_FILTER_HAWKEYE_FSU (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
                                ,OUT_FILE ,OUT_FILTER_STYLE_F
                                ,OUT_MBR ,OUT_FILTER_STYLE_M 
                                ,OUT_TYPE ,OUT_FILTER_STYLE_MT
    ) as ( 
        select int(0),smallint(0),MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT ,0 as MBNRCD ,bigint(0) CREATED ,bigint(0) CHANGED,'' MBUCNTXT
              ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
              ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
              ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from table( VSC_getHawkeyeFileSetUseList(IN_LIB=> HWKLIB ,IN_FILE=> HWKFIL, IN_DEBUG_PARMS=>IN_DEBUG_PARMS) ) x where MBFILE = IN_SRCF
    ) select HWK.* 
      from CUSTOM_FILTER_HAWKEYE_FSU HWK;  
    
    declare C9_DOU cursor with return for 
    with CUSTOM_FILTER_HAWKEYE_DOU (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
                                ,OUT_FILE ,OUT_FILTER_STYLE_F
                                ,OUT_MBR ,OUT_FILTER_STYLE_M 
                                ,OUT_TYPE ,OUT_FILTER_STYLE_MT
        
    ) as ( 
        select int(0),smallint(0),MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT ,0 as MBNRCD ,bigint(0) CREATED ,bigint(0) CHANGED,'' MBUCNTXT
              ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
              ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
              ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from table( VSC_getHawkeyeObjectUseList(IN_LIB=> HWKLIB ,IN_OBJ=> HWKFIL, IN_DEBUG_PARMS=>IN_DEBUG_PARMS) ) x where MBFILE = IN_SRCF
    ) select HWK.* from CUSTOM_FILTER_HAWKEYE_DOU HWK;  
    
    declare C9_DPO cursor with return for 
    with CUSTOM_FILTER_HAWKEYE_DPO (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
                                ,OUT_FILE ,OUT_FILTER_STYLE_F
                                ,OUT_MBR ,OUT_FILTER_STYLE_M 
                                ,OUT_TYPE ,OUT_FILTER_STYLE_MT
    
        ) as ( 
        select int(0),smallint(0),MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT ,0 as MBNRCD ,bigint(0) CREATED ,bigint(0) CHANGED,'' MBUCNTXT
              ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
              ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
              ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from table( VSC_getHawkeyeProgramObjectsList(IN_LIB=> HWKLIB ,IN_OBJ=> HWKFIL, IN_DEBUG_PARMS=>IN_DEBUG_PARMS) ) x where MBFILE = IN_SRCF
    ) select HWK.* from CUSTOM_FILTER_HAWKEYE_DPO HWK;  
-- 
    declare C3 cursor with return for 
    with CUSTOM_FILTER_CMS (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
    ) as (
        select 
        (TP.avgrowsize - 12) as MBMXRL
        ,ST.iasp_number as MBASP
        ,PCR.LIBRARY_
        ,PCR.SRCF MBFILE
        ,PCR.SRCM as MBNAME
        ,TP.SOURCE_TYPE as MBSEU2
        ,varchar(ifnull(TP.PARTITION_TEXT,'')) as MBMTXT
        ,TP.NUMBER_ROWS as MBNRCD
        ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
        ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
        ,' release '||grp||'/'||prd||'/'||rel||' ['||
        overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1)||']' as MBUCNTXT
        from table ( CMS_GETPCROBJECTS( IN_TASK => FILTER_STRING_M ) ) PCR 
        inner join QSYS2.SYSTABLES ST on ST.TABLE_SCHEMA = LIBRARY_ and ST.TABLE_NAME = SRCF
        inner join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = ST.TABLE_SCHEMA and TP.TABLE_NAME = ST.TABLE_NAME 
                    and TP.SYSTEM_TABLE_MEMBER = PCR.SRCM
        where ( PCR.LIBRARY_ = IN_LIB )
          and FILTER_STYLE_M = 3 
          and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
             or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
              )
          and ( 1=2 
             or FILTER_STRING_MT is null 
             or FILTER_STYLE_MT = 0 and PCR.OBJATTR = FILTER_STRING_MT
             or FILTER_STYLE_MT = 1 and PCR.OBJATTR like FILTER_STRING_MT 
             )
          
        group by avgrowsize,iasp_number,LIBRARY_,SRCF,SRCM,SOURCE_TYPE,PARTITION_TEXT,GRP,PRD,REL
                , OBJFMLY, TP.NUMBER_ROWS, TP.CREATE_TIMESTAMP,TP.LAST_SOURCE_UPDATE_TIMESTAMP
    ) select CMS.* 
            ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
            ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
            ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from CUSTOM_FILTER_CMS CMS;
-- 
    declare C4 cursor with return for  
    with CUSTOM_FILTER_CMS_BY_PROJECT (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
                                ,OUT_FILE ,OUT_FILTER_STYLE_F
                                ,OUT_MBR ,OUT_FILTER_STYLE_M 
                                ,OUT_TYPE ,OUT_FILTER_STYLE_MT

    ) as (
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
        ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
        ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
        ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from table ( CMS_GETPCROBJECTS( IN_PRJ_NUM => FILTER_STRING_M) ) PCR 
        inner join QSYS2.SYSTABLES ST on ST.TABLE_SCHEMA = LIBRARY_ and ST.TABLE_NAME = SRCF
        inner join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = ST.TABLE_SCHEMA and TP.TABLE_NAME = ST.TABLE_NAME 
                    and TP.SYSTEM_TABLE_MEMBER = PCR.SRCM
        where ( IN_LIB = PCR.LIBRARY_ )
          and FILTER_STYLE_M = 4 
          and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
             or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
              )
          and ( 1=2 
             or FILTER_STRING_MT is null 
             or FILTER_STYLE_MT = 0 and PCR.OBJATTR = FILTER_STRING_MT
             or FILTER_STYLE_MT = 1 and PCR.OBJATTR like FILTER_STRING_MT 
             )
          
        group by avgrowsize,iasp_number,LIBRARY_,SRCF,SRCM,SOURCE_TYPE,PARTITION_TEXT,GRP,PRD,REL
                , OBJFMLY, TP.NUMBER_ROWS, TP.CREATE_TIMESTAMP,TP.LAST_SOURCE_UPDATE_TIMESTAMP
    ) select * from CUSTOM_FILTER_CMS_BY_PROJECT;

    declare C2 cursor with return for 
    with CUSTOM_FILTER_REGEXPR (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
                                ,OUT_FILE ,OUT_FILTER_STYLE_F
                                ,OUT_MBR ,OUT_FILTER_STYLE_M 
                                ,OUT_TYPE ,OUT_FILTER_STYLE_MT
        
    ) as (
        select distinct 
        (TP.AVGROWSIZE-12)as MBMXRL
        ,ST.IASP_NUMBER as MBASP
        ,TP.TABLE_SCHEMA as MBLIB
        ,TP.SYSTEM_TABLE_NAME as MBFILE
        ,TP.SYSTEM_TABLE_MEMBER as MBNAME
        ,TP.SOURCE_TYPE as MBSEU2
        ,varchar(ifnull(PARTITION_TEXT,'') || case when TP.SYSTEM_TABLE_SCHEMA like 'PG%' and TP.SYSTEM_TABLE_SCHEMA <> 'PGMT' 
                                                   then ' ('||TP.SYSTEM_TABLE_SCHEMA||')' else '' end) as MBMTXT 
        ,TP.NUMBER_ROWS as MBNRCD
        ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
        ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
        ,' ' MBUCNTXT
        ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
        ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
        ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from QSYS2.SYSTABLES as ST  
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
        ) select * from CUSTOM_FILTER_REGEXPR;

    declare C1 cursor with return for 
    with BASE_FILTER (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT
                     ,OUT_FILE ,OUT_FILTER_STYLE_F
                     ,OUT_MBR ,OUT_FILTER_STYLE_M 
                     ,OUT_TYPE ,OUT_FILTER_STYLE_MT

    ) as (
        select distinct 
        (TP.AVGROWSIZE-12)as MBMXRL
        ,A.IASP_NUMBER as MBASP
        ,TP.TABLE_SCHEMA as MBLIB
        ,TP.SYSTEM_TABLE_NAME as MBFILE
        ,TP.SYSTEM_TABLE_MEMBER as MBNAME
        ,TP.SOURCE_TYPE as MBSEU2
        ,varchar(ifnull(PARTITION_TEXT,'') || case when TP.SYSTEM_TABLE_SCHEMA like 'PG%' and TP.SYSTEM_TABLE_SCHEMA <> 'PGMT' 
                                                   then ' ('||trim(TP.SYSTEM_TABLE_SCHEMA)||')' else '' end) as MBMTXT 
        ,TP.NUMBER_ROWS as MBNRCD
        ,extract(epoch from (TP.CREATE_TIMESTAMP))*1000 as CREATED
        ,extract(epoch from (TP.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
        ,' ' MBUCNTXT
        ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
        ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
        ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from QSYS2.SYSTABLES as A 
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
      ) select * from BASE_FILTER ;
      
    declare C0 cursor with return for   
        select NO_RESULTS.*
        ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
        ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
        ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        ,HWKLIB,HWKFIL
        from table ( values (int(0),smallint(0),'','','','','*** Empty list ***',0,bigint(0),bigint(0),'') )
              NO_RESULTS (MBMXRL,MBASP,MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,MBNRCD,CREATED,CHANGED,MBUCNTXT)
        ;
    
    
    open QUERY_STYLE_CSR;
    fetch QUERY_STYLE_CSR
    into FILTER_STYLE_F,FILTER_STRING_F,FILTER_STYLE_M,FILTER_STRING_M,FILTER_STYLE_MT,FILTER_STRING_MT,HWKLIB,HWKFIL; 
     
    case 
/*9*/when FILTER_STYLE_M = 9 and substr(FILTER_STRING_MT,5,4) = '$FSU' then
        open C9_FSU;      
/*9*/when FILTER_STYLE_M = 9 and substr(FILTER_STRING_MT,5,4) = '$DOU' then
        open C9_DOU;      
/*9*/when FILTER_STYLE_M = 9 and substr(FILTER_STRING_MT,5,4) = '$DPO' then       
        open C9_DPO;      
        
/*3*/when FILTER_STYLE_M = 3 then 
        open C3;
/*4*/when FILTER_STYLE_M = 4 then
        open C4;
/*2*/when FILTER_STYLE_M = 2 then 
        open C2;
--     
/*1*/when FILTER_STYLE_M = 1 then 
          open C1;
    else
        open C0;
    end case;
    
end; 
comment on specific procedure VSC00APC11 is 'Return list of source members for VS Code - Custom Code'; 
  label on specific procedure VSC00APC11 is 'Return list of source members for VS Code-Custom'; 
-- /* Testing query 
 
;call VSC_GETMEMBERLISTCUSTOM_SP( )
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'Q*' ,IN_MBR => 'KRN*',IN_DEBUG_PARMS=>'Y' )
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '*',IN_DEBUG_PARMS=>'Y' )
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => NULL ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'D2WFIQUAL' ,IN_SRCF => 'Q*' ,IN_MBR => 'KRN05*' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'D2WFIINTG' ,IN_SRCF => 'QTXTSRC' ,IN_MBR => '*' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'D2WFIINTG' ,IN_SRCF => 'QTXTSRC' ,IN_MBR =>  '#PCRPRJ00101' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'D2WFIINTG' ,IN_SRCF => '*' ,IN_MBR =>  '#PCRPRJ00101' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'Q*' ,IN_MBR => '^......FN..' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'Q*' ,IN_MBR => '^KRN...FN..' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'Q*' ,IN_MBR => '#PCR2066900' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFIQUAL' ,IN_SRCF => 'Q*' ,IN_MBR => '#PCRPRJ00120' ,IN_DEBUG_PARMS=>'Y')
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFISRC'  ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/EML10ACL' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') /* C9_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFISRC'  ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') /* C9_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFISRC'  ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/EML10ACL' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') /* C9_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFISRC'  ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIDTA/PRPEMPPF' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') /* C9_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFISRC'  ,IN_SRCF => 'QDDSSRC'   ,IN_MBR => 'WFIDTA/PRPPTOTH' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') /* C9_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'WFISRC'  ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIDTA/PRPPTOTH' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') /* C9_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'PGDR  '  ,IN_SRCF => 'QRPGSRC'   ,IN_DEBUG_PARMS=>'Y') /* C1_ */
;call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => 'PGMT  '  ,IN_SRCF => 'QRPGSRC'   ,IN_DEBUG_PARMS=>'Y') /* C1_ */
-- */
