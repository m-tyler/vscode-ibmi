create or replace function ILEDITOR.VSC_getHawkeyeObjectUseList
(
  IN_LIB  char(10)  
 ,IN_OBJ char(10) 
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
 specific VSC00AFN82 
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
VSC00AFN82: begin 
    declare cmdstring varchar(256);
    declare SQLSTATE char(5);
    
  /* SeOUp a condition handler to deal with the date error 
   *  we may get from the SET statement. 
   */ 
    declare HWK_ERROR condition for sqlstate '38501';
    declare continue handler for HWK_ERROR
    begin
    end;
 
    set cmdstring = 'DSPOBJU OBJ(ILEDITOR/QTOOLS) OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DOU) OUTMBR(*FIRST *REPLACE)';
    call qcmdexc( cmdstring );   
    set cmdstring = 'DSPOBJU OBJ(' ||trim(IN_LIB) ||'/' ||trim(IN_OBJ)||') OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DOU) OUTMBR(*FIRST *REPLACE)';
    call qcmdexc( cmdstring );
 
    set cmdstring = 'create or replace alias VSC_T$DOU_ for '||trim(user)||'/VSC_T$DOU';
    execute immediate cmdstring;
       
    return with  CONDENSE_HOW_USED (OUDLIB ,OUDPGM ,LANG_TYP ,OPERATE_TYPS) as (
        select OUDLIB ,OUDPGM 
        ,left(OUDHOW,(case locate('-',OUDHOW) when 0 then length(OUDHOW) else locate('-',OUDHOW) end)) As LANG_TYP 
        ,listagg(distinct trim(right(OUDHOW,locate('-',OUDHOW)+2)), ':') 
            within group (order by OUDLIB ,OUDPGM  ,OUDHOW ) as OPERATE_TYPS
        from VSC_T$DOU
--         where OUDHOW not in ('BIND','ENTMOD')
        where OUDHOW not in ('BIND')
        group by OUDLIB ,OUDPGM ,left(OUDHOW,(case locate('-',OUDHOW) when 0 then length(OUDHOW) else locate('-',OUDHOW) end)) 
    )
    select distinct OUXREF 
        ,case when OUDSLB = '    ' then '*NONE' else OUDSLB end PHLIB 
        ,case when OUDSFL = '    ' then '*NONE' else OUDSFL end PHFILE 
        ,'*PHY' PHFILA ,'S' PHDTAT ,OUHTXT PHTXT
        ,case when OUDSLB <> '      '  then OUDSLB  else VSC.OUDLIB end MBLIB
        ,case when OUDSFL = '    ' then '*NONE' else OUDSFL end MBFILE
        ,VSC.OUDPGM MBNAME
        ,case when OUDSFL <> '      '  then OUDATR  else '*NONE' end MBSEU2
        , trim((LANG_TYP ||OPERATE_TYPS))||' - '|| OUDTXT  MBMTXT
    
    from VSC_T$DOU_ VSC inner join CONDENSE_HOW_USED CHU on VSC.OUDLIB = CHU.OUDLIB and VSC.OUDPGM = CHU.OUDPGM
    where OUHOBJ=IN_OBJ and case when IN_LIB = '*ALL' then IN_LIB else OUHLIB end =IN_LIB 
--     union all select * from table( values(IN_LIB,IN_OBJ,'','SELF') ) x (OUDLIB ,OUDPGM ,LANG_TYP ,OPERATE_TYPS)
    ;    
    
end VSC00AFN82;

-- ;select * from table(VSC_getHawkeyeObjecOUseList(IN_LIB=> 'WFIDTA',IN_OBJ=>'PRPTJCTB' ,IN_TLIB=>'PGMT' ,IN_TFILE=>'VSC_T12345')) x 
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> 'WFIDTA',IN_OBJ=>'PRPTJCTB')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10HCL')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> '*ALL  ',IN_OBJ=>'PRINTPR')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> '*ALL  ',IN_OBJ=>'EML10HCL')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> '*ALL',IN_OBJ=>'PRP13ZRG')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> 'WFIOBJ',IN_OBJ=>'PRP13ZRG')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> '*ALL',IN_OBJ=>'PRP07HRG')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> '*ALL',IN_OBJ=>'KRN05CRG')) x order by MBLIB ,MBNAME
;select * from table(ILEDITOR.VSC_getHawkeyeObjectUseList(IN_LIB=> ' ',IN_OBJ=>' ')) x 