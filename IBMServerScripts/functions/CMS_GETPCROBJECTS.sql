/*============================================================================ 
   SPECIFIC NAME..: CMS00AFN01                                                 
   FUNCTION NAME..: CMS_GETPCROBJECTS                                          
   AUTHOR.........: Matt Tyler                                                 
   DATE...........: 06/07/2022                                                 
   PCR #..........: XXXXX 00                                                   
   FUNCTION/DESC..: Return list of objects checked out to PCR                  
                                                                               
  ---------------------------------------------------------------------------- 
     MODIFICATIONS:                                                            
  ---------------------------------------------------------------------------- 
   MOD#  PCR     PGMR   DATE   DESCRIPTION                                     
  ============================================================================*/ 
set path *libl ; 
create or replace function ILEDITOR.CMS_GETPCROBJECTS
( IN_TASK char(10) default '*NA' -- *USERDFT, *NA, *ANY, *NOT
                                      -- ,generic*, task name
 ,IN_OBJ_TYPE char(10) default '*ALL'
 ,IN_DEVELOPER char(10) default '*NAMED' -- *USERDFT, *ALL, *NAMED, *CRTNONRES,
                                           --  name 
 ,IN_GRP char(10) default '*USERDFT' -- *ALL, *USERDFT, name*
 ,IN_PRD char(10) default '*USERDFT' -- *ALL, *USERDFT, name*
 ,IN_REL char(10) default '*USERDFT' -- *ALL, *USERDFT, name*
 ,IN_ENV char(04) default '*NA' -- *NA, *ACT, D/I/Q/P
 ,IN_PRJ_NUM varchar(5) default '*ALL' 
       ) 
returns table ( 
  ENH CHAR(10)
 ,SRCF char(10)
 ,SRCM char(10)
 ,ENVSEQ VARCHAR(3)
 ,LIBRARY_ VARCHAR(10)
 ,ENVD VARCHAR(1)
 ,ENVI VARCHAR(1)
 ,ENVQ VARCHAR(1)
 ,ENVP VARCHAR(1)
 ,GRP### char(4)
 ,PRD### char(4)
 ,REL### char(4)
 ,OBJNAME char(10)
 ,OBJFMLY char(8)
 ,OBJTYPE char(8)
 ,ENV char(3)
 ,SUBENV char(10)
 ,GRP varchar(10)
 ,PRD varchar(10)
 ,REL varchar(10)
 ,DVPNAM char(10)
 ,OBJATTR char(10)
 ,OBJEXTA char(3)
 ,OBJCLASS char(1)
 ,EMGCHK char(1)
 ,VERSION char(8)
 ,DAT date
 ,TIM time
 ,ACTOBJNAM char(128)
 ,ACTSRCNAM char(10)
 ,ACTSRCLIB char(10)
 ,PSEUDOSRC char(1)
 ,SRCTEXT char(50)
 ,SCNDAT date
 ,SCNTIM time
 ,SCNCUR char(1)
 ,SPARE1 char(1)
 ,SPARE2 char(1)
 ,SPARE3 char(1)
 ,SPARE4 char(1)
 ,SPARE5 char(1)
 ,SPARE6 char(1)
 ,ACTRSVD char(20)
 ,DATAOBJ char(1)
 ,CKOUSR char(10)
 ,RETIRED char(1)
 ,CRTNONRESY char(1)
 ,TEMPHISTNM char(128)
 ,TEMPTYPE char(1)
 ,ONDELROW char(1)
 ,IN_TASK char(10)
 ,IN_OBJ_TYPE char(10) 
 ,IN_DEVELOPER char(10)
 ,IN_GRP char(10) 
 ,IN_PRD char(10) 
 ,IN_REL char(10) 
 ,IN_ENV char(04) 
 ,IN_PRJ_NUM varchar(5)
) 
 language sql 
 specific CMS00AFN01 
 deterministic 
 called on null input 
 no external action 
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
  return  with BASE_PCR_OBJECTS
