/*============================================================================
   SPECIFIC NAME..: VSC00AFN02
   FUNCTION NAME..: VSC_getSourceFileList
   AUTHOR.........: Matt Tyler
   DATE...........: 09/22/2022
   PCR #..........: XXXXX 00
   FUNCTION/DESC..: Return list of source files for VS Code

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

;create or replace function VSC_getSourceFileListCustom
(
  IN_LIB  char(10)
 ,IN_SRCF char(10) default '*'
 ,IN_MBR varchar(256) default '*'
 ,IN_MBR_TYPE varchar(64) default '*'
 ,IN_DEBUG_PARMS char(1) default null
       )
returns table (
 PHLIB varchar(10)
,PHFILE varchar(10)
,PHFILA varchar(10)
,PHDTAT char(1)
,PHTXT varchar(128)
,PHNOMB int
,PHCSID dec(5,0)
,PHMXRL dec(5,0)
,OUT_FILE varchar(64)
,OUT_FILTER_STYLE_F int
,OUT_MBR varchar(256)
,OUT_FILTER_STYLE_M int
,OUT_MBR_TYPE varchar(64)
,OUT_FILTER_STYLE_MT int
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
 declare PHLIB varchar(10);
 declare PHFILE varchar(10);
 declare PHFILA varchar(10);
 declare PHDTAT char(1);
 declare PHTXT varchar(128);
 declare PHNOMB int;
 declare PHCSID dec(5,0);
 declare PHMXRL dec(5,0);
 declare OUT_FILE varchar(64); -- Filtering format value
 declare OUT_FILTER_STYLE_F int; -- Filtering format type
 declare OUT_MBR varchar(64); -- Filtering format value
 declare OUT_FILTER_STYLE_M int; -- Filtering format type
 declare OUT_MBR_TYPE varchar(64); -- Filtering format value
 declare OUT_FILTER_STYLE_MT int; -- Filtering format type

 declare has_rows int default 1;
 declare RES1 RESULT_SET_LOCATOR varying;
 declare CONTINUE handler for not found set HAS_ROWS = 0;
 call VSC_getSourceFileListCustom_SP(IN_LIB => IN_LIB ,IN_SRCF => IN_SRCF ,IN_MBR => IN_MBR ,IN_MBR_TYPE => IN_MBR_TYPE ,IN_DEBUG_PARMS=>IN_DEBUG_PARMS) ;
 associate result set locators (RES1) with procedure VSC_getSourceFileListCustom_SP;
 allocate CUR1 cursor for result set RES1;
 fetch CUR1 into PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHTXT ,PHNOMB ,PHCSID ,PHMXRL ,OUT_FILE ,OUT_FILTER_STYLE_F ,OUT_MBR ,OUT_FILTER_STYLE_M ,OUT_MBR_TYPE ,OUT_FILTER_STYLE_MT ;
 while HAS_ROWS > 0 do -- some bogus processing
--          pipe allows you to load up a row set of data before returning
               pipe (PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHTXT ,PHNOMB ,PHCSID ,PHMXRL ,OUT_FILE ,OUT_FILTER_STYLE_F ,OUT_MBR ,OUT_FILTER_STYLE_M ,OUT_MBR_TYPE ,OUT_FILTER_STYLE_MT) ;
     fetch CUR1 into PHLIB ,PHFILE ,PHFILA ,PHDTAT ,PHTXT ,PHNOMB ,PHCSID ,PHMXRL ,OUT_FILE ,OUT_FILTER_STYLE_F ,OUT_MBR ,OUT_FILTER_STYLE_M ,OUT_MBR_TYPE ,OUT_FILTER_STYLE_MT ;
 end while;
 return;
end;
comment on specific function VSC00AFN03 is 'Return list of source files for VS Code';
  label on specific function VSC00AFN03 is 'Return list of source files for VS Code';
-- /* Testing query
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '*', IN_LIB => 'PGMT' ) ) /* C4 */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCRPRJ00101', IN_LIB => 'D2WFIQUAL' ) ) /* C4 */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR1708800', IN_LIB => 'D2WFIQUAL' ) ) /* C3 */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2118200', IN_LIB => 'PGMT' ) ) /* C3 */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '#PCR2066900', IN_LIB => 'WFIQUAL' ) ) /* C3 */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'KRN*', IN_LIB => 'WFISRC' ) ) /* C1*/
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => '^KRN...CL', IN_LIB => 'WFISRC' ) ) /* C2 */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DPO' ,IN_DEBUG_PARMS=>'Y' ) ) /* C9_DPO */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'WFIOBJ/PRP03ZRG' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$DOU' ,IN_DEBUG_PARMS=>'Y' ) ) /* C9_DOU */
;select * from table ( VSC_GETSOURCEFILELISTCUSTOM(IN_SRCF => 'Q*' ,IN_MBR => 'WFIDTA/PRPEMPPF' , IN_LIB => 'WFISRC' ,IN_MBR_TYPE => '$HWK$FSU' ,IN_DEBUG_PARMS=>'Y' ) ) /* C9_FSU */
--  */
