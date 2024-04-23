// import { parse } from 'csv-parse/sync';
import fs from 'fs';
import path from 'path';
import tmp from 'tmp';
import util from 'util';
// import { window } from 'vscode';
// import { ObjectTypes } from '../filesystems/qsys/Objects';
// import { CommandResult, IBMiError, IBMiFile, IBMiMember, IBMiObject, IFSFile, QsysPath } from '../typings';
import { IBMiSpooledFile } from '../typingsSplf';
import { ConnectionConfiguration } from './Configuration';
import { default as IBMi } from './IBMi';
import { Tools } from './Tools';
import { instance } from "../instantiate";
// import IBMiContent from "./IBMiContent";
const tmpFile = util.promisify(tmp.file);
const readFileAsync = util.promisify(fs.readFile);
const writeFileAsync = util.promisify(fs.writeFile);

const UTF8_CCSIDS = [`819`, `1208`, `1252`];

// type Authority = "*ADD" | "*DLT" | "*EXECUTE" | "*READ" | "*UPD" | "*NONE" | "*ALL" | "*CHANGE" | "*USE" | "*EXCLUDE" | "*AUTLMGT";
export type SortOrder = `name` | `type`;

export type SortOptions = {
  order: "name" | "date" | "?"
  ascending?: boolean
}

export default class IBMiContentSplf {

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

