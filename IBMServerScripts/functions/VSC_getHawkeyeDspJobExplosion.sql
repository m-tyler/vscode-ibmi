;cl:chgcurlib ILEDITOR;
;set current path ILEDITOR, SYSTEM PATH
-- ;cl:chgcurlib [USER];
-- ;set path [USER]
-- ;select * from LIBRARY_LIST_INFO

;create or replace function VSC_getHawkeyeDspJobExplosion
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
,MBEXSTEP int 
,MBEXLVL int 
)

 language sql 
 specific VSC00AFN85 
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
VSC00AFN85: begin 
    declare cmdstring varchar(256);
    declare SQLSTATE char(5);
    
  /* SeOUp a condition handler to deal with the date error 
   *  we may get from the SET statement. 
   */ 
    declare HWK_ERROR condition for sqlstate '38501';
    declare continue handler for HWK_ERROR
    begin
    end;
 
    set cmdstring = 'DSPJOBEXP PGM(QGPL/PROOF) OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DJE) OUTMBR(*FIRST *REPLACE)';
    call qcmdexc( cmdstring );   
    if SQLSTATE >= '02000' then 
        set cmdstring = 'DSPJOBEXP PGM(QGPL/*ALL) OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DJE) OUTMBR(*FIRST *REPLACE)';
        call qcmdexc( cmdstring );  
    end if; 
    set cmdstring = 'DSPJOBEXP PGM(' ||trim(IN_LIB) ||'/' ||trim(IN_OBJ)||') OUTPUT(*OUTFILE) OUTFILE('||trim(user)||'/VSC_T$DJE) OUTMBR(*FIRST *REPLACE)';
    call qcmdexc( cmdstring );
 
    set cmdstring = 'create or replace alias VSC_T$DJE_ for '||trim(user)||'/VSC_T$DJE';
    execute immediate cmdstring;
       
    return with  CONDENSE_HOW_USED (EXDLIB ,EXDOBJ ,LANG_TYP ,OPERATE_TYPS) as (
        select EXDLIB ,EXDOBJ 
        ,left(EXDHOW,(case locate('-',EXDHOW) when 0 then length(EXDHOW) else locate('-',EXDHOW)-1 end)) As LANG_TYP 
        ,listagg(distinct trim(right(EXDHOW,locate('-',EXDHOW)+2)), ':') 
            within group (order by EXDLIB ,EXDOBJ  ,EXDHOW ) as OPERATE_TYPS
        from VSC_T$DJE
        where EXDHOW not in ('BIND')
        group by EXDLIB ,EXDOBJ ,left(EXDHOW,(case locate('-',EXDHOW) when 0 then length(EXDHOW) else locate('-',EXDHOW)-1 end)) 
    )
    select distinct EXXREF 
        ,case when EXDSLB = '    ' then '*NONE' else EXDSLB end PHLIB 
        ,case when EXDSFL = '    ' then '*NONE' else EXDSFL end PHFILE 
        ,'*PHY' PHFILA ,'S' PHDTAT ,EXHTXT PHTXT
        ,case when EXDSLB <> '      '  then EXDSLB  else VSC.EXDLIB end MBLIB
        ,case when EXDSFL = '    ' then '*NONE' else EXDSFL end MBFILE
        ,VSC.EXDOBJ MBNAME
        ,case when EXDSFL <> '      '  then EXDATR  else '*NONE' end MBSEU2
        , trim((LANG_TYP ||OPERATE_TYPS))||' - '|| EXDTXT  MBMTXT
        ,EXDS# MBEXSTEP,EXDL# MBEXLVL
    
    from VSC_T$DJE_ VSC inner join CONDENSE_HOW_USED CHU on VSC.EXDLIB = CHU.EXDLIB and VSC.EXDOBJ = CHU.EXDOBJ
    where EXHPGM=IN_OBJ and case when IN_LIB = '*ALL' then IN_LIB else EXHLIB end =IN_LIB 
    ;    
    
end VSC00AFN85;

-- ;select * from table(VSC_getHawkeyeObjecOUseList(IN_LIB=> 'WFIDTA',IN_OBJ=>'PRPTJCTB' ,IN_TLIB=>'PGMT' ,IN_TFILE=>'VSC_T12345')) x 
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> 'WFIDTA',IN_OBJ=>'PRPTJCTB')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10HCL')) x order by MBLIB ,MBNAME

;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> 'WFIOBJ',IN_OBJ=>'HRM67ERG')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeObjectUseList  (IN_LIB=> 'WFIOBJ',IN_OBJ=>'HRM67ERG')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeObjectUseList  (IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10HCL')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeObjectUseList  (IN_LIB=> 'WFIOBJ',IN_OBJ=>'EML10BCL')) x order by MBLIB ,MBNAME

;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> '*ALL  ',IN_OBJ=>'PRINTPR')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> '*ALL  ',IN_OBJ=>'EML10HCL')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> '*ALL',IN_OBJ=>'PRP13ZRG')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> 'WFIOBJ',IN_OBJ=>'PRP13ZRG')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> '*ALL',IN_OBJ=>'PRP07HRG')) x order by MBLIB ,MBNAME
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> '*ALL',IN_OBJ=>'KRN05CRG')) x order by MBEXLVL, MBEXSTEP
;select * from table(VSC_getHawkeyeDspJobExplosion(IN_LIB=> ' ',IN_OBJ=>' ')) x 