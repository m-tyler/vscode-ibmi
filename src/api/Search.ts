import util from "util";
import fs from "fs";
import tmp from "tmp";

import { isProtectedFilter } from '../filesystems/qsys/QSysFs';
import { GlobalConfiguration } from './Configuration';
import Instance from './Instance';
import { Tools } from './Tools';
import { CommandResult } from "../typings";

const tmpFile = util.promisify(tmp.file);
const writeFileAsync = util.promisify(fs.writeFile);

export namespace Search {
  const QSYS_PATTERN = /(?:\/\w{1,10}\/QSYS\.LIB\/)|(?:\/QSYS\.LIB\/)|(?:\.LIB)|(?:\.FILE)|(?:\.MBR)/g;

  export interface Result {
    path: string
    lines: Line[]
    readonly?: boolean
    label?: string
    contextValue?: string
  }

  export interface Line {
    number: number
    content: string
  }

  export async function searchMembers(instance: Instance, library: string, sourceFile: string, memberFilter: string, searchTerm: string, filter?: string): Promise<Result[]> {
    const connection = instance.getConnection();
    const config = instance.getConfig();
    const content = instance.getContent();

    if (connection && config && content) {
      let asp = ``;
      if (config.sourceASP) {
        asp = `/${config.sourceASP}`;
      } else if (config.enableSQL) {
        try {
          const [row] = await content.runSQL(`SELECT IASP_NUMBER FROM TABLE(QSYS2.LIBRARY_INFO('${library}'))`);
          const iaspNumber = row?.IASP_NUMBER;
          if (iaspNumber && typeof iaspNumber === 'number' && connection.aspInfo[iaspNumber]) {
            asp = `/${connection.aspInfo[iaspNumber]}`;
          }
        } catch (e) { }
      }

      const result = await connection.sendQsh({
        command: `/usr/bin/grep -inHR -F "${sanitizeSearchTerm(searchTerm)}" ${asp}/QSYS.LIB/${connection.sysNameInAmerican(library)}.LIB/${connection.sysNameInAmerican(sourceFile)}.FILE/*`,
      });

      if (!result.stderr) {
        return parseGrepOutput(result.stdout || '', filter,
          path => connection.sysNameInLocal(path.replace(QSYS_PATTERN, ''))); //Transform QSYS path to URI 'member:' compatible path
      }
      else {
        throw new Error(result.stderr);
      }
    }
    else {
      throw new Error("Please connect to an IBM i");
    }
  }
  export async function HwksearchMembers(instance: Instance, library: string, sourceFile: string, memberFilter: string, searchTerm: string, filter?: string): Promise<Result[]> {
    const connection = instance.getConnection();
    const config = instance.getConfig();
    const content = instance.getContent();
    const lib = (library !== '*' ? library : '*ALL');
    const spf = (sourceFile !== '*' ? sourceFile : '*ALL');
    const member_Ext = (memberFilter !== '*.*' ? memberFilter : '*ALL.*ALL');
    const tempLibrary = `ILEDITOR`;
    const tempName = Tools.makeid();

    if (connection && config && content) {
      let mbrExt = member_Ext.split(`.`);
      const result = await connection.sendQsh({
        command: `system -q "CLRPFM ${tempLibrary}/${tempName} MBR(HWKSEARCH)"; system -q "DSPSCNSRC SRCFILE(${connection.sysNameInAmerican(lib)}/${connection.sysNameInAmerican(spf)}) SRCMBR(${connection.sysNameInAmerican(mbrExt[0])}) TYPE(${connection.sysNameInAmerican(mbrExt[1])}) OUTPUT(*OUTFILE) OUTFILE(${tempLibrary}/${tempName}) OUTMBR(HWKSEARCH) SCAN('${sanitizeSearchTerm(searchTerm).substring(0, 30)}') CASE(*IGNORE) BEGPOS(001) ENDPOS(240)" && db2 -s "select '/WIASP/QSYS.LIB/'||trim(SCDLIB)||'.LIB/'||trim(SCDFIL)||'.FILE/'||trim(SCDMBR)||'.'||(case when SP.SOURCE_TYPE is not null then SP.SOURCE_TYPE when SP.SOURCE_TYPE is null and SCDFIL = 'QSQDSRC' then 'SQL' else 'MBR' end)||':'||int(SCDSEQ)||':'||varchar(trim(SCDSTM),112) from ${tempLibrary}.${tempName} left join QSYS2.SYSPARTITIONSTAT SP on SP.SYSTEM_TABLE_SCHEMA=SCDLIB and SP.SYSTEM_TABLE_NAME=SCDFIL and SP.SYSTEM_TABLE_MEMBER=SCDMBR where ucase(rtrim(SCDSTM)) like ucase('%${sanitizeSearchTerm(searchTerm)}%')" | sed -e '1,3d' -e 's/\(.*\)/&/' -e '/^$/d' -e '/RECORD.*.*.* SELECTED/d' ;`,
      }); // add to end of list in future => -e 's/:/~/' -e 's/:/~/'

      if (!result.stderr) {
        // const result = await connection.sendQsh({ command: `system -q "DLTF ${tempLibrary}/${tempName}";`});
        return parseGrepOutput(result.stdout || '', filter,
          path => connection.sysNameInLocal(path.replace(QSYS_PATTERN, ''))); //Transform QSYS path to URI 'member:' compatible path
      }
      else {
        throw new Error(result.stderr);
      }
    }
    else {
      throw new Error("Please connect to an IBM i");
    }
  }