  /**
  * @param {string} user 
  * @param {string} sortOrder
  * @param {string=} splfName
  * @returns {Promise<IBMiSpooledFile[]>}
  */
  async getUserSpooledFileFilter(user: string, sort: SortOptions = { order: "date" }, splfName?: string, searchWords?: string): Promise<IBMiSpooledFile[]> {
    // const connection = instance.getConnection();
    // const config = instance.getConfig();
    const content = instance.getContent();

    sort.order = sort.order === '?' ? 'name' : sort.order;
    user = user.toUpperCase();

    const tempLib = this.config.tempLibrary;
    const tempName = Tools.makeid();
    var objQuery;
    let results: Tools.DB2Row[]|undefined;

    objQuery = `select SPE.SPOOLED_FILE_NAME, SPE.SPOOLED_FILE_NUMBER, SPE.STATUS, SPE.CREATION_TIMESTAMP, SPE.USER_DATA, SPE.SIZE, SPE.TOTAL_PAGES, SPE.QUALIFIED_JOB_NAME, SPE.JOB_NAME, SPE.JOB_USER, SPE.JOB_NUMBER, SPE.FORM_TYPE, SPE.OUTPUT_QUEUE_LIBRARY, SPE.OUTPUT_QUEUE, QE.PAGE_LENGTH from table (QSYS2.SPOOLED_FILE_INFO(USER_NAME => ucase('${user}')) ) SPE left join QSYS2.OUTPUT_QUEUE_ENTRIES QE on QE.SPOOLED_FILE_NAME = SPE.SPOOLED_FILE_NAME and QE.JOB_NAME = SPE.QUALIFIED_JOB_NAME and QE.FILE_NUMBER = SPE.SPOOLED_FILE_NUMBER where SPE.FILE_AVAILABLE = '*FILEEND' ${splfName ? ` and SPE.SPOOLED_FILE_NAME = ucase('${splfName}')` : ""}`;
    results = await content?.runSQL(objQuery);

    if (!results || results.length === 0) {
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
  async downloadSpooledFileContent(uriPath: string, name: string, qualified_job_name: string, splf_number: string, fileExtension: string, additionalPath?: string) {
    name = name.toUpperCase();
    qualified_job_name = qualified_job_name.toUpperCase();

    const tempRmt = this.getTempRemote(uriPath);
    const tmpobj = await tmpFile();

    const tmpName = path.basename(tempRmt);
    const tmpFolder = path.dirname(tempRmt) + (additionalPath ? `/${additionalPath}` : ``);

    // const path = homeDirectory +(folder !== undefined ? '/'+folder :'');
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
        default:
          // With the use of CPYSPLF and CPY to create a text based stream file in 1208, there are possibilities that the data becomes corrupt
          // in the tempRmt object
          this.ibmi.sendCommand({
            command: `rm -f ${tempRmt}`
          });

          // fileExtension = `txt`;
          // DLYJOB to ensure the CPY command completes in time.
          await this.ibmi.runCommand({
            command: `CPYSPLF FILE(${name}) TOFILE(*TOSTMF) JOB(${qualified_job_name}) SPLNBR(${splf_number}) TOSTMF('${tempRmt}') WSCST(*NONE) STMFOPT(*REPLACE)\nDLYJOB DLY(1)\nCPY OBJ('${tempRmt}') TOOBJ('${tempRmt}') TOCCSID(1208) DTAFMT(*TEXT) REPLACE(*YES)`
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

    await client.getFile(tmpobj, tempRmt);
    return await readFileAsync(tmpobj, fileEncoding);

  }

  /**
  * @param {string} user
  * @param {string=} splfName
  * @returns {Promise<String>} a string with the count of spooled file for user
  */
  async getUserSpooledFileCount(user: string, splfName?: string, searchWord?: string): Promise<String> {
    // const connection = instance.getConnection();
    // const config = instance.getConfig();
    const content = instance.getContent();

    user = user.toUpperCase();

    // const tempLib = this.config.tempLibrary;
    // const tempName = Tools.makeid();
    let results: Tools.DB2Row[] | undefined;

    const objQuery = `select count(*) USER_SPLF_COUNT
    from table (QSYS2.SPOOLED_FILE_INFO(USER_NAME => '${user}') ) QE 
    where FILE_AVAILABLE = '*FILEEND' ${splfName ? `and SPE.SPOOLED_FILE_NAME = ucase('${splfName}')` : ""} 
    group by SPE.JOB_USER` ;
    results = await content?.runSQL(objQuery);
    // const resultSet = await new IBMiContent(this).runSQL(`SELECT * FROM QSYS2.ASP_INFO`);
    if (results) {
      if (results.length === 0) {
        return ` ${user} user has no spooled files`;
      }
      return String(results[0].USER_SPLF_COUNT);
    }
    return ``;
  }
  /**
  * @param {string} user
  * @returns a promised string for user profile text 
  */
  async getUserProfileText(user: string): Promise<string | undefined> {
    user = user.toUpperCase();
    const content = instance.getContent();

    const tempLib = this.config.tempLibrary;
    const tempName = Tools.makeid();
    let results: Tools.DB2Row[]|undefined;

    const objQuery = `select UT.OBJTEXT USER_PROFILE_TEXT
    from table ( QSYS2.OBJECT_STATISTICS(OBJECT_SCHEMA => 'QSYS', OBJTYPELIST => '*USRPRF', OBJECT_NAME => '${user}') ) UT 
    where 1=1`;
    results = await content?.runSQL(objQuery);
    if (results) {
    if (results.length === 0) {
      return ` I dont know where to find the text for ${user}`;
    }
    const userText: string = String(results[0].USER_PROFILE_TEXT);
    return userText;
  }
  return ``;
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

  // /**
  //  * @param errorsString; several lines of `code:text`...
  //  * @returns errors
  //  */
  // parseIBMiErrors(errorsString: string): IBMiError[] {
  //   return errorsString.split(`\n`)
  //     .map(error => error.split(':'))
  //     .map(codeText => ({ code: codeText[0], text: codeText[1] }));
  // }

  // /**
  //  * @param century; century code (1=20xx, 0=19xx)
  //  * @param dateString: string in YYMMDD
  //  * @param timeString: string in HHMMSS
  //  * @returns date
  //  */
  // getDspfdDate(century: string = `0`, YYMMDD: string = `010101`, HHMMSS: string = `000000`): Date {
  //   let year: string, month: string, day: string, hours: string, minutes: string, seconds: string;
  //   let dateString: string = (century === `1` ? `20` : `19`).concat(YYMMDD.padStart(6, `0`)).concat(HHMMSS.padStart(6, `0`));
  //   [, year, month, day, hours, minutes, seconds] = /(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/.exec(dateString) || [];
  //   return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hours), Number(minutes), Number(seconds)));
  // }

  // /**
  //  * Return `true` if `remotePath` denotes a directory
  //  * 
  //  * @param remotePath: a remote IFS path
  //  */
  // async isDirectory(remotePath: string) {
  //   return (await this.ibmi.sendCommand({
  //     command: `cd ${remotePath}`
  //   })).code === 0;
  // }

  // async checkObject(object: { library: string, name: string, type: string }, ...authorities: Authority[]) {
  //   return (await this.ibmi.runCommand({
  //     command: `CHKOBJ OBJ(${object.library.toLocaleUpperCase()}/${object.name.toLocaleUpperCase()}) OBJTYPE(${object.type.toLocaleUpperCase()}) AUT(${authorities.join(" ")})`,
  //     noLibList: true
  //   })).code === 0;
  // }

  // async testStreamFile(path: string, right: "r" | "w" | "x") {
  //   return (await this.ibmi.sendCommand({ command: `test -${right} ${Tools.escapePath(path)}` })).code === 0;
  // }

  // isProtectedPath(path: string) {
  //   if (path.startsWith('/')) { //IFS path
  //     return this.config.protectedPaths.some(p => path.startsWith(p));
  //   }
  //   else { //QSYS path      
  //     const qsysObject = Tools.parseQSysPath(path);
  //     return this.config.protectedPaths.includes(qsysObject.library.toLocaleUpperCase());
  //   }
  // }
}
