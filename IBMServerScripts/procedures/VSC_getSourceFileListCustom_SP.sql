/*============================================================================
   SPECIFIC NAME..: VSC00APC03
   PROCEDURE NAME..: VSC_getSourceFileListCustom_SP
   AUTHOR.........: Matt Tyler
   DATE...........: 09/22/2022
   PCR #..........: XXXXX 00
   PROCEDURE/DESC..: Return list of source files for VS Code

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

;create or replace procedure VSC_getSourceFileListCustom_SP
(
  IN_LIB  char(10)
 ,IN_SRCF char(10) default '*'
 ,IN_MBR varchar(256) default '*'
 ,IN_MBR_TYPE varchar(64) default '*'
 ,IN_DEBUG_PARMS char(1) default null
)
 language sql
 specific VSC00APC03
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
                    when substring(IN_MBR, 1,1) = '#'    then 3 -- CUSTOM FILTERING - CMS
                    when substring(IN_MBR, 1,1) = '^'    then 2 -- REGEXP_LIKE
                    when locate('*',IN_MBR)     > 0      then 1 -- GENERICS
                    when locate('%',IN_MBR)     > 0      then 1 -- GENERICS
                    when IN_MBR is null                  then 1 -- GENERICS
                    else 0 end
                ,case when substring(IN_MBR_TYPE, 1,4) = '$HWK' then 9 -- CUSTOM FILTERING - HAWKEYE
                    when substring(IN_MBR_TYPE, 1,7) = '#PCRPRJ' then 4 -- CUSTOM FILTERING - CMS BY PROJECT
                    when substring(IN_MBR_TYPE, 1,4) = '#PCR' then 3 -- CUSTOM FILTERING - CMS
                    when substring(IN_MBR_TYPE, 1,1) = '#'    then 3 -- CUSTOM FILTERING - CMS
                    when substring(IN_MBR_TYPE, 1,1) = '^'    then 2 -- REGEXP_LIKE
                    when locate('*',IN_MBR_TYPE)     > 0      then 1 -- GENERICS
                    when locate('%',IN_MBR_TYPE)     > 0      then 1 -- GENERICS
                    when IN_MBR_TYPE is null                  then 1 -- GENERICS
                    else 0 end
            )
    )
    ,FILTER_STRINGS ( FILTER_STYLE_F ,FILTER_STRING_F ,FILTER_STYLE_M ,FILTER_STRING_M ,FILTER_STYLE_MT ,FILTER_STRING_MT ) as (
         select
           FILTER_STYLE_F ,case when FILTER_STYLE_F = 1 then replace(replace(trim(IN_SRCF), '*ALL', '%'), '*', '%') else IN_SRCF end
          ,FILTER_STYLE_M ,case when FILTER_STYLE_M = 3 then substr(IN_MBR,2,10)
                                when FILTER_STYLE_M = 4 then substr(IN_MBR,8,5)
                                when FILTER_STYLE_M = 9 then case when IN_MBR is not null then replace(trim(IN_MBR),'%','*') else '%' end
                                else IN_MBR end
          ,FILTER_STYLE_MT ,case when FILTER_STYLE_MT = 1 then case when IN_MBR_TYPE is not null then replace(trim(IN_MBR_TYPE),'*','%') else '%' end
                                 else IN_MBR_TYPE end

        from FILTER_STYLES )
    ,HAWK_FILTERS (HWKLIB,HWKFIL) as (
        select case when locate('/', FILTER_STRING_M) > 1 then substr(FILTER_STRING_M ,1,(locate('/', FILTER_STRING_M)-1)) else 'x' end
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
        with CUSTOM_FILTER_HAWKEYE_FSU (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,PHTXT)
        as (
            select IN_LIB PHLIB,PHFILE,PHFILA,PHDTAT,count(*),'('||count(*)||')',length(('('||count(*)||')')),PHTXT
            from table( VSC_getHawkeyeFileSetUseList(IN_LIB=> HWKLIB ,IN_FILE=> HWKFIL ) ) x
            group by IN_LIB,PHFILE,PHFILA,PHDTAT,PHTXT
        )
        select PHLIB ,PHFILE, PHFILA, PHDTAT
            ,substr((case when PHNOMB_T_LEN > 0 then (trim(PHTXT)||PHNOMB_T) else PHTXT end ),1,128) PHTXT
            ,PHNOMB  ,dec(37,5,0) PHCSID , dec(120,5,0) PHMXRL
            ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
            ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
            ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from CUSTOM_FILTER_HAWKEYE_FSU HWK;

    declare C9_DOU cursor with return for
        with CUSTOM_FILTER_HAWKEYE_DOU (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,PHTXT)
        as (
            select IN_LIB PHLIB,PHFILE,PHFILA,PHDTAT,count(*),'('||count(*)||')',length(('('||count(*)||')')),PHTXT
            from table( VSC_getHawkeyeObjectUseList(IN_LIB=> HWKLIB ,IN_OBJ=> HWKFIL ) ) x
            group by IN_LIB,PHFILE,PHFILA,PHDTAT,PHTXT
        )
        select PHLIB ,PHFILE, PHFILA, PHDTAT
            ,substr((case when PHNOMB_T_LEN > 0 then (trim(PHTXT)||PHNOMB_T) else PHTXT end ),1,128) PHTXT
            ,PHNOMB  ,dec(37,5,0) PHCSID , dec(120,5,0) PHMXRL
            ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
            ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
            ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from CUSTOM_FILTER_HAWKEYE_DOU;
--
    declare C9_DPO cursor with return for
        with CUSTOM_FILTER_HAWKEYE_DPO (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,PHTXT)
        as (
            select IN_LIB PHLIB,PHFILE,PHFILA,PHDTAT,count(*),'('||count(*)||')',length(('('||count(*)||')')),PHTXT
            from table( VSC_getHawkeyeProgramObjectsList(IN_LIB=> HWKLIB ,IN_OBJ=> HWKFIL ) ) x
            group by IN_LIB,PHFILE,PHFILA,PHDTAT,PHTXT
        )
        select PHLIB ,PHFILE, PHFILA, PHDTAT
            ,substr((case when PHNOMB_T_LEN > 0 then (trim(PHTXT)||PHNOMB_T) else PHTXT end ),1,128) PHTXT
            ,PHNOMB  ,dec(37,5,0) PHCSID , dec(120,5,0) PHMXRL
            ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
            ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
            ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
        from CUSTOM_FILTER_HAWKEYE_DPO;
--
    declare C3 cursor with return for
        with CUSTOM_FILTER_CMS (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN, PHMXRL)
        as (
            select PCR.LIBRARY_ as PHLIB
              ,PCR.SRCF         as PHFILE
              ,'*PHY'           as PHFILA
              ,'S'              as PHDTAT
              ,count(TP.SRCTYPE) as PHNOMB
              ,'('||count(TP.SRCTYPE)||')' as PHNOMB_T
              ,length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
              ,min(ROW_LENGTH)  as PHMXRL

            from table( CMS_GETPCROBJECTS( IN_TASK => FILTER_STRING_M ,IN_ENV => '*NA' ) ) PCR
            left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = PCR.LIBRARY_ and TP.TABLE_NAME = PCR.SRCF
                    and PCR.SRCM = TP.TABLE_PARTITION
            left join QSYS2.SYSTABLES as ST  on TP.SYSTEM_TABLE_SCHEMA = ST.SYSTEM_TABLE_SCHEMA and TP.SYSTEM_TABLE_NAME = ST.SYSTEM_TABLE_NAME
                    and TP.SRCTYPE is not null
            where (PCR.LIBRARY_ = IN_LIB )
              and ( FILTER_STYLE_F = 0 and ( FILTER_STRING_F is null or FILTER_STRING_F = PCR.SRCF )
                 or FILTER_STYLE_F = 1 and ( PCR.SRCF like FILTER_STRING_F )
                  )
            group by PCR.LIBRARY_ ,PCR.SRCF
           )
           select PHLIB ,PHFILE, PHFILA, PHDTAT
                 ,substr((case when PHNOMB_T_LEN > 0 then (trim(ifnull(OBJTEXT,char(' ',50)))||PHNOMB_T) else '' end ),1,128) PHTXT
                 ,PHNOMB  ,dec(37,5,0) PHCSID ,PHMXRL
                ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
                ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
                ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
           from CUSTOM_FILTER_CMS CMS
           left join lateral(select * from table(qsys2.object_statistics(CMS.PHLIB, '*FILE', CMS.PHFILE))) OT on 1=1
           ;

    declare C4 cursor with return for
        with CUSTOM_FILTER_CMS_BY_PROJECT (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN, PHMXRL)
        as (
            select PCR.LIBRARY_    as PHLIB
                ,PCR.SRCF          as PHFILE
                ,'*PHY'            as PHFILA
                ,'S'               as PHDTAT
                ,count(TP.SRCTYPE) as PHNOMB
                ,'('||count(TP.SRCTYPE)||')' as PHNOMB_T
                ,length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
                ,min(ROW_LENGTH)   as PHMXRL

            from table( CMS_GETPCROBJECTS( IN_PRJ_NUM => FILTER_STRING_M ,IN_ENV => '*NA' ) ) PCR
            left join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = PCR.LIBRARY_ and TP.TABLE_NAME = PCR.SRCF
                    and PCR.SRCM = TP.TABLE_PARTITION
            left join QSYS2.SYSTABLES as ST  on TP.SYSTEM_TABLE_SCHEMA = ST.SYSTEM_TABLE_SCHEMA and TP.SYSTEM_TABLE_NAME = ST.SYSTEM_TABLE_NAME
                    and TP.SRCTYPE is not null
            where ( PCR.LIBRARY_ = IN_LIB )
            group by PCR.LIBRARY_ ,PCR.SRCF
          )
          select PHLIB ,PHFILE, PHFILA, PHDTAT
                 ,substr((case when PHNOMB_T_LEN > 0 then (trim(ifnull(OBJTEXT,char(' ',50)))||PHNOMB_T) else '' end ),1,128) PHTXT
                 ,PHNOMB  ,dec(37,5,0) PHCSID ,PHMXRL
                ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
                ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
                ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
           from CUSTOM_FILTER_CMS_BY_PROJECT CMSP
           left join lateral(select * from table(qsys2.object_statistics(CMSP.PHLIB, '*FILE', CMSP.PHFILE))) OT on 1=1
           ;

    declare C2 cursor with return for
        with CUSTOM_FILTER_REG_EXPR (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN, PHMXRL)
        as (
            select TP.SYSTEM_TABLE_SCHEMA as PHLIB
            ,TP.SYSTEM_TABLE_NAME         as PHFILE
            ,'*PHY'                       as PHFILA
            ,'S'                          as PHDTAT
            ,count(TP.SRCTYPE)            as PHNOMB
            ,'('||count(TP.SRCTYPE)||')'  as PHNOMB_T
            ,length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
            ,min(ROW_LENGTH)              as PHMXRL
            from QSYS2.SYSTABLES as ST
            left join QSYS2.SYSPARTITIONSTAT as TP on TP.SYSTEM_TABLE_SCHEMA = ST.SYSTEM_TABLE_SCHEMA and TP.SYSTEM_TABLE_NAME = ST.SYSTEM_TABLE_NAME
                    and TP.SRCTYPE is not null
            where ST.SYSTEM_TABLE_SCHEMA = IN_LIB
              and ST.FILE_TYPE = 'S'
              and regexp_like( TP.SYSTEM_TABLE_MEMBER ,FILTER_STRING_M ,1,'c')
              and ( FILTER_STYLE_F = 1 and ( ST.SYSTEM_TABLE_NAME like FILTER_STRING_F )
                  )
            group by TP.SYSTEM_TABLE_SCHEMA ,TP.SYSTEM_TABLE_NAME
           )
           select PHLIB ,PHFILE, PHFILA, PHDTAT
                 ,substr((case when PHNOMB_T_LEN > 0 then (trim(ifnull(OBJTEXT,char(' ',50)))||PHNOMB_T) else '' end ),1,128) PHTXT
                 ,PHNOMB  ,dec(37,5,0) PHCSID ,PHMXRL
                 ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
                 ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
                 ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
           from CUSTOM_FILTER_REG_EXPR REGXP
           left join lateral(select * from table(qsys2.object_statistics(PHLIB, '*FILE', PHFILE))) OT on 1=1
           ;


    declare C1 cursor with return for
        with CUSTOM_FILTER_BASIC (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN, PHMXRL)
        as (
            select ST.SYSTEM_TABLE_SCHEMA as PHLIB
            ,ST.SYSTEM_TABLE_NAME         as PHFILE
            ,'*PHY'                       as PHFILA
            ,'S'                          as PHDTAT
            , count(TP.SRCTYPE)           as PHNOMB
            ,' ('||count(TP.SRCTYPE)||')' as PHNOMB_T
            , length(('('||count(TP.SRCTYPE)||')')) as PHNOMB_T_LEN
            ,min(ROW_LENGTH)              as PHMXRL
            from QSYS2.SYSTABLES as ST
            left join QSYS2.SYSPARTITIONSTAT as TP on TP.SYSTEM_TABLE_SCHEMA = ST.SYSTEM_TABLE_SCHEMA and TP.SYSTEM_TABLE_NAME = ST.SYSTEM_TABLE_NAME
                    and TP.SRCTYPE is not null
            where ST.SYSTEM_TABLE_SCHEMA = IN_LIB
              and ST.FILE_TYPE = 'S'
              and ( FILTER_STYLE_F = 0 and ( ST.SYSTEM_TABLE_NAME = FILTER_STRING_F )
                or  FILTER_STYLE_F = 1 and ( ST.SYSTEM_TABLE_NAME like FILTER_STRING_F )
                  )
              and ( FILTER_STYLE_M = 1 and TP.SYSTEM_TABLE_MEMBER is null
                or  FILTER_STYLE_M = 1 and TP.SYSTEM_TABLE_MEMBER like (replace(trim(FILTER_STRING_M),'*','%'))
                  )
            group by ST.SYSTEM_TABLE_SCHEMA ,ST.SYSTEM_TABLE_NAME
           )
           select PHLIB ,PHFILE, PHFILA, PHDTAT
                 ,substr((case when PHNOMB_T_LEN > 0 then (trim(ifnull(OBJTEXT,char(' ',50)))||PHNOMB_T) else '' end ),1,128) PHTXT
                 ,PHNOMB  ,dec(37,5,0) PHCSID ,PHMXRL
                 ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
                 ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
                 ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
           from CUSTOM_FILTER_BASIC BASIC
           left join lateral(select * from table(qsys2.object_statistics(PHLIB, '*FILE', PHFILE))) OT on 1=1
           ;

    declare C0 cursor with return for
        select PHLIB ,PHFILE, PHFILA, PHDTAT
            ,PHTXT
            ,PHNOMB  ,dec(37,5,0) PHCSID , dec(120,5,0) PHMXRL
            ,FILTER_STRING_F as OUT_FILE , FILTER_STYLE_F as OUT_FILTER_STYLE_F
            ,FILTER_STRING_M as OUT_MBR , FILTER_STYLE_M as OUT_FILTER_STYLE_M
            ,FILTER_STRING_MT as OUT_TYPE , FILTER_STYLE_MT as OUT_FILTER_STYLE_MT
            ,HWKLIB,HWKFIL
        from table ( values (nullif(' ',' '),x'A1'  ,'*PHY ','S'    ,0      ,' '      ,0            ,'*** Empty list ***') )
                 NO_RESULTS (PHLIB          ,PHFILE ,PHFILA ,PHDTAT ,PHNOMB ,PHNOMB_T ,PHNOMB_T_LEN ,PHTXT)
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
;

comment on specific procedure VSC00APC03 is 'Return list of source files for VS Code';
  label on specific procedure VSC00APC03 is 'Return list of source files for VS Code';
/* Tests
 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => '*ALL' ,IN_MBR => '*', IN_LIB => 'PGDR' ,IN_DEBUG_PARMS=>'Y' ) /* C4 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => '*ALL' ,IN_MBR => '*', IN_LIB => 'PGMT' ,IN_DEBUG_PARMS=>'Y' ) /* C4 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_LIB => 'PGDR' ,IN_DEBUG_PARMS=>'Y' ) /* C4 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '#PCRPRJ00101', IN_LIB => 'D2WFIQUAL' ) /* C4 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '#PCRPRJ00101', IN_LIB => 'D2WFIINTG' ) /* C4 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) /* C3 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2066900', IN_LIB => 'WFIQUAL' ) /* C3 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2118200', IN_LIB => 'PGMT' , IN_DEBUG_PARMS => 'Y') /* C3 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '#TESTITCHGS', IN_LIB => 'PGMT' , IN_DEBUG_PARMS => 'Y') /* C3 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => 'KRN*', IN_LIB => 'WFISRC' ) /* C1 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'q*' ,IN_MBR => 'krn*', IN_LIB => 'WFISRC' ) /* C1 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => '^KRN...CL', IN_LIB => 'WFISRC' ) /* C2 */
;call VSC_GETSOURCEFILELISTCUSTOM_SP(IN_LIB  => 'WFISRC', IN_SRCF => 'QRPGSRC',IN_MBR => 'PRP04V*', IN_DEBUG_PARMS => 'Y' )
;call vsc_getSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y' ) /* C9_DPO */
;call vsc_getSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y' ) /* C9_DOU */
;call vsc_getSOURCEFILELISTCUSTOM_SP(IN_SRCF => 'Q*' ,IN_MBR => 'WFIDTA/PRPEMPPF' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y' ) /* C9_FSU */