  export async function searchIFS(instance: Instance, path: string, searchTerm: string): Promise<Result[]> {
    const connection = instance.getConnection();
    if (connection) {
      const grep = connection.remoteFeatures.grep;

      if (grep) {
        const dirsToIgnore = GlobalConfiguration.get<string[]>(`grepIgnoreDirs`) || [];
        let ignoreString = ``;

        if (dirsToIgnore.length > 0) {
          ignoreString = dirsToIgnore.map(dir => `--exclude-dir=${dir}`).join(` `);
        }

        const grepRes = await connection.sendCommand({
          command: `${grep} -inr -F -f - ${ignoreString} ${Tools.escapePath(path)}`,
          stdin: sanitizeSearchTerm(searchTerm)
        });

        if (grepRes.code == 0) {
          return parseGrepOutput(grepRes.stdout);
        }
        else {
          return [];
        }
      } else {
        throw new Error(`Grep must be installed on the remote system.`);
      }
    }
    else {
      throw new Error("Please connect to an IBM i");
    }
  }

  function parseGrepOutput(output: string, filter?: string, pathTransformer?: (path: string) => string): Result[] {
    const results: Result[] = [];
    const readonly = isProtectedFilter(filter);
    for (const line of output.split('\n')) {
      if (!line.startsWith(`Binary`)) {
        const parts = line.split(`:`); //path:line
        const path = pathTransformer?.(parts[0]) || parts[0];
        let result = results.find(r => r.path === path);
        if (!result) {
          result = {
            path,
            lines: [],
            readonly,
          };
          results.push(result);
        }

        const contentIndex = nthIndex(line, `:`, 2);
        if (contentIndex >= 0) {
          const curContent = line.substring(contentIndex + 1);

          result.lines.push({
            number: Number(parts[1]),
            content: curContent
          })
        }
      }
    }

    return results;
  }
}

function sanitizeSearchTerm(searchTerm: string): string {
  return searchTerm.replace(/\\/g, `\\\\`).replace(/"/g, `\\\\"`);
}

function nthIndex(aString: string, pattern: string, n: number) {
  let index = -1;
  while (n-- && index++ < aString.length) {
    index = aString.indexOf(pattern, index);
    if (index < 0) break;
  }
  return index;
}