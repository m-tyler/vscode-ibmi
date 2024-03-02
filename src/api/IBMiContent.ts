import { parse } from 'csv-parse/sync';
import fs from 'fs';
import path from 'path';
import tmp from 'tmp';
import util from 'util';
import { window } from 'vscode';
import { ObjectTypes } from '../filesystems/qsys/Objects';
import { CommandResult, IBMiError, IBMiMember, IBMiObject, IFSFile, QsysPath } from '../typings';
import { IBMiSpooledFile } from '../typingsSplf';
import { ConnectionConfiguration } from './Configuration';
import { FilterType, parseFilter, singleGenericName } from './Filter';
import { default as IBMi } from './IBMi';
import { Tools } from './Tools';
const tmpFile = util.promisify(tmp.file);
const readFileAsync = util.promisify(fs.readFile);
const writeFileAsync = util.promisify(fs.writeFile);

const UTF8_CCSIDS = [`819`, `1208`, `1252`];

type Authority = "*ADD" | "*DLT" | "*EXECUTE" | "*READ" | "*UPD" | "*NONE" | "*ALL" | "*CHANGE" | "*USE" | "*EXCLUDE" | "*AUTLMGT";
export type SortOrder = `name` | `type`;

export type SortOptions = {
  order: "name" | "date"
  ascending?: boolean
}
interface funcInfo {
  funcSysLib: string
  funcSysName: string
}
export default class IBMiContent {
  private chgJobCCSID: string | undefined = undefined;
  constructor(readonly ibmi: IBMi) { }

  private get config(): ConnectionConfiguration.Parameters {
    if (!this.ibmi.config) {
      throw new Error("Please connect to an IBM i");
    }
    else {
      return this.ibmi.config;
    }
  }

  private getTempRemote(path: string) {
    const tempRemote = this.ibmi.getTempRemote(path);
    if (!tempRemote) {
      throw new Error(`Could not compute temporary remote location for ${path}`);
    }
    return tempRemote;
  }

  private async getNotUTF8CCSID(attr: string, remotePath: string): Promise<string> {
    const result = await this.ibmi.sendCommand({ command: `${attr} "${remotePath}" CCSID` });
    if (result.code === 0) {
      //What's the point of converting 1208?
      let ccsid = result.stdout.trim();
      if (!UTF8_CCSIDS.includes(ccsid)) {
        return ccsid.padStart(3, `0`);
      }
    }
    return "";
  }

  private async convertToUTF8(iconv: string, from: string, to: string, ccsid: string) {
    const result = await this.ibmi.sendCommand({ command: `${iconv} -f IBM-${ccsid} -t UTF-8 "${from}" > ${to}` });
    if (result.code === 0) {
      return result.stdout;
    }
    else {
      throw new Error(`Failed to convert ${from} to UTF-8: ${result.stderr}`);
    }
  }

  /**
   * 
   * @param remotePath Remote IFS path
   * @param localPath Local path to download file to
   */
  async downloadStreamfileRaw(remotePath: string, localPath?: string) {
    const features = this.ibmi.remoteFeatures;

    if (this.config.autoConvertIFSccsid && features.attr && features.iconv) {
      // If it's not 1208, generate a temp file with the converted content
      const ccsid = await this.getNotUTF8CCSID(features.attr, remotePath);
      if (ccsid) {
        const newTempFile = this.getTempRemote(remotePath);
        await this.convertToUTF8(features.iconv, remotePath, newTempFile, ccsid);
        remotePath = newTempFile;
      }
    }

    if (!localPath) {
      localPath = await tmpFile();
    }

    await this.ibmi.downloadFile(localPath, remotePath);
    const raw = await readFileAsync(localPath);
    return raw;
  }

  /**
   * @deprecated Use downloadStreamfileRaw instead
   */
  async downloadStreamfile(remotePath: string, localPath?: string) {
    const raw = await this.downloadStreamfileRaw(remotePath, localPath);
    return raw.toString(`utf8`);
  }

  /**
   * @param originalPath 
   * @param content Raw content
   * @param encoding Optional encoding to write.
   */
  async writeStreamfileRaw(originalPath: string, content: Uint8Array, encoding?: string) {
    const client = this.ibmi.client;
    const features = this.ibmi.remoteFeatures;
    const tmpobj = await tmpFile();

    let ccsid;
    if (this.config.autoConvertIFSccsid && features.attr) {
      // First, find the CCSID of the original file if not UTF-8
      ccsid = await this.getNotUTF8CCSID(features.attr, originalPath);
    }

    await writeFileAsync(tmpobj, content, encoding);

    if (ccsid && features.iconv) {
      // Upload our file to the same temp file, then write convert it back to the original ccsid
      const tempFile = this.getTempRemote(originalPath);
      await client.putFile(tmpobj, tempFile); //TODO: replace with uploadFiles
      return await this.convertToUTF8(features.iconv, tempFile, originalPath, ccsid);
    } else {
      return client.putFile(tmpobj, originalPath);
    }
  }

  /**
   * Write utf8 content to a streamfile
   * @deprecated Use writeStreamfileRaw instead
   */
  async writeStreamfile(originalPath: string, content: string) {
    const buffer = Buffer.from(content, `utf8`);
    return this.writeStreamfileRaw(originalPath, buffer);
  }

