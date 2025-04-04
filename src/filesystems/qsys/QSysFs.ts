import { parse as parsePath } from "path";
import { parse, ParsedUrlQueryInput, stringify } from "querystring";
import vscode, { FilePermission, FileSystemError } from "vscode";
import IBMi from "../../api/IBMi";
import { Tools } from "../../api/Tools";
import { onCodeForIBMiConfigurationChange } from "../../config/Configuration";
import { instance } from "../../instantiate";
import { IBMiMember, QsysFsOptions, QsysPath } from "../../typings";
import { ExtendedIBMiContent } from "./extendedContent";
import { reconnectFS } from "./FSUtils";
import { SourceDateHandler } from "./sourceDateHandler";

export function getMemberUri(member: IBMiMember, options?: QsysFsOptions) {
    return getUriFromPath(`${member.asp ? `${member.asp}/` : ``}${member.library}/${member.file}/${member.name}.${member.extension}`, options);
}

export function getUriFromPath(path: string, options?: QsysFsOptions) {
    const query = stringify(options as ParsedUrlQueryInput);
    if (path.startsWith(`/`)) {
        //IFS path
        return vscode.Uri.parse(path).with({ scheme: `streamfile`, path, query });
    } else {
        //QSYS path
        return vscode.Uri.parse(path).with({ scheme: `member`, path: `/${path}`, query });
    }
}

export function getFilePermission(uri: vscode.Uri): FilePermission | undefined {
    const fsOptions = parseFSOptions(uri);
    if (instance.getConnection()?.getConfig().readOnlyMode || fsOptions.readonly) {
        return FilePermission.Readonly;
    }
}

export function parseFSOptions(uri: vscode.Uri): QsysFsOptions {
    const parameters = parse(uri.query);
    return {
        readonly: parameters.readonly === `true`
    };
}

export function isProtectedFilter(filter?: string): boolean {
    return filter && instance.getConnection()?.getConfig().objectFilters.find(f => f.name === filter)?.protected || false;
}

export class QSysFS implements vscode.FileSystemProvider {
    private readonly savedAsMembers: Set<string> = new Set;
    private readonly sourceDateHandler: SourceDateHandler;
    private readonly extendedContent: ExtendedIBMiContent;
    private extendedMemberSupport = false;
    private emitter = new vscode.EventEmitter<vscode.FileChangeEvent[]>();
    onDidChangeFile: vscode.Event<vscode.FileChangeEvent[]> = this.emitter.event;

    constructor(context: vscode.ExtensionContext) {
        this.sourceDateHandler = new SourceDateHandler(context);
        this.extendedContent = new ExtendedIBMiContent(this.sourceDateHandler);

        instance.subscribe(
            context,
            'connected',
            `Update member support`,
            () => this.updateMemberSupport());

        instance.subscribe(
            context,
            'disconnected',
            `Update member support & clear library ASP cache`,
            () => {
                this.updateMemberSupport();
            });
    }

    private updateMemberSupport() {
        this.extendedMemberSupport = false
        const connection = instance.getConnection();
        const config = connection?.getConfig();

        if (connection && config?.enableSourceDates) {
            if (connection.sqlRunnerAvailable()) {
                this.extendedMemberSupport = true;
            } else {
                vscode.window.showErrorMessage(`Source date support is enabled, but the remote system does not support SQL. Source date support will be disabled.`);
            }
        }

        this.sourceDateHandler.setEnabled(this.extendedMemberSupport);
    }

    async stat(uri: vscode.Uri): Promise<vscode.FileStat> {
        const path = uri.path;
        const pathParts = path.split(`/`).filter(Boolean);
        if (pathParts.length > 4 || !path.startsWith('/')) {
            throw new vscode.FileSystemError("Invalid member path");
        }

        let type = vscode.FileType.File;
        const connection = instance.getConnection();
        if (connection) {
            const filePathLength = connection.getIAspDetail(pathParts[0]) ? 4 : 3;
            if(pathParts.length < filePathLength){
                type = vscode.FileType.Directory;
            }
            
            if (type === vscode.FileType.File) {
                const member = parsePath(path).name;
                const qsysPath = { ...Tools.parseQSysPath(path), member };
                const attributes = await this.getMemberAttributes(connection, qsysPath);
                if (attributes) {
                    return {
                        ctime: Tools.parseAttrDate(String(attributes.CREATE_TIME)),
                        mtime: Tools.parseAttrDate(String(attributes.MODIFY_TIME)),
                        size: Number(attributes.DATA_SIZE),
                        type,
                        permissions: member && !this.savedAsMembers.has(uri.path) ? getFilePermission(uri) : undefined
                    }
                } else {
                    throw FileSystemError.FileNotFound(uri);
                }
            }
        }

        return {
            ctime: 0,
            mtime: 0,
            size: 0,
            type,
            permissions: getFilePermission(uri)
        }
    }

    async getMemberAttributes(connection: IBMi, path: QsysPath & { member?: string }) {
        path.asp = path.asp || await connection.lookupLibraryIAsp(path.library);
        return await connection.getContent().getAttributes(path, "CREATE_TIME", "MODIFY_TIME", "DATA_SIZE");
    }

    parseMemberPath(connection: IBMi, path: string) {
        const memberParts = connection.parserMemberPath(path);
        memberParts.asp = memberParts.asp || connection.getLibraryIAsp(memberParts.library);
        return memberParts;
    }