( EHN, SRCF,SRCM,ENVSEQ,LIBRARY_,ENVD,ENVI,ENVQ,ENVP,GRP### ,PRD### ,REL###
       ,OBJNAME ,OBJFMLY,OBJTYPE
       ,ENV,SUBENV
       ,GRP,PRD,REL
       ,DVPNAM
       ,OBJATTR ,OBJEXTA ,OBJCLASS
       ,EMGCHK
       ,VERSION
       ,DAT ,TIM
       ,ACTOBJNAM ,ACTSRCNAM ,ACTSRCLIB
       ,PSEUDOSRC
       ,SRCTEXT
       ,SCNDAT,SCNTIM
       ,SCNCUR
       ,SPARE1,SPARE2,SPARE3,SPARE4,SPARE5,SPARE6
       ,ACTRSVD
       ,DATAOBJ
       ,CKOUSR
       ,RETIRED
       ,CRTNONRESY
       ,TEMPHISTNM
       ,TEMPTYPE
       ,ONDELROW)
as ( select distinct EO.ENH
, OS.SRCF
, OS.SRCM
,trim( case OE.ENV when 'DVP' then '001'
                   when 'ITG' then '002'
                   when 'QUA' then '003'
                   else '004' end ) as ENVSEQ
,trim( case OE.ENV when 'DVP' then OE.SUBENV
    when 'ITG' then ( select LIBRARY from ACMSCTL.LIBNAME LN
         where LN.GRP###=OE.GRP### and LN.PRD###=OE.PRD###
           and LN.REL###=OE.REL### and LN.ENV = OE.ENV
           and ( LN.LIBNBR= OS.ITGSRCLIBN and OE.OBJTYPE='*SRCMBR'
             or LN.LIBNBR= OS.ITGOBJLIBN and OE.OBJTYPE<>'*SRCMBR'))
    when 'QUA' then ( select LIBRARY from ACMSCTL.LIBNAME LN
         where LN.GRP###=OE.GRP### and LN.PRD###=OE.PRD###
           and LN.REL###=OE.REL### and LN.ENV = OE.ENV
           and ( LN.LIBNBR= OS.QUASRCLIBN and OE.OBJTYPE='*SRCMBR'
             or LN.LIBNBR= OS.QUAOBJLIBN and OE.OBJTYPE<>'*SRCMBR'))
    when 'PDN' then ( select LIBRARY from ACMSCTL.LIBGRP LG
                     inner join ACMSCTL.LIBNAME LN
                     on LG.GRP###=LN.GRP### and LG.PRD###=LN.PRD###
                    and LG.REL###=LN.REL### and LG.LIBNBR=LN.LIBNBR
         where LN.GRP###=OE.GRP### and LN.PRD###=OE.PRD###
           and LN.REL###=OE.REL### and LN.ENV = OE.ENV
           and ( LG.LIBGRPNBR= OS.DYNSRCLIBN /*and OE.OBJTYPE='*SRCMBR'
            or  LG.LIBGRPNBR= OS.DYNOBJLIBN and OE.OBJTYPE<>'*SRCMBR'*/))
    else '*LIBL' end ) as LIBRARY_
,case
   when OE.ENV = 'DVP' and OE.RETIRED =  'Y' then '*'
   when OE.ENV = 'DVP' and OE.RETIRED <> 'Y' then
     case when EEO.ENH### = EO.ENH### then 'D' else 'd' end
   else ' '
   end  DVP

,case
    when OE.ENV = 'ITG' and OE.RETIRED =  'Y' then '*'
    when OE.ENV = 'ITG' and OE.RETIRED <> 'Y' then
      case when EEO.ENH### = EO.ENH### then 'I' else 'i' end
    else ' '
    end ITG

,case
    when OE.ENV = 'QUA' and OE.RETIRED =  'Y' then '*'
    when OE.ENV = 'QUA' and OE.RETIRED <> 'Y' then
      case when EEO.ENH### = EO.ENH### then 'Q' else 'q' end
    else ' '
    end QUA
,case
    when OE.ENV = 'PDN' and OE.RETIRED =  'Y' then '*'
    when OE.ENV = 'PDN' and OE.RETIRED <> 'Y' then 'P'
    else ' '
    end PDN
,OE.GRP###,OE.PRD###,OE.REL###
,case when OS.SYSOBJNAM > ' ' then OS.SYSOBJNAM else substr( OE.OBJNAME,1,10) end OBJNAME
,OE.OBJFMLY,OE.OBJTYPE
,OE.ENV,OE.SUBENV
,trim(OE.GRP),trim(OE.PRD),trim(OE.REL)
,OE.DVPNAM
,OE.OBJATTR,OE.OBJEXTA,OE.OBJCLASS
,OE.EMGCHK
,OE."VERSION"
,OE.DAT,OE.TIM
,OE.ACTOBJNAM,OE.ACTSRCNAM
,ifnull( LB.LIBRARY ,OE.SUBENV) as ACTSRCLIB
,OE.PSEUDOSRC
,OE.SRCTEXT
,OE.SCNDAT
,OE.SCNTIM
,OE.SCNCUR
,OE.SPARE1,OE.SPARE2,OE.SPARE3,OE.SPARE4,OE.SPARE5,OE.SPARE6
,OE.ACTRSVD
,OE.DATAOBJ
,OE.CKOUSR
,OE.RETIRED
,OE.CRTNONRESY
,OE.TEMPHISTNM
,OE.TEMPTYPE
,OE.ONDELROW
from ACMSCTL.OBJENV OE 
left join ACMSCTL.OBJSREL OS on OE.GRP###=OS.GRP### and
   OE.PRD###=OS.PRD### and OE.REL###=OS.REL### and
   OE.OBJNAME=OS.OBJNAME and OE.OBJFMLY=OS.OBJFMLY
left join ACMSCTL.LIBNAMEGRP LG on (LG.GRP###, LG.PRD###, LG.REL###) = (OS.GRP###, OS.PRD###, OS.REL###) 
    and case when OE.ENV = 'PDN' and OS.DYNSRCLIBN = LG.LIBGRPNBR then 1
             when OE.ENV = 'QUA' and OS.QUASRCLIBN = LG.LIBGRPNBR then 1
             when OE.ENV = 'ITG' and OS.ITGSRCLIBN = LG.LIBGRPNBR then 1
             end = 1
left join ACMSCTL.LIBNAME LB on (LB.GRP###, LB.PRD###, LB.REL###) = (LG.GRP###, LG.PRD###, LG.REL###) and LG.LIBNBR = LB.LIBNBR   
   
left join ACMSCTL.ENHOBJ EO on EO.GRP###=OE.GRP### and
   EO.PRD###=OE.PRD### and EO.REL###=OE.REL### and
   EO.OBJNAME=OE.OBJNAME and EO.OBJFMLY=OE.OBJFMLY
   
left join ACMSCTL.ENVENHOBJ EEO on EO.GRP### = EEO.GRP###
   and EO.PRD###  = EEO.PRD### and EO.REL### = EEO.REL### 
   and EO.ENH### = EEO.ENH###
   and EO.OBJNAME = EEO.OBJNAME 
   and OE.OBJFMLY = EEO.OBJFMLY and OE.ENV = EEO.ENV 

-- left join ACMSCTL.ENHDEF ED on ED.ENH### = EEO.ENH### 
left join ACMSCTL.TSK TK on TK.TSKNM = EO.ENH
cross join (select PRVGRP, PRVPRD, PRVREL, PRVDVP, PRVENH 
            from ACMSCTL.USRDEF where USRPRF = current_user) UD
where 1=1 
-- See Work with Objects by Devloper F17 for values and informationon * values
and ( IN_TASK = '*NA     ' 
   or IN_TASK = '*USERDFT' and EO.ENH = (case when UD.PRVENH = '*NONE' then EO.ENH else UD.PRVENH end)
   or IN_TASK = '*ANY    ' and EO.ENH > ' '
   or IN_TASK = '*NOT    ' and EO.ENH = ' '  
   or locate('*',IN_TASK,2) > 0 and EO.ENH like (replace(trim(IN_TASK),'*','%')) 
   or IN_TASK = EO.ENH -- named
   )
and ( IN_DEVELOPER = '*USERDFT  ' and OE.DVPNAM = (case when UD.PRVDVP = '*NONE' then OE.DVPNAM else UD.PRVDVP end)
   or IN_DEVELOPER = '*ALL      ' --and OE.DVPNAM >= ' '
   or IN_DEVELOPER = '*NAMED    ' and OE.DVPNAM not like '*%'
   or IN_DEVELOPER = '*CRTNONRES' and OE.DVPNAM = '*CRTNONRES'
   or IN_DEVELOPER = OE.DVPNAM -- named
   or IN_DEVELOPER = '*NA'
   )   
and ( case IN_OBJ_TYPE when '*ALL'     then '*ALL'
                     when '    '     then '    '
                     when '**DBFMLY' then OE.OBJFMLY
                     else OE.OBJTYPE end ) = IN_OBJ_TYPE
and OE.GRP like (case when IN_GRP='*ALL'  then OE.GRP
                      when IN_GRP='*USERDFT' 
                         then case when UD.PRVGRP = '*NONE' then OE.GRP else UD.PRVGRP end 
                       when right( trim(IN_GRP),1 ) in ('*','%') 
                         then (replace(trim(IN_GRP),'*','%'))                         
                      else IN_GRP end )
and OE.PRD like (case when IN_PRD='*ALL' then OE.PRD
                      when IN_PRD='*USERDFT' 
                         then case when UD.PRVPRD = '*NONE' then OE.PRD else UD.PRVPRD end 
                       when right( trim(IN_PRD),1 ) in ('*','%') 
                         then (replace(trim(IN_PRD),'*','%'))                         
                      else IN_PRD end )
and OE.REL like (case when IN_REL='*ALL' then OE.REL
                      when IN_REL='*USERDFT' 
                        then case when UD.PRVREL = '*NONE' then OE.REL else UD.PRVREL end
                      when right( trim(IN_REL),1 ) in ('*','%') 
                        then (replace(trim(IN_REL),'*','%')) 
                      else IN_REL end)                       
and ( IN_PRJ_NUM = '*ALL' 
   or IN_PRJ_NUM <> '*ALL' and 'PRJ'||IN_PRJ_NUM = TK.UDFC2
   )
) select distinct A.*  ,IN_TASK ,IN_OBJ_TYPE ,IN_DEVELOPER ,IN_GRP ,IN_PRD ,IN_REL ,IN_ENV ,IN_PRJ_NUM
from BASE_PCR_OBJECTS A
where 1=1 
and ( IN_ENV = '*ACT' and ( ENVD <> ' ' or ENVI <> ' ' or ENVQ <> ' ')
   or IN_ENV = 'D' And ENVD = 'D' 
   or IN_ENV = 'I' And ENVI = 'I' 
   or IN_ENV = 'Q' And ENVQ = 'Q' 
   or IN_ENV = '*NA' 
     )
order by OBJNAME, OBJTYPE, ENVSEQ
;
end; 
comment on specific function CMS00AFN01 is 'Return list of objects checked out to PCR'; 
  label on specific function CMS00AFN01 is 'Return list of objects checked out to PCR'; 
/* Testing query 
 */
select  *
  from table ( 
          CMS_GETPCROBJECTS( 
--              IN_TASK => 'PCR1861900' 
--              IN_TASK => 'PCR1935500' 
--              IN_TASK => 'PCR1708800' 
--              IN_TASK => 'PCR1976200' 
--              IN_TASK => 'PCR1970000' 
--              IN_TASK => 'PCR2039000' 
--              IN_TASK => 'ZEMER' 
--              IN_TASK => 'Y2K' 
--              IN_TASK => '*NA' 
--              ,IN_OBJ_TYPE => '**DBFMLY'
--              ,IN_PRJ_NUM => 102
             IN_PRJ_NUM => 101
-- ,IN_REL => 'D2*' 
-- , IN_REL => 'D2WFI'
-- ,IN_REL => 'D1*'
-- ,IN_ENV => 'I'
-- ,IN_ENV => 'D'
-- ,IN_ENV => '*ALL'
-- ,IN_ENV => '*NA'
-- ,IN_DEVELOPER => 'PGMT'
-- ,IN_DEVELOPER => '*NAMED'
-- ,IN_DEVELOPER => '*NAMED'
-- ,IN_DEVELOPER => '*CRTNONRES'
            ) 
         ) PCR
-- where LIBRARY_ = 'D2WFIINTG' and SRCF = 'QRPGSRC'
where LIBRARY_ = 'D2WFIQUAL' -- and SRCF = 'QRPGSRC'
-- where LIBRARY_ = 'PGMT' and SRCF = 'QRPGSRC'
-- where 1=1 
-- and ACTSRCLIB = 'PGMT' 
-- and ACTSRCLIB = 'WFISRC' 
-- and ACTSRCLIB = 'PGMT' 
-- and SRCF = 'QRPGSRC'
-- and SRCF = 'QTXTSRC'
and SRCF like 'Q%'
-- where SRCF = 'QRPGSRC'
-- and ENV = 'PDN'

  order by OBJNAME, OBJTYPE, ENVSEQ

/**/ 
;select 
(TP.avgrowsize - 12) as MBMXRL
,ST.iasp_number as MBASP
,PCR.SRCF MBFILE
,PCR.SRCM as MBNAME
,TP.SOURCE_TYPE as MBSEU2
,TP.PARTITION_TEXT as MBMTXT
,TP.PARTITION_TEXT ||' (of '||grp||'/'||prd||'/'||rel||') ['||
overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1)||']' as MBMTXT
-- ,
,PCR.GRP
,PCR.PRD
,PCR.REL
,overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1) ENVSTS
,OBJFMLY
-- ,PCR.*
  from table ( CMS_GETPCROBJECTS( IN_TASK => 'PCR1976200' ) ) PCR
  inner join QSYS2.SYSTABLES ST on ST.TABLE_SCHEMA = LIBRARY_ and ST.TABLE_NAME = SRCF
  inner join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = ST.TABLE_SCHEMA and TP.TABLE_NAME = ST.TABLE_NAME and TP.SYSTEM_TABLE_MEMBER = PCR.SRCM