  /**
   * Download the contents of a source member
   */
  async downloadMemberContent(asp: string | undefined, library: string, sourceFile: string, member: string, localPath?: string) {
    asp = asp || this.config.sourceASP;
    library = library.toUpperCase();
    sourceFile = sourceFile.toUpperCase();
    member = member.toUpperCase();

    let retry = false;
    let path = Tools.qualifyPath(library, sourceFile, member, asp);
    const tempRmt = this.getTempRemote(path);
    while (true) {
      const copyResult = await this.ibmi.runCommand({
        command: `CPYTOSTMF FROMMBR('${path}') TOSTMF('${tempRmt}') STMFOPT(*REPLACE) STMFCCSID(1208) DBFCCSID(${this.config.sourceFileCCSID})`,
        noLibList: true
      });

      if (copyResult.code === 0) {
        if (!localPath) {
          localPath = await tmpFile();
        }
        await this.ibmi.downloadFile(localPath, tempRmt);
        return await readFileAsync(localPath, `utf8`);
      } else {
        if (!retry) {
          const messageID = String(copyResult.stdout).substring(0, 7);
          switch (messageID) {
            case "CPDA08A":
              //We need to try again after we delete the temp remote
              const result = await this.ibmi.sendCommand({ command: `rm -rf ${tempRmt}`, directory: `.` });
              retry = !result.code || result.code === 0;
              break;
            case "CPFA0A9":
              //The member may be located on SYSBAS
              if (asp) {
                path = Tools.qualifyPath(library, sourceFile, member);
                retry = true;
              }
              break;
            default:
              retry = false;
              break;
          }
        }

        if (!retry) {
          throw new Error(`Failed downloading member: ${copyResult.stderr}`);
        }
      }
    }
  }

  /**
   * Upload to a member
   */
  async uploadMemberContent(asp: string | undefined, library: string, sourceFile: string, member: string, content: string | Uint8Array) {
    asp = asp || this.config.sourceASP;
    library = library.toUpperCase();
    sourceFile = sourceFile.toUpperCase();
    member = member.toUpperCase();

    const client = this.ibmi.client;
    const tmpobj = await tmpFile();

    let retry = false;
    try {
      await writeFileAsync(tmpobj, content, `utf8`);
      let path = Tools.qualifyPath(library, sourceFile, member, asp);
      const tempRmt = this.getTempRemote(path);
      await client.putFile(tmpobj, tempRmt);

      while (true) {
        const copyResult = await this.ibmi.runCommand({
          command: `QSYS/CPYFRMSTMF FROMSTMF('${tempRmt}') TOMBR('${path}') MBROPT(*REPLACE) STMFCCSID(1208) DBFCCSID(${this.config.sourceFileCCSID})`,
          noLibList: true
        });

        if (copyResult.code === 0) {
          const messages = Tools.parseMessages(copyResult.stderr);
          if (messages.findId("CPIA083")) {
            window.showWarningMessage(`${library}/${sourceFile}(${member}) was saved with truncated records!`);
          }
          return true;
        } else {
          if (!retry) {
            const messages = Tools.parseMessages(copyResult.stderr);
            if (messages.findId("CPFA0A9")) {
              //The member may be located on SYSBAS
              if (asp) {
                path = Tools.qualifyPath(library, sourceFile, member);
                retry = true;
              }
            }
            else {
              throw new Error(`Failed uploading member: ${copyResult.stderr}`);
            }
          }
        }
      }
    } catch (error) {
      console.log(`Failed uploading member: ` + error);
      return Promise.reject(error);
    }
  }

  /**
   * Run SQL statements.
   * Each statement must be separated by a semi-colon and a new line (i.e. ;\n).
   * If a statement starts with @, it will be run as a CL command.
   * 
   * @param statements
   * @returns a Result set
   */
  async runSQL(statements: string): Promise<Tools.DB2Row[]> {
    const { 'QZDFMDB2.PGM': QZDFMDB2 } = this.ibmi.remoteFeatures;

    if (QZDFMDB2) {
      if (this.chgJobCCSID === undefined) {
        this.chgJobCCSID = (this.ibmi.qccsid < 1 || this.ibmi.qccsid === 65535) && this.ibmi.defaultCCSID > 0 ? `@CHGJOB CCSID(${this.ibmi.defaultCCSID});\n` : '';
      }      

      const output = await this.ibmi.sendCommand({
        command: `LC_ALL=EN_US.UTF-8 system "call QSYS/QZDFMDB2 PARM('-d' '-i' '-t')"`,
        stdin: Tools.fixSQL(`${this.chgJobCCSID}${statements}`)
      })

      if (output.stdout) {
        return Tools.db2Parse(output.stdout);
      } else {
        throw new Error(`There was an error running the SQL statement.`);
      }

    } else {
      throw new Error(`There is no way to run SQL on this system.`);
    }
  }

