import { FilterType } from './Filter';
import { instance } from "../instantiate";
// import { default as IBMi } from './IBMi';
import { Tools } from './Tools';
import { t } from "../locale";


export type SortOrder = `name` | `type`;

export type SortOptions = {
  order: "name" | "date"
  ascending?: boolean
}
interface funcInfo {
  funcSysLib: string
  funcSysName: string
}
function getConnection() {
  const connection = instance.getConnection();
  if (connection) {
    return connection;
  }
  else {
    throw new Error(t('not.connected'));
  }
}
function getContent() {
  const content = instance.getContent();
  if (content) {
    return content;
  }
  else {
    throw new Error(t('not.connected'));
  }
}

  export async function whereisCustomFunc(): Promise<funcInfo> {
    // Look for the custom function somewhere
    let currentUser = '';
    const connection = getConnection();
    const content = getContent();
    if (connection) {
      currentUser = connection.currentUser;
    }
    let funcLookupRS: Tools.DB2Row[];
    let statement = `select SPECIFIC_SCHEMA,SPECIFIC_NAME from QSYS2.SYSFUNCS SF inner join table( values(1,'${currentUser}'),(2,'ILEDITOR') ) LL (Pos, ASCHEMA) on ASCHEMA = SPECIFIC_SCHEMA where ROUTINE_NAME = 'VSC_GETSOURCEFILELISTCUSTOM' limit 1`;
    funcLookupRS = await getContent().runSQL(statement);
    return {
      funcSysLib: String(funcLookupRS[0].SPECIFIC_SCHEMA),
      funcSysName: String(funcLookupRS[0].SPECIFIC_NAME)
    }
  }

  export async function getCustomObjectListQuery(filters: { library: string; object?: string; types?: string[]; filterType?: FilterType; member?: string; memberType?: string; }
                                , sortOrder?: SortOrder): Promise<string[]> {
    let theStatement: string[];
    let funcInfo: funcInfo = await whereisCustomFunc();
    let sqlFuncExist = await getContent().checkObject({ library: funcInfo.funcSysLib, name: funcInfo.funcSysName, type: "*SRVPGM" });
    let specialMember = (/^(#PCR|\$HWK)/.test(filters.member!));
    if (funcInfo 
      && sqlFuncExist
      && specialMember
      // && await getContent().checkObject({ library: funcInfo.funcSysLib, name: funcInfo.funcSysName, type: "*SRVPGM" })
      // && (/^(#PCR|$HWK)$/.test(filters.member!))
    ) {
      theStatement = [`select PHFILE name,`,
        `'*FILE' as type,`,
        `'PF'    as ATTRIBUTE,`,
        `PHTXT   as TEXT,`,
        `1       as IS_SOURCE,`,
        `PHNOMB  as NB_NBR,`,
        `PHMXRL  as SOLURCE_LENGTH,`,
        `PHCSID  as CCSID`,
        `from table ( ${funcInfo.funcSysLib}.VSC_getSourceFileListCustom (`,
        `  IN_LIB => '${filters.library}'`,
        `, IN_SRCF => '${filters.object}'`,
        `, IN_MBR => '${filters.member}'`,
        `, IN_MBR_TYPE => '${filters.memberType}'`,
        ` ) )`
      ];
      return theStatement;
    } 
    return [];
  }

  export async function getCustomMemberListQuery(filter: { library: string, sourceFile: string, members?: string, extensions?: string, sort?: SortOptions, filterType?: FilterType }): Promise<string> {
    let theStatement = ``;
    let funcInfo: funcInfo = await whereisCustomFunc();
    if (funcInfo) {
      let sqlFuncExist = await getContent().checkObject({ library: funcInfo.funcSysLib, name: funcInfo.funcSysName, type: "*SRVPGM" });
      let specialMember = (/^(#PCR|\$HWK)/.test(filter.members!));

      if (sqlFuncExist
        && specialMember
        // await getContent().checkObject({ library: funcInfo.funcSysLib, name: funcInfo.funcSysName, type: "*SRVPGM" })
        //   && (/^(#PCR|\$HWK)/.test(filter.members!))
      ) {
        theStatement = `\n select MBLIB LIBRARY,MBMXRL RECORD_LENGTH,MBASP ASP,MBFILE SOURCE_FILE,MBNAME NAME,MBSEU2 TYPE,MBMTXT TEXT,MBNRCD LINES,CREATED CREATED,CHANGED CHANGED,USERCONTENT from table (${funcInfo.funcSysLib}.VSC_getMemberListCustom(IN_LIB => '${filter.library}' 
        ${filter.sourceFile ? `,IN_SRCF => '${filter.sourceFile}'` : ""}
        ${filter.members ? `,IN_MBR =>  '${filter.members}'` : ""} 
        ${filter.extensions ? `,IN_MBR_TYPE => '${filter.extensions}'` : ""} ))
        Order By ${filter.sort?.order === 'name' ? 'NAME' : 'CHANGED'} ${!filter.sort?.ascending ? 'DESC' : 'ASC'}`;
      }
    }
    return theStatement;
  }
