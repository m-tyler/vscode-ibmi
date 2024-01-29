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
set path *LIBL ; 
create or replace function ILEDITOR.VSC_getSourceFileListCustom
( 
  IN_LIB  char(10)  
 ,IN_SRCF char(10) default null
 ,IN_MBR varchar(256) default null
 ,IN_MBR_TYPE varchar(64) default null 
 ,IN_DEBUG_PARMS char(1) default null
       ) 
returns table ( 
 PHLIB varchar(10)
,PHFILE varchar(10)
,PHFILA varchar(10)
,PHDTAT char(1)
,PHTXT varchar(128)
,PHNOMB int
,OUT_FILE varchar(64)
,OUT_FILTER_STYLE_F int
,OUT_MBR varchar(256)
,OUT_FILTER_STYLE_M int
,OUT_MBR_TYPE varchar(64)
,OUT_FILTER_STYLE_MT int
,OUT_CTE_SRC char(1)
) 
 language sql 
 specific VSC00AFN03 
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
        values ( case when locate( '*' ,trim(IN_SRCF)) > 0 then 1 else 0 end -- GENERICS/SPEICIFC
                ,case when substring(IN_MBR_TYPE, 1,4) = '$HWK' then 9 -- CUSTOM FILTERING - HAWKEYE
                      when substring(IN_MBR, 1,7) = '#PCRPRJ'   then 4 -- CUSTOM FILTERING - CMS by PROJECT#
                      when substring(IN_MBR, 1,4) = '#PCR'      then 3 -- CUSTOM FILTERING - CMS
                      when substring(IN_MBR, 1,1) = '^'         then 2 -- REGEXP_LIKE
                      when locate('*',IN_MBR)     > 0           then 1 -- GENERICS
                      else 0 end                                  -- SPECIFIC
                ,case when substring(IN_MBR_TYPE, 1,4) = '$HWK'    then 9 -- CUSTOM FILTERING - HAWKEYE
                      when substring(IN_MBR_TYPE, 1,7) = '#PCRPRJ' then 4 -- CUSTOM FILTERING - CMS by PROJECT#
                      when substring(IN_MBR_TYPE, 1,4) = '#PCR'    then 3 -- CUSTOM FILTERING - CMS
                      when substring(IN_MBR_TYPE, 1,1) = '^'       then 2 -- REGEXP_LIKE
                      when locate('*',IN_MBR_TYPE)     > 0         then 1 -- GENERICS
                      else 0 end                                  -- SPECIFIC
            )
    )
    ,FILTER_STRINGS ( FILTER_STYLE_F ,FILTER_STRING_F ,FILTER_STYLE_M ,FILTER_STRING_M ,FILTER_STYLE_MT ,FILTER_STRING_MT ) as (
         select 
           FILTER_STYLE_F ,case when FILTER_STYLE_F = 1 then replace(replace(trim(IN_SRCF),'*ALL','%'),'*','%') else IN_SRCF end
          ,FILTER_STYLE_M ,case when FILTER_STYLE_M = 3 then substr(IN_MBR,2,10) when FILTER_STYLE_M = 4 then substr(IN_MBR,8,5) when FILTER_STYLE_M = 5 then replace(trim(IN_MBR),'%','*') else IN_MBR end 
          ,FILTER_STYLE_MT ,case when FILTER_STYLE_MT = 1 then replace(trim(IN_MBR_TYPE),'*','%') else IN_MBR_TYPE end 
               
        from FILTER_STYLES )
    ,NO_RESULTS (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,SRC) as (
         values (nullif(' ',' '),x'A1','*PHY ','S',0 ,' ',0,' ')
         )
    ,Hawk_filters (LIB,FIL) as (select case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,1,(locate('/', FILTER_STRING_M)-1)) else 'x' end
                                      ,case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,(locate('/', FILTER_STRING_M)+1)  ) else 'y' end
                                from FILTER_STRINGS 
                      )              
    ,CUSTOM_FILTER_HAWKEYE (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,PHTXT) as ( 
        select IN_LIB PHLIB,PHFILE,PHFILA,PHDTAT,count(*),'('||count(*)||')',length(('('||count(*)||')')),PHTXT from FILTER_STRINGS F inner join HAWK_FILTERS HWK on FILTER_STYLE_MT = 9 and substr(IN_MBR_TYPE,5,4) = '$FSU' 
        inner join table( ILEDITOR.VSC_getHawkeyeFileSetUseList(IN_LIB=> HWK.LIB ,IN_FILE=> HWK.FIL ) ) x on 1=1
        group by IN_LIB,PHFILE,PHFILA,PHDTAT,PHTXT
        union ALL
        select IN_LIB PHLIB,PHFILE,PHFILA,PHDTAT,count(*),'('||count(*)||')',length(('('||count(*)||')')),PHTXT from FILTER_STRINGS F inner join HAWK_FILTERS HWK on FILTER_STYLE_MT = 9 and substr(IN_MBR_TYPE,5,4) = '$DOU' 
        inner join table( ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> HWK.LIB ,IN_OBJ=> HWK.FIL ) ) x on 1=1
        group by IN_LIB,PHFILE,PHFILA,PHDTAT,PHTXT
        union ALL
        select IN_LIB PHLIB,PHFILE,PHFILA,PHDTAT,count(*),'('||count(*)||')',length(('('||count(*)||')')),PHTXT from FILTER_STRINGS F inner join HAWK_FILTERS HWK on FILTER_STYLE_MT = 9 and substr(IN_MBR_TYPE,5,4) = '$DPO' 
        inner join table( ILEDITOR.VSC_getHawkeyeProgramObjectsList(IN_LIB=> HWK.LIB ,IN_OBJ=> HWK.FIL ) ) x on 1=1
        group by IN_LIB,PHFILE,PHFILA,PHDTAT,PHTXT
    )
    ,CUSTOM_FILTER_CMS (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN) as ( 
        select PCR.LIBRARY_ as PHLIB ,PCR.SRCF as PHFILE 
        ,'*PHY' PHFILA ,'S' PHDTAT 
        ,count(TP.SRCTYPE) asPHNOMB 
        ,'('||count(TP.SRCTYPE)||')' as PHNOMB_T
        ,length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
        
        from FILTER_STRINGS F
        inner join table( ILEDITOR.CMS_GETPCROBJECTS( IN_TASK => FILTER_STRING_M ,IN_ENV => '*NA' ) ) PCR on PCR.LIBRARY_ = IN_LIB and FILTER_STYLE_M = 3 
        left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = PCR.LIBRARY_ and TP.TABLE_NAME = PCR.SRCF 
                and PCR.SRCM = TP.TABLE_PARTITION
        where FILTER_STYLE_M = 3 
          and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
             or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
              )
        group by PCR.LIBRARY_ ,PCR.SRCF 
    )    
    ,CUSTOM_FILTER_CMS_BYP (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN) as ( 
        select PCR.LIBRARY_ as PHLIB ,PCR.SRCF as PHFILE 
        ,'*PHY' PHFILA ,'S' PHDTAT 
        ,count(TP.SRCTYPE) asPHNOMB 
        ,'('||count(TP.SRCTYPE)||')' as PHNOMB_T
        ,length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
        
        from FILTER_STRINGS F
        inner join table( ILEDITOR.CMS_GETPCROBJECTS( IN_PRJ_NUM => FILTER_STRING_M ,IN_ENV => '*NA' ) ) PCR on PCR.LIBRARY_ = IN_LIB and FILTER_STYLE_M = 4 
        left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = PCR.LIBRARY_ and TP.TABLE_NAME = PCR.SRCF 
                and PCR.SRCM = TP.TABLE_PARTITION
        where FILTER_STYLE_M = 4 
        --   and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
        --      or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
        --       )
        group by PCR.LIBRARY_ ,PCR.SRCF 
    )    
    ,CUSTOM_FILTER_REG_EXPR (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN)
    as (select TP.SYSTEM_TABLE_SCHEMA ,TP.SYSTEM_TABLE_NAME as PHFILE 
        ,'*PHY' PHFILA ,'S' PHDTAT 
        ,count(TP.SRCTYPE) asPHNOMB 
        ,'('||count(TP.SRCTYPE)||')' as PHNOMB_T
        ,length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
        from FILTER_STRINGS F 
        left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = IN_LIB and TP.SRCTYPE is not null and FILTER_STYLE_M = 2
        where FILTER_STYLE_M = 2 
        and regexp_like( TP.SYSTEM_TABLE_MEMBER ,FILTER_STRING_M ,1,'c')
        and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = TP.TABLE_NAME )
           or FILTER_STYLE_F = 1 and ( TP.TABLE_NAME like FILTER_STRING_F )
            )
        group by TP.SYSTEM_TABLE_SCHEMA ,TP.SYSTEM_TABLE_NAME
        )
    ,CUSTOM_FILTER_BASIC (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN)
    as (select ST.SYSTEM_TABLE_SCHEMA ,ST.SYSTEM_TABLE_NAME as PHFILE 
        ,'*PHY' PHFILA ,'S' PHDTAT 
        , count(TP.SRCTYPE) asPHNOMB 
        ,'('||count(TP.SRCTYPE)||')' as PHNOMB_T
        , length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
        from FILTER_STRINGS F 
        left join QSYS2.SYSTABLES as ST on ST.SYSTEM_TABLE_SCHEMA = IN_LIB and ST.FILE_TYPE = 'S' and FILTER_STYLE_M in (1,2)
        left join QSYS2.SYSPARTITIONSTAT as TP on TP.SYSTEM_TABLE_SCHEMA = ST.SYSTEM_TABLE_SCHEMA and TP.SYSTEM_TABLE_NAME = ST.SYSTEM_TABLE_NAME
        and TP.SRCTYPE is not null
        where FILTER_STYLE_M in (1,2) 
        and ( FILTER_STYLE_M = 1 and TP.SYSTEM_TABLE_MEMBER is null
          or  FILTER_STYLE_M = 1 and TP.SYSTEM_TABLE_MEMBER like (replace(trim(FILTER_STRING_M),'*','%'))
          or  FILTER_STYLE_M = 0 and ( FILTER_STRING_M is null or TP.SYSTEM_TABLE_MEMBER = FILTER_STRING_M )
          )
        and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = ST.SYSTEM_TABLE_NAME )
           or FILTER_STYLE_F = 1 and ( ST.SYSTEM_TABLE_NAME like FILTER_STRING_F )
            )
        group by ST.SYSTEM_TABLE_SCHEMA ,ST.SYSTEM_TABLE_NAME
        )        
    ,COMBINED_GROUPS (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,SRC) 
    as (
        select PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN,'H' from CUSTOM_FILTER_HAWKEYE HWK
        union
        select CMS.*,'C' from CUSTOM_FILTER_CMS CMS
        union
        select CMS.*,'C' from CUSTOM_FILTER_CMS_BYP CMS
        union
        select RE.*,'R' from CUSTOM_FILTER_REG_EXPR RE
        union
        select  B.*,'B' from CUSTOM_FILTER_BASIC B
        
    )
    ,COMBINED_GROUP_QTY as ( select count(*) CG_QTY from COMBINED_GROUPS )    
    ,COMBINED_GROUPS_2 (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,SRC) 
    as (
        select * from COMBINED_GROUPS 
        union
        select * from NO_RESULTS where (select CG_QTY from COMBINED_GROUP_QTY) = 0 and IN_DEBUG_PARMS is not null
    )

    ,APPLY_TEXT (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHTXT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,SRC) 
    as (select ifnull(CG.PHLIB ,' ') ,CG.PHFILE ,CG.PHFILA ,CG.PHDTAT  
        ,case when CG.PHLIB is null then char('Empty list ***',50) 
         else 
            case when SRC = 'H' then HWK.PHTXT else ifnull(OBJTEXT,char(' ',50)) end end PHTXT  
        ,CG.PHNOMB ,CG.PHNOMB_T ,CG.PHNOMB_T_LEN ,CG.SRC
        from COMBINED_GROUPS_2 CG
        left join CUSTOM_FILTER_HAWKEYE HWK on HWK.PHLIB = CG.PHLIB and HWK.PHFILE = CG.PHFILE and HWK.PHNOMB = CG.PHNOMB
        left join lateral(select * from table(qsys2.object_statistics(CG.PHLIB, '*FILE', CG.PHFILE))) OT on 1=1
    )
    select PHLIB ,PHFILE, PHFILA, PHDTAT
    ,substr((case when PHNOMB_T_LEN > 0 then (trim(PHTXT)||' ('||PHNOMB||')') else PHTXT end ),1,128) PHTXT 