--   where SRCF = 'QRPGSRC'
  group by avgrowsize,iasp_number,SRCF,SRCM,SOURCE_TYPE,PARTITION_TEXT,GRP,PRD,REL, OBJFMLY
  order by iasp_number,SRCF,SRCM,SOURCE_TYPE,PARTITION_TEXT,REL





;with t1 (MBLIB,MBFILE,MBNAME,MBSEU2,MBMTXT,gpr,envsts,objfmly) as (
select 
 PCR.LIBRARY_
,PCR.SRCF MBFILE
,PCR.SRCM as MBNAME
,PCR.OBJATTR as MBSEU2
,case when left((trim(max(ENVD))||trim(max(ENVI))||trim(max(ENVQ))),1) = '*' then '**RETIRING** ' 
      when left((trim(max(ENVP))),1) = '*' then '**RETIRED** ' else trim(PCR.SRCTEXT) end as MBMTXT
,grp||'/'||prd||'/'||rel
,overlay( overlay( overlay( overlay( '    ' ,max(ENVD) ,1,1) ,max(ENVI) ,2,1) ,max(ENVQ) ,3,1) ,max(ENVP) ,4,1) ENVSTS
,OBJFMLY
  from table ( CMS_GETPCROBJECTS( IN_TASK => 'PCR1976200' ) ) PCR
  group by LIBRARY_,SRCF,SRCM,PCR.OBJATTR,PCR.SRCTEXT,GRP,PRD,REL,OBJFMLY
) 
select (TP.avgrowsize - 12) as MBMXRL
,ST.iasp_number as MBASP
,MBLIB,MBFILE,MBNAME,MBSEU2
,ifnull(nullif(MBMTXT,' '),TP.PARTITION_TEXT) ||' (of '||gpr||') ['||ENVSTS||']' as MBMTXT
,ifnull(nullif(MBMTXT,' '),TP.PARTITION_TEXT) as MBMTXT2
from T1
  inner join QSYS2.SYSTABLES ST on ST.TABLE_SCHEMA = MBLIB and ST.TABLE_NAME = MBFILE
  inner join QSYS2.SYSPARTITIONSTAT as TP on TP.TABLE_SCHEMA = ST.TABLE_SCHEMA and TP.TABLE_NAME = ST.TABLE_NAME and TP.SYSTEM_TABLE_MEMBER = MBNAME
-- where MBLIB = 'D2WFIINTG'
-- and MBFILE = 'QRPGSRC'

  order by MBASP,MBFILE,MBNAME,MBSEU2,MBMTXT
  