;cl:chgcurlib ILEDITOR;
;set current path ILEDITOR, SYSTEM PATH
-- ;cl:chgcurlib [USER];
-- ;set path [USER]
-- ;select * from LIBRARY_LIST_INFO

;create or replace function VSC_getHawkeyeProgramObjectsList
(
  IN_LIB  char(10)
 ,IN_OBJ char(10)
 ,IN_MBR varchar(64) default null
--  ,IN_MBR_TYPE varchar(64) default null
 ,IN_DEBUG_PARMS char(1) default null

       )
returns table (
 OUXREF varchar(10)
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
 specific VSC00AFN83
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
VSC00AFN83: begin
    declare cmdstring varchar(256);
    declare SQLSTATE char(5);
    declare SQLCODE int;
    declare APISF  char(10) default ' ';
    declare APISFL char(10) default ' ';
    declare APISFM char(10) default ' ';

  /* SetUp a condition handler to deal with the date error
   *  we may get from the SET statement.
   */
    declare HWK_ERROR condition for sqlstate '38501';
    declare continue handler for HWK_ERROR
    begin
    end;

    set cmdstring = 'DSPPGMOBJ PGM(QGPL/ENDTRACE) OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DPO) OUTMBR(*FIRST *REPLACE)';
    call qcmdexc( cmdstring );
    if IN_DEBUG_PARMS = 'Y' then 
        call systools.lprintf( '>>>>> ' ||cmdstring );
    end if;
    set cmdstring = 'create or replace alias VSC_T$DPO_ for '||trim(user)||'/VSC_T$DPO';
    execute immediate cmdstring;
    if IN_DEBUG_PARMS = 'Y' then 
        call systools.lprintf(SQLSTATE ||':'||SQLCODE);
    end if;
    set cmdstring = 'CLRPFM FILE('||trim(user)||'/VSC_T$DPO)';
    call qcmdexc( cmdstring );

    If IN_LIB > ' '  and IN_OBJ > ' '  then
      set cmdstring = 'DSPPGMOBJ PGM(' ||trim(IN_LIB) ||'/' ||trim(IN_OBJ)||') OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DPO)';
      if IN_DEBUG_PARMS = 'Y' then 
        call systools.lprintf( '>>>>> ' ||cmdstring );
      end if;
      call qcmdexc( cmdstring );
      if SQLSTATE > '01000' then
        call systools.lprintf( 'ERROR> ' ||cmdstring );
      end if;

      update VSC_T$DPO o
      set (PODSFL,PODSLB,PODSMB) = (select APISF,APISFL,APISFM
                                    from table ( VSC_GETHAWKEYEPROGRAMOBJECTSOURCELISTTF(APITYP => '20' ,APIOPT => '80'
                                                                                        ,APIOB => o.PODOBJ ,APIOBL => o.PODLIB
                                                                                        ,APIOBM => ' ' ,APIOBA => o.PODTYP) ))
      where (PODSFL,PODSLB,PODSMB) = (' ',' ',' ') or PODSFL ='Z_INTSQL_Z' or PODSLB like 'ACMS#%';
    else
      call systools.lprintf( '>>>>> ' ||'IN_LIB=>'||INLIB ||', IN_OBJ=> '||INOBJ );
    End if;

    return with  CONDENSE_HOW_USED (PODLIB ,PODOBJ ,LANG_TYP ,OPERATE_TYPS) as (
        select PODLIB ,PODOBJ
        ,left(PODCMD,(case locate('-',PODCMD) when 0 then length(PODCMD) else locate('-',PODCMD) end)) As LANG_TYP
        ,listagg(distinct trim(right(PODCMD,locate('-',PODCMD)+2)), ':')
            within group (order by PODLIB ,PODOBJ  ,PODCMD ) as OPERATE_TYPS
        from VSC_T$DPO_
        where PODCMD not in ('BIND','ENTMOD')
        group by PODLIB ,PODOBJ ,left(PODCMD,(case locate('-',PODCMD) when 0 then length(PODCMD) else locate('-',PODCMD) end))
    )
    select distinct POXREF
        ,case when POHSLB = '    ' then '*NONE' else VSC.PODLIB end PHLIB
        ,case when POHSFL = '    ' then '*NONE' else case when PODSFL = '    ' then '*NONE' else PODSFL end end PHFILE
        ,'*PHY' PHFILA ,'S' PHDTAT ,'' PHTXT
        ,ifnull(IASP_NUMBER,1) ,ifnull(ROW_LENGTH,0)
        ,case when PODSLB <> '      '  then PODSLB  else VSC.PODLIB end MBLIB
        ,case when PODSFL = '    ' then '*NONE' else PODSFL end MBFILE
        ,VSC.PODOBJ MBNAME
        ,case when PODSFL <> '      '  then PODATR  else '*NONE' end MBSEU2
        , trim((LANG_TYP ||OPERATE_TYPS))||' - '|| PODTXT  MBMTXT

    from VSC_T$DPO_ VSC inner join CONDENSE_HOW_USED CHU on VSC.PODLIB = CHU.PODLIB and VSC.PODOBJ = CHU.PODOBJ
    left  join SYSTABLES on SYSTEM_TABLE_NAME = (case when PODSFL = '    ' then '*NONE' else PODSFL end)
                        and SYSTEM_TABLE_SCHEMA = (case when PODSLB <> '      '  then PODSLB  else VSC.PODLIB end)
    where POHPGM=IN_OBJ and case when IN_LIB = '*ALL' then IN_LIB else POHLIB end =IN_LIB
    ;

end VSC00AFN83;

-- ;select * from table(VSC_getHawkeyeObjecOUseList(IN_LIB=> 'WFIDTA',IN_OBJ=>'PRPTJCTB' ,IN_TLIB=>'PGMT' ,IN_TFILE=>'VSC_T12345')) x
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'PRP03ZRG')) x order by MBLIB ,MBNAME
-- ;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> 'WFIDTA',IN_OBJ=>'PRPEMPPF')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'HRM67ERG',IN_DEBUG_PARMS=>'Y')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10ACL',IN_DEBUG_PARMS=>'Y')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10HCL',IN_DEBUG_PARMS=>'Y')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> '*ALL  ',IN_OBJ=>'EML10HCL',IN_DEBUG_PARMS=>'Y')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10HCLx',IN_DEBUG_PARMS=>'Y')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeProgramObjectsList(IN_LIB=> ' ',IN_OBJ=>' ')) x

;select * from table(VSC_getHawkeyeProgramObjectSourceListTF(APITYP => '20' ,APIOPT => '80',APIOB => 'PRPBATI0', APIOBL => 'WFIDTA', APIOBM => ' ', APIOBA => '*FILE') )