--     ,case when PHNOMB_T_LEN > 0 then replace( (substr(PHTXT,1,50-PHNOMB_T_LEN)||'('||PHNOMB||')'),'  ',' .') else PHTXT end PHTXT 
--     ,case when PHNOMB_T_LEN > 0 then replace( substr(('('||PHNOMB||') '||PHTXT),1,50-PHNOMB_T_LEN),'  ',' .') else PHTXT end PHTXT
--     ,case when PHNOMB_T_LEN > 0 then substr(('('||PHNOMB||') '||PHTXT),1,50-PHNOMB_T_LEN) else PHTXT end PHTXT
    ,PHNOMB
    ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
    ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M 
    ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT 
    ,SRC

    from FILTER_STRINGS cross join APPLY_TEXT
--     where FILTER_STYLE_M in (0,1,2,3)
;
end; 
comment on specific function VSC00AFN03 is 'Return list of source files for VS Code'; 
  label on specific function VSC00AFN03 is 'Return list of source files for VS Code'; 
/* Testing query 
 
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIQUAL' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ) )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ) )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ) )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '*', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '^CVT19355', IN_LIB => 'PGMT' ) )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_MBR => '#PCR1824200', IN_LIB => 'WFIQUAL' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_LIB => 'CVTQUAL' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '^CVT19700'  ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'KRONOSDATAFEEDREQUEST' ,IN_MBR => '*'  ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => '*ALL' ,IN_MBR => '*'  ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'Q*' ,IN_MBR => '*'  ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1960600', IN_LIB => 'CVTQUAL' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => '*ALL' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => '*' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => '*' ,IN_MBR => 'KRN66*', IN_LIB => 'PGMT' ) )

;create or replace variable IN_MBR Varchar(64)
;create or replace variable IN_LIB  char(10)  
;create or replace variable IN_SRCF char(10) default null
;create or replace variable IN_MBR_TYPE char(64) default null
;set IN_MBR = 'KRN05*'
;set IN_MBR = 'KRN05ARG'
;set IN_MBR = '^KRN05ARG'
;set IN_MBR = '^KRN05(A|B)(RG|FM)|^HRM65'
;set IN_MBR = '#PCR1708800'
;set IN_LIB = 'D2WFIINTG'
;set IN_SRCF = 'QRPGSRC '
;set IN_MBR_TYPE = 'SQLRPGLE'
;values  (IN_MBR,IN_LIB,IN_SRCF,substr(IN_MBR,2,11))
 
;values x'ff'
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'TSTSRC' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELIST(IN_SRCF => 'TSTSRC' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1976200', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1970000', IN_LIB => 'WFIQUAL' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1970000', IN_LIB => 'WFISRC' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'WFISRC' ) )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2030600', IN_LIB => 'WFISRC' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2030600', IN_LIB => 'WFIINTG' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2030600', IN_LIB => 'WFIQUAL' ) )

;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2030600', IN_LIB => 'PGMT' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => '*ALL' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )
-- ;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'PRPEMPPF' ,IN_MBR => '$HWK', IN_LIB => 'WFIDTA' ) )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'WFIDTA/PRPEMPPF' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'WFIOBJ/EML10ACL' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '*ALL/EML10ACL' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '*ALL/PRINTPR' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '*ALL/PRP03ZRG' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
;select * from table ( VSC_getSourceFileListCustom (IN_SRCF => 'Q*' ,IN_MBR => 'CVT20306R*', IN_LIB => 'WFICVT' ,IN_MBR_TYPE => '*' ) )
;create or replace table pgmt/demo1 (PHLIB,PHFILE,PHFILA,PHDTAT,PHTXT,PHNOMB,OUT_FILE,OUT_FILTER_STYLE_F,OUT_MBR,OUT_FILTER_STYLE_M,OUT_MBR_TYPE,OUT_FILTER_STYLE_MT) as 
-- ;
(select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2030600', IN_LIB => 'WFIINTG' ) )) with data
ON REPLACE DELETE ROWS
;select * from table ( ILEDITOR.VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCRPRJ0010', IN_LIB => 'D2WFIQUAL' ) )
;select * from table ( ILEDITOR.VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) )

;create or replace table ILEDITOR.O_4BHbJOYJ (PHLIB,PHFILE,PHFILA,PHDTAT,PHTXT) as 
      (
;select * from table ( VSC_getSourceFileListCustom (IN_SRCF => 'Q*' ,IN_MBR => '*ALL/KRN05CRG', IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DOU' ) )
-- ) with data
--         on replace delete rows
;select * from ILEDITOR.O_4BHbJOYJ

 */
;select * from table ( ILEDITOR.VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCRPRJ00101', IN_LIB => 'D2WFIQUAL' ) )
;select * from table ( ILEDITOR.VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) )
;select * from table ( ILEDITOR.VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'KRN*', IN_LIB => 'WFISRC' ) )