  /**
   * @param ileCommand Command that would change the library list, like CHGLIBL
   */
  async getLibraryListFromCommand(ileCommand: string): Promise<{ currentLibrary: string; libraryList: string[]; } | undefined> {
    if (this.ibmi.remoteFeatures[`GETNEWLIBL.PGM`]) {
      const tempLib = this.config.tempLibrary;
      const resultSet = await this.runSQL(`CALL ${tempLib}.GETNEWLIBL('${ileCommand.replace(new RegExp(`'`, 'g'), `''`)}')`);

      let result = {
        currentLibrary: `QGPL`,
        libraryList: [] as string[]
      };

      resultSet.forEach(row => {
        const libraryName = String(row.SYSTEM_SCHEMA_NAME);
        switch (row.PORTION) {
        case `CURRENT`:
          result.currentLibrary = libraryName;
          break;
        case `USER`:
          result.libraryList.push(libraryName);
          break;
        }
      })

      return result;
    }

    return undefined;
  }

  /**
   * Download the contents of a table.
   * @param library
   * @param file
   * @param member Will default to file provided
   * @param deleteTable Will delete the table after download
   */
  async getTable(library: string, file: string, member?: string, deleteTable?: boolean): Promise<Tools.DB2Row[]> {
    if (!member) member = file; //Incase mbr is the same file

    if (file === member && this.config.enableSQL) {
      const data = await this.runSQL(`SELECT * FROM ${library}.${file}`);

      if (deleteTable && this.config.autoClearTempData) {
        await this.ibmi.runCommand({
          command: `DLTOBJ OBJ(${library}/${file}) OBJTYPE(*FILE)`,
          noLibList: true
        });
      }

      return data;

    } else {
      const tempRmt = this.getTempRemote(Tools.qualifyPath(library, file, member));
      const copyResult = await this.ibmi.runCommand({
        command: `QSYS/CPYTOIMPF FROMFILE(${library}/${file} ${member}) ` +
          `TOSTMF('${tempRmt}') ` +
          `MBROPT(*REPLACE) STMFCCSID(1208) RCDDLM(*CRLF) DTAFMT(*DLM) RMVBLANK(*TRAILING) ADDCOLNAM(*SQL) FLDDLM(',') DECPNT(*PERIOD)`,
        noLibList: true
      });

      if (copyResult.code === 0) {
        let result = await this.downloadStreamfile(tempRmt);

        if (this.config.autoClearTempData) {
          Promise.allSettled([
            this.ibmi.sendCommand({ command: `rm -rf ${tempRmt}`, directory: `.` }),
            deleteTable ? this.ibmi.runCommand({ command: `DLTOBJ OBJ(${library}/${file}) OBJTYPE(*FILE)`, noLibList: true }) : Promise.resolve()
          ]);
        }

        return parse(result, {
          columns: true,
          skip_empty_lines: true,
          cast: true,
          onRecord(record) {
            for (const key of Object.keys(record)) {
              record[key] = record[key] === ` ` ? `` : record[key];
            }
            return record;
          }
        });

      } else {
        throw new Error(`Failed fetching table: ${copyResult.stderr}`);
      }
    }

  }

  /**
   * Prepare a table in QTEMP using any number of preparation queries and return its content.
   * @param prepareQueries : SQL statements that should create a table in QTEMP
   * @param table : the name of the table expected to be found in QTEMP
   * @returns : the table's content
   */
  async getQTempTable(prepareQueries: string[], table: string): Promise<Tools.DB2Row[]> {
    prepareQueries.push(`Select * From QTEMP.${table}`);
    const fullQuery = prepareQueries.map(query => query.endsWith(';') ? query : `${query};`).join("\n");
    return await this.runSQL(fullQuery);
  }

  /**
   * Get list of libraries with description and attribute
   * @param libraries Array of libraries to retrieve
   * @returns an array of libraries as IBMiObject
   */
  async getLibraryList(libraries: string[]): Promise<IBMiObject[]> {
    let results: Tools.DB2Row[];

    if (this.config.enableSQL) {
      const statement = `
        select os.OBJNAME as ODOBNM
             , coalesce(os.OBJTEXT, '') as ODOBTX
             , os.OBJATTRIBUTE as ODOBAT
          from table( SYSTOOLS.SPLIT( INPUT_LIST => '${libraries.toString()}', DELIMITER => ',' ) ) libs
             , table( QSYS2.OBJECT_STATISTICS( OBJECT_SCHEMA => 'QSYS', OBJTYPELIST => '*LIB', OBJECT_NAME => libs.ELEMENT ) ) os
      `;
      results = await this.runSQL(statement);
    } else {
      results = await this.getQTempTable([`CALL QSYS2.QCMDEXC('DSPOBJD OBJ(QSYS/*ALL) OBJTYPE(*LIB) DETAIL(*TEXTATR) OUTPUT(*OUTFILE) OUTFILE(QTEMP/LIBLIST)')`], "LIBLIST");
      if (results.length === 1 && !results[0].ODOBNM?.toString().trim()) {
        return [];
      }
      results = results.filter(object => libraries.includes(this.ibmi.sysNameInLocal(String(object.ODOBNM))));
    };

    const objects = results.map(object => ({
      library: 'QSYS',
      type: '*LIB',
      name: this.config.enableSQL ? object.ODOBNM : this.ibmi.sysNameInLocal(String(object.ODOBNM)),
      attribute: object.ODOBAT,
      text: object.ODOBTX
    } as IBMiObject));

    return libraries.map(library => {
      return objects.find(info => info.name === library) ||
      {
        library: 'QSYS',
        type: '*LIB',
        name: library,
        attribute: ``,
        text: `*** NOT FOUND ***`
      };
    });
  }

  /**
   * Validates a list of libraries
   * @param newLibl Array of libraries to validate
   * @returns Bad libraries
   */
  async validateLibraryList(newLibl: string[]): Promise<string[]> {
    let badLibs: string[] = [];

    newLibl = newLibl.filter(lib => {
      if (lib.match(/^\d/)) {
        badLibs.push(lib);
        return false;
      }

      if (lib.length > 10) {
        badLibs.push(lib);
        return false;
      }

      return true;
    });

    const result = await this.ibmi.sendQsh({
      command: [
        `liblist -d ` + Tools.sanitizeLibraryNames(this.ibmi.defaultUserLibraries).join(` `),
        ...newLibl.map(lib => `liblist -a ` + Tools.sanitizeLibraryNames([lib]))
      ].join(`; `)
    });

    if (result.stderr) {
      const lines = result.stderr.split(`\n`);

      lines.forEach(line => {
        const badLib = newLibl.find(lib => line.includes(`ibrary ${lib} `) || line.includes(`ibrary ${Tools.sanitizeLibraryNames([lib])} `));

        // If there is an error about the library, remove it
        if (badLib) badLibs.push(badLib);
      });
    }

    return badLibs;
  }

  async getLibraries(filters: { library: string; filterType?: FilterType }) {
    return this.getObjectList({ library: "QSYS", object: filters.library, types: ["*LIB"], filterType: filters.filterType });
  }

  /**
   * @param filters
   * @param sortOrder
   * @returns an array of IBMiFile
   */
  async getObjectList(filters: { library: string; object?: string; types?: string[]; filterType?: FilterType; member?: string; memberType?: string; }, sortOrder?: SortOrder): Promise<IBMiObject[]> {
    const library = filters.library.toUpperCase();
    if (!await this.checkObject({ library: "QSYS", name: library, type: "*LIB" })) {
      throw new Error(`Library ${library} does not exist.`);
    }

    const singleEntry = filters.filterType !== 'regex' ? singleGenericName(filters.object) : undefined;
    const nameFilter = parseFilter(filters.object, filters.filterType);
    const object = filters.object && (nameFilter.noFilter || singleEntry) && filters.object !== `*` ? filters.object.toUpperCase() : `*ALL`;
    const member = (filters.member ? filters.member.toUpperCase() : filters.member);
    const mbrtype = (filters.memberType ? filters.memberType.toUpperCase() : filters.memberType);
    const { instance } = (require(`../instantiate`));


    const typeFilter = filters.types && filters.types.length > 1 ? (t: string) => filters.types?.includes(t) : undefined;
    const type = filters.types && filters.types.length === 1 && filters.types[0] !== '*' ? filters.types[0] : '*ALL';

    const sourceFilesOnly = filters.types && filters.types.length === 1 && filters.types.includes(`*SRCPF`);
    const withSourceFiles = ['*ALL', '*SRCPF'].includes(type);

    const queries: string[] = [];

    if (!sourceFilesOnly) {
      queries.push(`CALL QSYS2.QCMDEXC('DSPOBJD OBJ(${library}/${object}) OBJTYPE(${type}) OUTPUT(*OUTFILE) OUTFILE(QTEMP/CODE4IOBJD)')`);
    }

    if (withSourceFiles) {
      let funcInfo :funcInfo = await this.whereisCustomFunc();
      if (funcInfo) {
        if (await this.checkObject({ library: funcInfo.funcSysLib, name: funcInfo.funcSysName, type: "*SRVPGM" })) {
          queries.push(`create or replace table QTEMP.CODE4IFD (PHLIB,PHFILE,PHFILA,PHDTAT,PHTXT,PHNOMB) as (select PHLIB,PHFILE,PHFILA,PHDTAT,PHTXT,PHNOMB from table ( ${funcInfo.funcSysLib}.VSC_getSourceFileListCustom (IN_SRCF => '${object}' ,IN_MBR => '${member}', IN_LIB => '${library}' ,IN_MBR_TYPE => '${mbrtype}' ) )) with data on replace delete rows`);
        }
      } else {
        queries.push(`CALL QSYS2.QCMDEXC('DSPFD FILE(${library}/${object}) TYPE(*ATR) FILEATR(*PF) OUTPUT(*OUTFILE) OUTFILE(QTEMP/CODE4IFD)')`);
      }
    }

    let createOBJLIST;
    if (sourceFilesOnly) {
      //DSPFD only
      createOBJLIST = `Select PHFILE as NAME, ` +
        `'*FILE' As TYPE, ` +
        `PHFILA As ATTRIBUTE, ` +
        `PHTXT As TEXT, ` +
        `1 As IS_SOURCE, ` +
        `PHNOMB As NB_MBR ` +
        `From QTEMP.CODE4IFD Where PHDTAT = 'S'`;
    } else if (!withSourceFiles) {
      //DSPOBJD only
      createOBJLIST = `Select ODOBNM as NAME, ` +
        `ODOBTP As TYPE, ` +
        `ODOBAT As ATTRIBUTE, ` +
        `ODOBTX As TEXT, ` +
        `0 As IS_SOURCE ` +
        `From QTEMP.CODE4IOBJD`;
    }
    else {
      //Both DSPOBJD and DSPFD
      createOBJLIST = `Select ODOBNM as NAME, ` +
        `ODOBTP As TYPE, ` +
        `ODOBAT As ATTRIBUTE, ` +
        `ODOBTX As TEXT, ` +
        `Case When PHDTAT = 'S' Then 1 Else 0 End As IS_SOURCE, ` +
        `PHNOMB As NB_MBR ` +
        `From QTEMP.CODE4IOBJD  ` +
        `Left Join QTEMP.CODE4IFD On PHFILE = ODOBNM And PHDTAT = 'S'`;
    }

    queries.push(`Create Table QTEMP.OBJLIST As (${createOBJLIST}) With DATA`);

    const objects = (await this.getQTempTable(queries, "OBJLIST"));
    return objects.map(object => ({
      library,
      name: this.ibmi.sysNameInLocal(String(object.NAME)),
      type: String(object.TYPE),
      attribute: String(object.ATTRIBUTE),
      text: String(object.TEXT),
      memberCount: object.NB_MBR !== undefined ? Number(object.NB_MBR) : undefined,
      sourceFile: Boolean(object.IS_SOURCE)
    } as IBMiObject))
      .filter(object => !typeFilter || typeFilter(object.type))
      .filter(object => nameFilter.test(object.name))
      .sort((a, b) => {
        if (a.library.localeCompare(b.library) != 0) {
          return a.library.localeCompare(b.library)
        }
        else if (sortOrder === `name`) {
          return a.name.localeCompare(b.name)
        }
        else {
          return ((ObjectTypes.get(a.type) || 0) - (ObjectTypes.get(b.type) || 0)) || a.name.localeCompare(b.name);
        }
      });
  }

  /**
   *
   * @param filter: the criterias used to list the members
   * @returns
   */
  async getMemberList(filter: { library: string, sourceFile: string, members?: string, extensions?: string, sort?: SortOptions, filterType?: FilterType }): Promise<IBMiMember[]> {
    const sort = filter.sort || { order: 'name' };
    const library = filter.library.toUpperCase();
    const sourceFile = filter.sourceFile.toUpperCase();

    const memberFilter = parseFilter(filter.members, filter.filterType);
    const singleMember = memberFilter.noFilter && filter.members && !filter.members.includes(",") ? filter.members.toLocaleUpperCase().replace(/[*]/g, `%`) : undefined;

    const memberExtensionFilter = parseFilter(filter.extensions, filter.filterType);
    const singleMemberExtension = memberExtensionFilter.noFilter && filter.extensions && !filter.extensions.includes(",") ? filter.extensions.toLocaleUpperCase().replace(/[*]/g, `%`) : undefined;

    let statement = ``;

    let funcInfo :funcInfo = await this.whereisCustomFunc();
    if (funcInfo) {

      if (await this.checkObject({ library: funcInfo.funcSysLib, name: funcInfo.funcSysName, type: "*SRVPGM" })) {
        statement = `\n select MBMXRL RECORD_LENGTH,MBASP ASP,MBLIB LIBRARY,MBFILE SOURCE_FILE,MBNAME NAME,MBSEU2 TYPE,MBMTXT TEXT,MBNRCD LINES,CREATED CREATED,CHANGED CHANGED,USERCONTENT from table (${funcInfo.funcSysLib}.VSC_getMemberListCustom(IN_LIB => '${library}' 
        ${sourceFile ? `,IN_SRCF => '${sourceFile}'` : ""}
        ${singleMember ? `,IN_MBR =>  '${singleMember}'` : ""} 
        ${singleMemberExtension ? `,IN_MBR_TYPE => '${singleMemberExtension}'` : ""} ))
        Order By ${sort.order === 'name' ? 'NAME' : 'CHANGED'} ${!sort.ascending ? 'DESC' : 'ASC'}`;
      }
    } else {
      statement =
        `With MEMBERS As (
        SELECT
          rtrim(cast(a.system_table_schema as char(10) for bit data)) as LIBRARY,
          b.avgrowsize as RECORD_LENGTH,
          a.iasp_number as ASP,
          rtrim(cast(a.system_table_name as char(10) for bit data)) AS SOURCE_FILE,
          rtrim(cast(b.system_table_member as char(10) for bit data)) as NAME,
          coalesce(rtrim(cast(b.source_type as varchar(10) for bit data)), '') as TYPE,
          coalesce(rtrim(b.partition_text), '') as TEXT,
          b.NUMBER_ROWS as LINES,
          extract(epoch from (b.CREATE_TIMESTAMP))*1000 as CREATED,
          extract(epoch from (b.LAST_SOURCE_UPDATE_TIMESTAMP))*1000 as CHANGED
        FROM qsys2.systables AS a
          JOIN qsys2.syspartitionstat AS b
            ON b.table_schema = a.table_schema AND
              b.table_name = a.table_name
      )
      Select * From MEMBERS
      Where LIBRARY = '${library}'
        ${sourceFile !== `*ALL` ? `And SOURCE_FILE = '${sourceFile}'` : ``}
        ${singleMember ? `And NAME Like '${singleMember}'` : ''}
        ${singleMemberExtension ? `And TYPE Like '${singleMemberExtension}'` : ''}
      Order By ${sort.order === 'name' ? 'NAME' : 'CHANGED'} ${!sort.ascending ? 'DESC' : 'ASC'}`;
    }
    let results: Tools.DB2Row[];
    if (this.config.enableSQL) {
      results = await this.runSQL(statement);
    }
    else {
      results = await this.getQTempTable([`Create Table QTEMP.MEMBERSLST As (${statement}) With DATA`], "MEMBERSLST");
    }

    if (results.length) {
      const asp = this.ibmi.aspInfo[Number(results[0].ASP)];
      return results.map(result => ({
        asp,
        library,
        file: String(result.SOURCE_FILE),
        name: String(result.NAME),
        extension: String(result.TYPE),
        recordLength: Number(result.RECORD_LENGTH) - 12,
        text: `${result.TEXT || ``}${sourceFile === `*ALL` ? ` (${result.SOURCE_FILE})` : ``}`.trim(),
        lines: Number(result.LINES),
        created: new Date(result.CREATED ? Number(result.CREATED) : 0),
        changed: new Date(result.CHANGED ? Number(result.CHANGED) : 0)
        ,usercontent: String(result.USERCONTENT)
      } as IBMiMember))
        .filter(member => memberFilter.test(member.name))
        .filter(member => memberExtensionFilter.test(member.extension));
    }
    else {
      return [];
    }
  }

  /**
   * Get list of items in a path
   * @param remotePath
   * @return an array of IFSFile
   */
  async getFileList(remotePath: string, sort: SortOptions = { order: "name" }, onListError?: (errors: string[]) => void): Promise<IFSFile[]> {
    const { 'stat': STAT } = this.ibmi.remoteFeatures;
    const { 'sort': SORT } = this.ibmi.remoteFeatures;

    const items: IFSFile[] = [];
    let fileListResult: CommandResult;

    if (STAT && SORT) {
      fileListResult = (await this.ibmi.sendCommand({
        command: `cd '${remotePath}' && ${STAT} --dereference --printf="%A\t%h\t%U\t%G\t%s\t%Y\t%n\n" * .* ${sort.order === `date` ? `| ${SORT} --key=6` : ``} ${(sort.order === `date` && !sort.ascending) ? ` --reverse` : ``}`
      }));

      if (fileListResult.stdout !== '') {
        const fileStatList = fileListResult.stdout;
        const fileList = fileStatList.split(`\n`);

        //Remove current and dir up.
        fileList.forEach(item => {
          let auth: string, hardLinks: string, owner: string, group: string, size: string, modified: string, name: string;
          [auth, hardLinks, owner, group, size, modified, name] = item.split(`\t`);

          if (name !== `..` && name !== `.`) {
            const type = (auth.startsWith(`d`) ? `directory` : `streamfile`);
            items.push({
              type: type,
              name: name,
              path: path.posix.join(remotePath, name),
              size: Number(size),
              modified: new Date(Number(modified) * 1000),
              owner: owner
            });
          };
        });
      }
    } else {
      fileListResult = (await this.ibmi.sendCommand({
        command: `${this.ibmi.remoteFeatures.ls} -a -p -L ${sort.order === "date" ? "-t" : ""} ${(sort.order === 'date' && sort.ascending) ? "-r" : ""} ${Tools.escapePath(remotePath)}`
      }));

      if (fileListResult.stdout !== '') {
        const fileList = fileListResult.stdout;

        //Remove current and dir up.
        fileList.split(`\n`)
          .filter(item => item !== `../` && item !== `./`)
          .forEach(item => {
            const type = (item.endsWith(`/`) ? `directory` : `streamfile`);
            items.push({
              type: type,
              name: (type === `directory` ? item.substring(0, item.length - 1) : item),
              path: path.posix.join(remotePath, item)
            });
          });
      }
    }

    if (sort.order === "name") {
      items.sort((f1, f2) => f1.name.localeCompare(f2.name));
      if (sort.ascending === false) {
        items.reverse();
      }
    }

    if (fileListResult.code !== 0) {
      //Filter out the errors occurring when stat is run on a directory with no hidden or regular files
      const errors = fileListResult.stderr.split("\n")
        .filter(e => !e.toLowerCase().includes("cannot stat '*'") && !e.toLowerCase().includes("cannot stat '.*'"))
        .filter(Tools.distinct);

      if (errors.length) {
        onListError ? onListError(errors) : errors.forEach(console.log);
      }
    }

    return items;
  }

  async memberResolve(member: string, files: QsysPath[]): Promise<IBMiMember | undefined> {
    // Escape names for shell
    const pathList = files
      .map(file => {
        const asp = file.asp || this.config.sourceASP;
        if (asp && asp.length > 0) {
          return [
            Tools.qualifyPath(file.library, file.name, member, asp, true),
            Tools.qualifyPath(file.library, file.name, member, undefined, true)
          ].join(` `);
        } else {
          return Tools.qualifyPath(file.library, file.name, member, undefined, true);
        }
      })
      .join(` `)
      .toUpperCase();

    const command = `for f in ${pathList}; do if [ -f $f ]; then echo $f; break; fi; done`;
    const result = await this.ibmi.sendCommand({
      command,
    });

    if (result.code === 0) {
      const firstMost = result.stdout;

      if (firstMost) {
        try {
          const simplePath = Tools.unqualifyPath(firstMost);

          // This can error if the path format is wrong for some reason.
          // Not that this would ever happen, but better to be safe than sorry
          return this.ibmi.parserMemberPath(simplePath);
        } catch (e) {
          console.log(e);
        }
      }
    }

    return undefined;
  }

  async objectResolve(object: string, libraries: string[]): Promise<string | undefined> {
    const command = `for f in ${libraries.map(lib => `/QSYS.LIB/${lib.toUpperCase()}.LIB/${object.toUpperCase()}.*`).join(` `)}; do if [ -f $f ] || [ -d $f ]; then echo $f; break; fi; done`;

    const result = await this.ibmi.sendCommand({
      command,
    });

    if (result.code === 0) {
      const firstMost = result.stdout;

      if (firstMost) {
        const lib = Tools.unqualifyPath(firstMost);

        return lib.split('/')[1];
      }
    }

    return undefined;
  }

  async streamfileResolve(names: string[], directories: string[]): Promise<string | undefined> {
    const command = `for f in ${directories.flatMap(dir => names.map(name => `"${path.posix.join(dir, name)}"`)).join(` `)}; do if [ -f "$f" ]; then echo $f; break; fi; done`;

    const result = await this.ibmi.sendCommand({
      command,
    });

    if (result.code === 0 && result.stdout) {
      const firstMost = result.stdout;

      return firstMost;
    }

    return undefined;
  }

  /**
  * @param {string} user 
  * @param {string} sortOrder
  * @param {string=} splfName
  * @returns {Promise<IBMiSpooledFile[]>}
  */
  async getUserSpooledFileFilter(user: string, sort: SortOptions = { order: "date" }, splfName?: string, searchWords?: string): Promise<IBMiSpooledFile[]> {
    // const connection = instance.getConnection();
    // const config = instance.getConfig();
    // const content = instance.getContent();

    // sort.order = sort.order === '?' ? 'name' : sort.order;
    // sort = sort.order || { order: 'name' };
    user = user.toUpperCase();

    const tempLib = this.config.tempLibrary;
    const tempName = Tools.makeid();
    var objQuery;
    let results: Tools.DB2Row[];

    objQuery = `select SPE.SPOOLED_FILE_NAME, SPE.SPOOLED_FILE_NUMBER, SPE.STATUS, SPE.CREATION_TIMESTAMP, SPE.USER_DATA, SPE.SIZE, SPE.TOTAL_PAGES, SPE.QUALIFIED_JOB_NAME, SPE.JOB_NAME, SPE.JOB_USER, SPE.JOB_NUMBER, SPE.FORM_TYPE, SPE.OUTPUT_QUEUE_LIBRARY, SPE.OUTPUT_QUEUE, QE.PAGE_LENGTH from table (QSYS2.SPOOLED_FILE_INFO(USER_NAME => ucase('${user}')) ) SPE left join TABLE(QSYS2.OUTPUT_QUEUE_ENTRIES( OUTQ_LIB => OUTPUT_QUEUE_LIBRARY ,OUTQ_NAME=> OUTPUT_QUEUE, DETAILED_INFO => 'YES',IGNORE_ERRORS => 'YES' ) ) QE on QE.SPOOLED_FILE_NAME = SPE.SPOOLED_FILE_NAME and QE.JOB_NAME = SPE.QUALIFIED_JOB_NAME and QE.FILE_NUMBER = SPE.SPOOLED_FILE_NUMBER where SPE.FILE_AVAILABLE = '*FILEEND' ${splfName ? ` and SPE.SPOOLED_FILE_NAME = ucase('${splfName}')` : ""}`;
    results = await this.runSQL(objQuery);

    if (results.length === 0) {
      return [];
    }
    results = results.sort((a, b) => String(a.MBSPOOLED_FILE_NAMENAME).localeCompare(String(b.SPOOLED_FILE_NAME)));

    let sorter: (r1: IBMiSpooledFile, r2: IBMiSpooledFile) => number;
    if (sort.order === 'name') {
      sorter = (r1, r2) => r1.name.localeCompare(r2.name);
    }
    else {
      sorter = (r1, r2) => r1.creation_timestamp.localeCompare(r2.creation_timestamp);
    }
    let searchWords_ = searchWords?.split(' ') || [];
    // console.log(searchWords_);

    // return results
    let returnSplfList = results
      .map(object => ({
        user: user,
        name: this.ibmi.sysNameInLocal(String(object.SPOOLED_FILE_NAME)),
        number: Number(object.SPOOLED_FILE_NUMBER),
        status: this.ibmi.sysNameInLocal(String(object.STATUS)),
        creation_timestamp: object.CREATION_TIMESTAMP,
        user_data: this.ibmi.sysNameInLocal(String(object.USER_DATA)),
        size: Number(object.SIZE),
        total_pages: Number(object.TOTAL_PAGES),
        page_length: Number(object.PAGE_LENGTH),
        qualified_job_name: this.ibmi.sysNameInLocal(String(object.QUALIFIED_JOB_NAME)),
        job_name: this.ibmi.sysNameInLocal(String(object.JOB_NAME)),
        job_user: this.ibmi.sysNameInLocal(String(object.JOB_USER)),
        job_number: String(object.JOB_NUMBER),
        form_type: this.ibmi.sysNameInLocal(String(object.FORM_TYPE)),
        queue_library: this.ibmi.sysNameInLocal(String(object.OUTPUT_QUEUE_LIBRARY)),
        queue: this.ibmi.sysNameInLocal(String(object.OUTPUT_QUEUE)),
      } as IBMiSpooledFile))
      .filter(obj => searchWords_.length === 0 || searchWords_.some(term => Object.values(obj).join(" ").includes(term)))
      .sort(sorter);

    return returnSplfList;

  }
  /**
  * Download the contents of a source member
  * @param {string} uriPath 
  * @param {string} name 
  * @param {string} qualified_job_name 
  * @param {string} splf_number 
  * @param {string} fileExtension 
  * @param {string=} additionalPath 
  * @returns {string} a string containing spooled file data 
  */
  async downloadSpooledFileContent(uriPath: string, name: string, qualified_job_name: string, splf_number: string, fileExtension: string, ctlchar?: string) {
    name = name.toUpperCase();
    qualified_job_name = qualified_job_name.toUpperCase();

    const tempRmt = this.getTempRemote(uriPath);
    const client = this.ibmi.client;

    let retried = false;
    let retry = 1;
    let fileEncoding = `utf8`;
    while (retry > 0) {
      retry--;
      try {
        //If this command fails we need to try again after we delete the temp remote
        switch (fileExtension.toLowerCase()) {
        case `pdf`:
          fileEncoding = ``;
          await this.ibmi.runCommand({
            command: `CPYSPLF FILE(${name}) TOFILE(*TOSTMF) JOB(${qualified_job_name}) SPLNBR(${splf_number}) TOSTMF('${tempRmt}') WSCST(*PDF) STMFOPT(*REPLACE)\nDLYJOB DLY(1)`
            , environment: `ile`
          });
          break;
        // case `prtctl`:
        //   const tempLib = this.config.tempLibrary;
        //   const tempName = Tools.makeid();
        //   await this.ibmi.runCommand({
        //     command: `CPYSPLF FILE(${name}) TOFILE(${tempLib}/${tempName}) JOB(${qualified_job_name}) SPLNBR(${splf_number}) CTLCHAR(*PRTCTL) MBROPT(*REPLACE)\nDLYJOB DLY(1)\nCPYTOIMPF FROMFILE(${tempLib}/${tempName}) TOSTMF('${tempRmt}') MBROPT(*REPLACE) `
        //     , environment: `ile`
        //   });
        //   break;            
        default:
          // With the use of CPYSPLF and CPY to create a text based stream file in 1208, there are possibilities that the data becomes corrupt
          // in the tempRmt object
          this.ibmi.sendCommand({
            command: `rm -f ${tempRmt}`
          });

          // fileExtension = `txt`;
          // DLYJOB to ensure the CPY command completes in time.
          await this.ibmi.runCommand({
            command: `CPYSPLF FILE(${name}) TOFILE(*TOSTMF) JOB(${qualified_job_name}) SPLNBR(${splf_number}) TOSTMF('${tempRmt}') WSCST(*NONE) STMFOPT(*REPLACE) ${ctlchar ? `CTLCHAR(*PRTCTL)` : ``}\nDLYJOB DLY(1)\nCPY OBJ('${tempRmt}') TOOBJ('${tempRmt}') TOCCSID(1208) DTAFMT(*TEXT) REPLACE(*YES)`
            , environment: `ile`
          });
        }
      } catch (e) {
        if (String(e).startsWith(`CPDA08A`)) {
          if (!retried) {
            await this.ibmi.sendCommand({ command: `rm -f ${tempRmt}`, directory: `.` });
            retry++;
            retried = true;
          } else {
            throw e;
          }
        } else {
          throw e;
        }
      }
    }
    return tempRmt;
    // await client.getFile(tmpobj, tempRmt);
    // return await readFileAsync(tmpobj, fileEncoding);

  }

  /**
  * @param {string} user
  * @param {string=} splfName
  * @returns {Promise<String>} a string with the count of spooled file for user
  */
  async getUserSpooledFileCount(user: string, splfName?: string, searchWord?: string): Promise<String> {
    // const connection = instance.getConnection();
    // const config = instance.getConfig();
    // const content = instance.getContent();

    user = user.toUpperCase();

    // const tempLib = this.config.tempLibrary;
    // const tempName = Tools.makeid();
    let results: Tools.DB2Row[];

    const objQuery = `select count(*) USER_SPLF_COUNT
    from table (QSYS2.SPOOLED_FILE_INFO(USER_NAME => '${user}') ) SPE 
    where FILE_AVAILABLE = '*FILEEND' ${splfName ? `and SPOOLED_FILE_NAME = ucase('${splfName}')` : ""} 
    group by JOB_USER` ;
    results = await this.runSQL(objQuery);
    // const resultSet = await new IBMiContent(this).runSQL(`SELECT * FROM QSYS2.ASP_INFO`);
    if (results.length === 0) {
      return ` ${user} user has no spooled files`;
    }
    return String(results[0].USER_SPLF_COUNT);
  }
  /**
  * @param {string} user
  * @returns a promised string for user profile text 
  */
  async getUserProfileText(user: string): Promise<string | undefined> {
    user = user.toUpperCase();

    const tempLib = this.config.tempLibrary;
    const tempName = Tools.makeid();
    let results: Tools.DB2Row[];

    const objQuery = `select UT.OBJTEXT USER_PROFILE_TEXT
    from table ( QSYS2.OBJECT_STATISTICS(OBJECT_SCHEMA => 'QSYS', OBJTYPELIST => '*USRPRF', OBJECT_NAME => '${user}') ) UT 
    where 1=1`;
    results = await this.runSQL(objQuery);
    if (results.length === 0) {
      return ` I dont know where to find the text for ${user}`;
    }
    const userText: string = String(results[0].USER_PROFILE_TEXT);
    return userText;
  }

 
  /**
   * Fix Comments in an SQL string so that the comments always start at position 0 of the line.
   * Required to work with QZDFMDB2.
   * @param inSql; sql statement
   * @returns correctly formattted sql string containing comments
   */
  private fixCommentsInSQLString(inSql: string): string {
    const newLine: string = `\n`;
    let parsedSql: string = ``;

    inSql.split(newLine)
      .forEach(item => {
        let goodLine = item + newLine;

        const pos = item.search(`--`);
        if (pos > 0) {
          goodLine = item.slice(0, pos) +
            newLine +
            item.slice(pos) +
            newLine;
        }
        parsedSql += goodLine;

      });

    return parsedSql;
  }

  /**
   * @param errorsString; several lines of `code:text`...
   * @returns errors
   */
  parseIBMiErrors(errorsString: string): IBMiError[] {
    return errorsString.split(`\n`)
      .map(error => error.split(':'))
      .map(codeText => ({ code: codeText[0], text: codeText[1] }));
  }

  /**
   * @param century; century code (1=20xx, 0=19xx)
   * @param dateString: string in YYMMDD
   * @param timeString: string in HHMMSS
   * @returns date
   */
  getDspfdDate(century: string = `0`, YYMMDD: string = `010101`, HHMMSS: string = `000000`): Date {
    let year: string, month: string, day: string, hours: string, minutes: string, seconds: string;
    let dateString: string = (century === `1` ? `20` : `19`).concat(YYMMDD.padStart(6, `0`)).concat(HHMMSS.padStart(6, `0`));
    [, year, month, day, hours, minutes, seconds] = /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/.exec(dateString) || [];
    return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hours), Number(minutes), Number(seconds)));
  }

  /**
   * Return `true` if `remotePath` denotes a directory
   *
   * @param remotePath: a remote IFS path
   */
  async isDirectory(remotePath: string) {
    return (await this.ibmi.sendCommand({
      command: `cd ${remotePath}`
    })).code === 0;
  }

  async checkObject(object: { library: string, name: string, type: string, member?: string }, authorities: Authority[] = [`*NONE`]) {
    return (await this.ibmi.runCommand({
      command: IBMiContent.toCl(`CHKOBJ`, {
        obj: `${object.library.toLocaleUpperCase()}/${object.name.toLocaleUpperCase()}`,
        objtype: object.type.toLocaleUpperCase(),
        aut: authorities.join(" "),
        mbr: object.member
      }),
      noLibList: true
    })).code === 0;
  }

  async testStreamFile(path: string, right: "r" | "w" | "x") {
    return (await this.ibmi.sendCommand({ command: `test -${right} ${Tools.escapePath(path)}` })).code === 0;
  }

  isProtectedPath(path: string) {
    if (path.startsWith('/')) { //IFS path
      return this.config.protectedPaths.some(p => path.startsWith(p));
    }
    else { //QSYS path
      const qsysObject = Tools.parseQSysPath(path);
      return this.config.protectedPaths.includes(qsysObject.library.toLocaleUpperCase());
    }
  }

  /**
   * 
   * @param command Optionally qualified CL command
   * @param parameters A key/value object of parameters
   * @returns Formatted CL string
   */
  static toCl(command: string, parameters: { [parameter: string]: string | number | undefined }) {
    let cl = command;

    for (const [key, value] of Object.entries(parameters)) {
      let parmValue;

      if (value !== undefined) {
        if (typeof value === 'string') {
          if (value === value.toLocaleUpperCase()) {
            parmValue = value;
          } else {
            parmValue = value.replace(/'/g, `''`);
            parmValue = `'${parmValue}'`;
          }
        } else {
          parmValue = String(value);
        }

        cl += ` ${key.toUpperCase()}(${parmValue})`;
      }
    }

    return cl;
  }
  async whereisCustomFunc(): Promise<funcInfo> {
    // async whereisCustomFunc() :Promise<{ funcSysLib: string; funcSysName: string; } | undefined> {
    // Look for the custom function somewhere
    const { instance } = (require(`../instantiate`));
    let currentUser = '';
    const connection = instance.getConnection();
    if (connection) {
      currentUser = connection.currentUser;
    }
    let funcLookupRS: Tools.DB2Row[];
    let statement = `select SPECIFIC_SCHEMA,SPECIFIC_NAME from QSYS2.SYSFUNCS SF inner join table( values(1,'${currentUser}'),(2,'ILEDITOR') ) LL (Pos, ASCHEMA) on ASCHEMA = SPECIFIC_SCHEMA where ROUTINE_NAME = 'VSC_GETSOURCEFILELISTCUSTOM' limit 1`;
    funcLookupRS = await this.runSQL(statement);
    return {
      funcSysLib: String(funcLookupRS[0].SPECIFIC_SCHEMA),
      funcSysName: String(funcLookupRS[0].SPECIFIC_NAME)
    }
  }

}