    async readFile(uri: vscode.Uri, retrying?: boolean): Promise<Uint8Array> {
        const connection = instance.getConnection();
        if (connection) {
            const contentApi = connection.getContent();
            let { asp, library, file, name: member } = this.parseMemberPath(connection, uri.path);
            asp = asp || await connection.lookupLibraryIAsp(library);

            let memberContent;
            try {
                memberContent = this.extendedMemberSupport ?
                    await this.extendedContent.downloadMemberContentWithDates(uri) :
                    await contentApi.downloadMemberContent(library, file, member);
            } catch (error) {
                if (!retrying && await this.stat(uri)) { //Check if exists on an iASP and retry if so
                    return this.readFile(uri, true);
                }
                throw error;
            }
            if (memberContent !== undefined) {
                return new Uint8Array(Buffer.from(memberContent, `utf8`));
            } else {
                throw new FileSystemError(`Couldn't read ${uri}; check IBM i connection.`);
            }
        } else {
            if (retrying) {
                throw new FileSystemError("Not connected to IBM i");
            } else {
                if (await reconnectFS(uri)) {
                    this.updateMemberSupport(); //this needs to be done right after reconnecting, before the member is read (the connect event may be triggered too late at this point)
                    return this.readFile(uri, true);
                } else {
                    return Buffer.alloc(0);
                }
            }
        }
    }

    async writeFile(uri: vscode.Uri, content: Uint8Array, options: { readonly create: boolean; readonly overwrite: boolean; }) {
        const path = uri.path;
        const connection = instance.getConnection();
        if (connection) {
            const contentApi = connection.getContent();
            let { asp, library, file, name: member, extension } = this.parseMemberPath(connection, uri.path);
            asp = asp || await connection.lookupLibraryIAsp(library);

            if (!content.length) { //Coming from "Save as"
                const addMember = await connection.runCommand({
                    command: `ADDPFM FILE(${library}/${file}) MBR(${member}) SRCTYPE(${extension || '*NONE'})`,
                    noLibList: true
                });
                if (addMember.code === 0) {
                    this.savedAsMembers.add(uri.path);
                    vscode.commands.executeCommand(`code-for-ibmi.refreshObjectBrowser`);
                } else {
                    throw new FileSystemError(addMember.stderr);
                }
            }
            else {
                this.savedAsMembers.delete(uri.path);
                this.extendedMemberSupport ?
                    await this.extendedContent.uploadMemberContentWithDates(uri, content.toString()) :
                    await contentApi.uploadMemberContent(library, file, member, content);
            }
        }
        else {
            throw new FileSystemError("Not connected to IBM i");
        }
    }

    rename(oldUri: vscode.Uri, newUri: vscode.Uri, options: { readonly overwrite: boolean; }): void | Thenable<void> {
        //Not used at the moment
    }

    watch(uri: vscode.Uri, options: { readonly recursive: boolean; readonly excludes: readonly string[]; }): vscode.Disposable {
        return { dispose: () => { } };
    }

    async readDirectory(uri: vscode.Uri): Promise<[string, vscode.FileType][]> {
        const connection = instance.getConnection();
        if (connection) {
            const content = connection.getContent();
            const qsysPath = Tools.parseQSysPath(uri.path);
            if (qsysPath.name) {
                return (await content.getMemberList({ library: qsysPath.library, sourceFile: qsysPath.name }))
                    .map(member => [`${member.name}${member.extension ? `.${member.extension}` : ''}`, vscode.FileType.File]);
            }
            else if (qsysPath.library) {
                return (await content.getObjectList({ library: qsysPath.library, types: ["*SRCPF"] }))
                    .map(srcPF => [srcPF.name, vscode.FileType.Directory]);
            }
            else if (uri.path === '/') {
                return (await connection.runSQL(`select OBJNAME from table (QSYS2.OBJECT_STATISTICS ('*ALLSIMPLE', 'LIB', '*ALLSIMPLE'))`))
                    .map(row => [row.OBJNAME as string, vscode.FileType.Directory]);
            }
        }
        throw FileSystemError.FileNotFound(uri);
    }

    async createDirectory(uri: vscode.Uri) {
        const connection = instance.getConnection();
        if (connection) {
            const qsysPath = Tools.parseQSysPath(uri.path);
            if (qsysPath.library && !await connection.getContent().checkObject({ library: "QSYS", name: qsysPath.library, type: "*LIB" })) {
                const createLibrary = await connection.runCommand({
                    command: `CRTLIB LIB(${qsysPath.library})`,
                    noLibList: true
                });
                if (createLibrary.code !== 0) {
                    throw FileSystemError.NoPermissions(createLibrary.stderr);
                }
            }
            if (qsysPath.name) {
                const createFile = await connection.runCommand({
                    command: `CRTSRCPF FILE(${qsysPath.library}/${qsysPath.name}) RCDLEN(112)`,
                    noLibList: true
                });
                if (createFile.code !== 0) {
                    throw FileSystemError.NoPermissions(createFile.stderr);
                }
            }
        }
    }

    delete(uri: vscode.Uri, options: { readonly recursive: boolean; }): void | Thenable<void> {
        throw new FileSystemError("Method not implemented.");
    }
}