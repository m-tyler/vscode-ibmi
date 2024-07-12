/*============================================================================ 
   SPECIFIC NAME..: VSC00AFN01
   FUNCTION NAME..: VSC_getMemberListCustom
   AUTHOR.........: Matt Tyler
   DATE...........: 09/22/2022
   PCR #..........: XXXXX 00
   FUNCTION/DESC..: Return list of source members for VS Code - Custom Code 

  ----------------------------------------------------------------------------
     MODIFICATIONS:
  ----------------------------------------------------------------------------
   MOD#  PCR     PGMR   DATE   DESCRIPTION
  ============================================================================*/
;cl:chgcurlib ILEDITOR;
;set current path ILEDITOR, SYSTEM PATH
-- ;cl:chgcurlib [USER];
-- ;set current path [user], SYSTEM PATH
-- ;select * from LIBRARY_LIST_INFO
  
;create or replace function VSC_getMemberListCustom
(
  IN_LIB  char(10)
 ,IN_SRCF char(10) default '*'
 ,IN_MBR  varchar(1200) default '*'
 ,IN_MBR_TYPE char(10) default '*'
 ,IN_DEBUG_PARMS char(1) default null
)
returns table (
 MBMXRL int -- Max Rec Len
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
,OUT_MBR varchar(256) -- Filtering format value
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

 declare MBMXRL int;  -- Max Rec Len
 declare MBASP  smallint; -- File iASP
 declare MBLIB  varchar(10);
 declare MBFILE varchar(10);
 declare MBNAME varchar(10);
 declare MBSEU2 varchar(10); -- Member type longer version
 declare MBMTXT varchar(180);
 declare MBNRCD int;
 declare CREATED bigint;
 declare CHANGED bigint;
 declare USERCONTENT varchar(132); -- user textual data for use in tooltip
 declare OUT_FILE varchar(64); -- Filtering format value
 declare OUT_FILTER_STYLE_F int; -- Filtering format type
 declare OUT_MBR varchar(64); -- Filtering format value
 declare OUT_FILTER_STYLE_M int; -- Filtering format type
 declare OUT_MBR_TYPE varchar(64); -- Filtering format value
 declare OUT_FILTER_STYLE_MT int; -- Filtering format type

 declare HAS_ROWS int default 1;
 declare RES1 RESULT_SET_LOCATOR varying;
 declare CONTINUE handler for not found set HAS_ROWS = 0;
 call VSC_GETMEMBERLISTCUSTOM_SP(IN_LIB => IN_LIB ,IN_SRCF => IN_SRCF ,IN_MBR => IN_MBR ,IN_MBR_TYPE => IN_MBR_TYPE ,IN_DEBUG_PARMS=>IN_DEBUG_PARMS) ;
 associate result set locators (RES1) with procedure VSC_GETMEMBERLISTCUSTOM_SP;
 allocate CUR1 cursor for result set RES1;
 fetch CUR1 into MBMXRL ,MBASP ,MBLIB ,MBFILE ,MBNAME ,MBSEU2 ,MBMTXT ,MBNRCD ,CREATED ,CHANGED ,USERCONTENT ,OUT_FILE ,OUT_FILTER_STYLE_F ,OUT_MBR ,OUT_FILTER_STYLE_M ,OUT_MBR_TYPE ,OUT_FILTER_STYLE_MT;
 while HAS_ROWS > 0 do -- some bogus processing
    -- pipe allows you to load up a row set of data before returning
               pipe (MBMXRL ,MBASP ,MBLIB ,MBFILE ,MBNAME ,MBSEU2 ,MBMTXT ,MBNRCD ,CREATED ,CHANGED ,USERCONTENT ,OUT_FILE ,OUT_FILTER_STYLE_F ,OUT_MBR ,OUT_FILTER_STYLE_M ,OUT_MBR_TYPE ,OUT_FILTER_STYLE_MT);
     fetch CUR1 into MBMXRL ,MBASP ,MBLIB ,MBFILE ,MBNAME ,MBSEU2 ,MBMTXT ,MBNRCD ,CREATED ,CHANGED ,USERCONTENT ,OUT_FILE ,OUT_FILTER_STYLE_F ,OUT_MBR ,OUT_FILTER_STYLE_M ,OUT_MBR_TYPE ,OUT_FILTER_STYLE_MT;
 end while;
 return;

end;
comment on specific function VSC00AFN11 is 'Return list of source members for VS Code - Custom Code';
  label on specific function VSC00AFN11 is 'Return list of source members for VS Code-Custom';
;STOP;
/* Testing query */
/* T01 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'QTXTSRC' ,IN_MBR => '#PCR1959800'  ))
/* T02 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '#PCR1959800'  ))
/* T03 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT' ,IN_SRCF => 'Q*SRC' ,IN_MBR => '#PCR1959800'  ))
/* T04 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ) )
/* T05 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) )
/* T06 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
/* T07 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
/* T08 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1970000', IN_LIB => 'PGMT' ,IN_SRCF=>'Q*') )
/* T09 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR2066900', IN_LIB => 'WFIQUAL' ,IN_SRCF=>'Q*') )
/* T10 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
/* T11 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
/* T12 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^KRN05', IN_LIB => 'D2WFIINTG' ) )
/* T13 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
/* T14 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
/* T15 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*RG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
/* T16 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*', IN_LIB => 'D2WFIINTG' ) )
/* T17 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05*RG', IN_LIB => 'D2WFIINTG' ) )
/* T18 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'QRPGSRC') )
/* T19 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ,IN_SRCF=>'Q*') )
/* T20 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => 'KRN05ARG', IN_LIB => 'D2WFIINTG' ) )
/* T21 */
/* T22 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '*', IN_LIB => 'PGMT' ) )
/* T23 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '*', IN_LIB => 'PGMT', IN_SRCF => 'Q*SRC' ) )
/* T24 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '^CVT19355', IN_LIB => 'PGMT' ) )
/* T25 */
/* T26 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_MBR => '#PCR1824200', IN_LIB => 'WFIQUAL' ) )
/* T27 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'CVTQUAL' ,IN_SRCF => 'QRPGSRC' ,IN_MBR => '^CVT19700'  ) )
/* T28 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFICVT' ,IN_SRCF => 'Q*' ,IN_MBR => 'CVT19700%'  ) )
/* T29 */
/* T30 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1960600', IN_LIB => 'CVTQUAL' ) )
/* T31 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_SRCF => '*ALL' ,IN_MBR => '*', IN_LIB => 'PGMT' ) )
/* T32 */
/* T33 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'QRPGSRC'  ,IN_MBR => '#PCR1970000'  ))
/* T34 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'TSTSRC'   ))
/* T35 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'QCLSRC'   ,IN_MBR => '#PCR1708800'  ))
/* T36 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QTXTSRC'   ))
/* T37 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'Q*'       ,IN_MBR => '#PCR2030600'  ))
/* T38 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'PGMT'   ,IN_SRCF => 'QTXTSRC'  ,IN_MBR => '#PCR2030600' , IN_DEBUG_PARMS => '1' ))
/* T39 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFIQUAL',IN_SRCF => 'QRPGSRC'  ,IN_MBR => '#PCR2030600' , IN_DEBUG_PARMS => '1' ))
/* T40 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFIDTA' ,IN_SRCF => 'PRPJTCTB' ,IN_MBR => '$HWK',  ) )
/* T41 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'  ,IN_MBR => 'WFIDTA/PRPTJCTB' , IN_MBR_TYPE => '$HWK' ,IN_DEBUG_PARMS=>'Y') )
/* T42 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QCLSRC '   ,IN_MBR => 'WFIDTA/PRPPTOTH' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') )
/* T43 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIDTA/PRPPTOTH' , IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y') )
/* T44 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QDDSSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
/* T45 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QCLSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
/* T46 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
/* T47 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '*ALL/PRP03ZRG' , IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y') )
/* T48 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => 'WFIOBJ/EML10ACL' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
/* T49 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '*ALL/EML10ACL' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
/* T50 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '*ALL/PRINTPR' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
/* T51 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QRPGSRC'   ,IN_MBR => '%ALL/PRINTPR' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
/* T52 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'WFISRC' ,IN_SRCF => 'QCLSRC'   ,IN_MBR => '%ALL/PRINTPR' , IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y') )
/* T53 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'D2WFIQUAL' ,IN_SRCF => 'QDDSSRC' ,IN_MBR => '#PCR1708800'  ))
/* T54 */;select * from table ( VSC_GETMEMBERLISTCUSTOM(IN_LIB => 'D2WFIQUAL' ,IN_SRCF => 'QDDSSRC' ,IN_MBR => '#PCRPRJ00101'  ))