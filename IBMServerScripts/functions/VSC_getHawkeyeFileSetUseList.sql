/*============================================================================ 
   SPECIFIC NAME..: VSC00AFN81                                                 
   FUNCTION NAME..: VSC_getHawkeyeFileSetUseList                                          
   AUTHOR.........: Matt Tyler                                                 
   DATE...........: 06/07/2022                                                 
   PCR #..........: XXXXX 00                                                   
   FUNCTION/DESC..: Return list of objects checked out to PCR                  
                                                                               
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

;create or replace function VSC_getHawkeyeFileSetUseList
(
  IN_LIB  char(10)
 ,IN_FILE char(10)
 ,IN_MBR varchar(64) default null
--  ,IN_MBR_TYPE varchar(64) default null
 ,IN_DEBUG_PARMS char(1) default null

       )
returns table (
 TUXREF varchar(10)
,PHLIB varchar(10)
,PHFILE varchar(10)
,PHFILA varchar(10)
,PHDTAT char(1)
,PHTXT varchar(128)
,MBRCDL int
,MBASP int
,MBLIB varchar(10)
,MBFILE varchar(10)
,MBNAME varchar(10)
,MBSEU2 varchar(10) -- Member type longer version
,MBMTXT varchar(180)
)

 language sql
 specific VSC00AFN81
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
VSC00AFN81: begin
    declare cmdstring varchar(256);
    declare SQLSTATE char(5);

  /* Setup a condition handler to deal with the date error
   *  we may get from the SET statement.
   */
    declare HWK_ERROR condition for sqlstate '38501';
    declare continue handler for HWK_ERROR
    begin
    end;

    set cmdstring = 'DSPFILSETU FILE(QAUOOPT) OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$FSU)  OUTMBR(*FIRST *REPLACE)';
    call qcmdexc( cmdstring );
    set cmdstring = 'create or replace alias VSC_T$FSU_ for '||trim(user)||'/VSC_T$FSU';
    if IN_DEBUG_PARMS = 'Y' then 
        call systools.lprintf( '>>>>> ' ||cmdstring );
    end if;
    execute immediate cmdstring;
    set cmdstring = 'CLRPFM FILE('||trim(user)||'/VSC_T$FSU)';
    if IN_DEBUG_PARMS = 'Y' then 
        call systools.lprintf( '>>>>> ' ||cmdstring );
    end if;
    call qcmdexc( cmdstring );

    If IN_LIB > ' '  and IN_FILE > ' ' then
        set cmdstring = 'DSPFILSETU FILE(' ||trim(IN_LIB) ||'/' ||trim(IN_FILE)||') OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$FSU) OUTMBR(*FIRST *REPLACE)';
        if IN_DEBUG_PARMS = 'Y' then 
            call systools.lprintf( '>>>>> ' ||cmdstring );
        end if;
        call qcmdexc( cmdstring );
    End if;


    return with  CONDENSE_HOW_USED (TUDLIB ,TUDPGM ,LANG_TYP ,OPERATE_TYPS) as (
        select TUDLIB ,TUDPGM
        ,left(TUDHOW,(case locate('-',TUDHOW) when 0 then length(TUDHOW) else locate('-',TUDHOW) end)) As LANG_TYP
        ,listagg(distinct trim(right(TUDHOW,locate('-',TUDHOW)+2)), ':')
            within group (order by TUDLIB ,TUDPGM  ,TUDHOW ) as OPERATE_TYPS
        from VSC_T$FSU_
        where 1=1 
        group by TUDLIB ,TUDPGM ,left(TUDHOW,(case locate('-',TUDHOW) when 0 then length(TUDHOW) else locate('-',TUDHOW) end))
    )
    select distinct TUXREF
        ,case when TUDSLB = '    ' then '*NONE' else TUDSLB end PHLIB
        ,case when TUDSFL = '    ' then '*NONE' else TUDSFL end PHFILE
        ,'*PHY' PHFILA ,'S' PHDTAT ,TUHTXT PHTXT
        ,ifnull(IASP_NUMBER,1) ,ifnull(ROW_LENGTH,0)
        ,case when TUDSLB <> '      '  then TUDSLB  else VSC.TUDLIB end MBLIB
        ,case when TUDSFL = '    ' then '*NONE' else TUDSFL end MBFILE
        ,VSC.TUDPGM MBNAME
        ,case when TUDSFL <> '      '  then TUDATR  else '*NONE' end MBSEU2
        , trim((LANG_TYP ||OPERATE_TYPS))||' - '|| TUDTXT  MBMTXT

    from VSC_T$FSU_ VSC inner join CONDENSE_HOW_USED CHU on VSC.TUDLIB = CHU.TUDLIB and VSC.TUDPGM = CHU.TUDPGM
    left  join SYSTABLES on SYSTEM_TABLE_NAME = (case when TUDSFL = '    ' then '*NONE' else TUDSFL end)
                        and SYSTEM_TABLE_SCHEMA = (case when TUDSLB <> '      '  then TUDSLB  else VSC.TUDLIB end)
    where TUHFIL=IN_FILE and case when IN_LIB = '*ALL' then IN_LIB else TUHLIB end =IN_LIB
    ;


end VSC00AFN81;

-- ;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPTJCTB' ,IN_TLIB=>'PGMT' ,IN_TFILE=>'VSC_T12345')) x
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPTJCTB')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPTJCTB'                     )) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPPTOTH')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPEMPPF')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA',IN_FILE=>'PRPEMPPFx')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> ' ',IN_FILE=>' ')) x
;select * from table(VSC_getHawkeyeFileSetUseList(IN_LIB=> 'WFIDTA' ,IN_FILE=> 'PRPPTOTH', IN_DEBUG_PARMS=>'Y')) x where MBFILE = 'QRPGSRC'