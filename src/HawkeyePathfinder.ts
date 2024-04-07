import vscode, { TreeDataProvider } from "vscode";
import { GlobalConfiguration } from "./api/Configuration";
import { HawkeyeSearch } from "./api/HawkeyeSearch";
// import { instance, setSearchResultsHwk } from "./instantiate";
import { instance } from "./instantiate";
import { t } from "./locale";
import { IBMiMember } from "./typings";

export function initializeHawkeyePathfinder(context: vscode.ExtensionContext) {

  context.subscriptions.push(
    vscode.commands.registerCommand(`Hawkeye-Pathfinder.searchSourceFiles`, async (node) => {
      const parameters = {
        path: node?.path,
        filter: node?.filter
      }

      if (!parameters.path) {
        const connection = getConnection();
        const input = await vscode.window.showInputBox({
          prompt: t(`objectBrowser.searchSourceFile.prompt`),
          title: t(`objectBrowser.searchSourceFile.title`),
          validateInput: (input) => {
            input = input.trim();
            const path = input.split(`/`);
            let checkPath;
            if (path.length > 3) {
              return t(`objectBrowser.searchSourceFile.invalidForm`)
            } else if (path.length > 2) {                 // Check member
              let checkMember = path[2].replace(/[*]/g, ``).split(`.`);
              checkMember[0] = checkMember[0] !== `` ? checkMember[0] : `a`;
              checkPath = path[0] + `/` + path[1] + `/` + checkMember[0] + `.` + (checkMember.length > 1 ? checkMember[1] : ``);
            } else if (path.length > 1) {                 // Check filename
              checkPath = input + (path[path.length - 1] === `` ? `a` : ``) + `/a.b`;
            } else {                                      // Check library
              checkPath = input + (path[path.length - 1] === `` ? `a` : ``) + `/a/a.a`;
            }
            // if (checkPath) {
            //   try {
            //     connection.parserMemberPath(checkPath);
            //   } catch (e: any) {
            //     return e;
            //   }
            // }
          }
        });

        if (input) {
          const path = input.trim().toUpperCase().split(`/`);
          let member: string[] = [];
          if (path.length < 3 || path[2] === ``) {
            member = [`*`, `*`];
          } else if (!path[2].includes(`.`)) {
            member = [path[2], `*`];
          } else {
            member = path[2].split(`.`);
          }
          if (path.length == 1 || path[1] === ``) { path[1] = `*` }
          parameters.path = [path[0], path[1], member[0], member[1]].join('/');
        }
      }

      // Hawkeye-Pathfinder
      if (parameters.path) {
        const config = getConfig();
        const content = getContent();

        const pathParts = parameters.path.split(`/`);

        if (pathParts[1] !== ` `) {
          const aspText = ((config.sourceASP && config.sourceASP.length > 0) ? t(`objectBrowser.searchSourceFile.aspText`, config.sourceASP) : ``);

          const searchTerm = await vscode.window.showInputBox({
            prompt: t(`objectBrowser.HWKsearchSourceFile.prompt2`, parameters.path, aspText)
          });

          if (searchTerm) {
            try {
              let members: IBMiMember[] = [];
              await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `Searching`,
              }, async progress => {
                progress.report({
                  message: t(`objectBrowser.HWKsearchSourceFile.progressMessage`, parameters.path)
                });
                parameters.filter.member = `${pathParts[2] || `*`}.${pathParts[3] || `*`}`;
                const members = await content.getMemberList({ library: pathParts[0]?pathParts[0]:`QGPL`, sourceFile: pathParts[1]?pathParts[1]:`QCLSRC`, members: parameters.filter?.member });

                if (members.length > 0) {
                  // NOTE: if more messages are added, lower the timeout interval
                  const timeoutInternal = 9000;
                  const searchMessages = [
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage0`),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage1`, searchTerm, parameters.path),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage2`, members.length, searchTerm, parameters.path),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage3`, searchTerm),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage4`, searchTerm, parameters.path),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage5`),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage6`),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage7`),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage8`, members.length),
                    t(`objectBrowser.HWKsearchSourceFile.searchMessage9`, searchTerm, parameters.path),
                  ];

                  let currentMessage = 0;
                  const messageTimeout = setInterval(() => {
                    if (currentMessage < searchMessages.length) {
                      progress.report({
                        message: searchMessages[currentMessage]
                      });
                      currentMessage++;
                    } else {
                      clearInterval(messageTimeout);
                    }
                  }, timeoutInternal);
                  // Hawkeye-Pathfinder-DSPSCNSRC
                  // returns results member name with member type as extension
                  let results = await HawkeyeSearch.HwksearchMembers(instance, pathParts[0], pathParts[1], parameters.filter.member, searchTerm, parameters?.filter?.protected);

                  // Filter search result by member type filter.
                  if (results.length > 0 && parameters.filter?.memberTypeFilter) {
                    const patternExt = new RegExp(`^` + parameters.filter?.memberTypeFilter.replace(/[*]/g, `.*`).replace(/[$]/g, `\\$`) + `$`);
                    results = results.filter(result => {
                      const resultPath = result.path.split(`/`);
                      const resultName = resultPath[resultPath.length - 1].split(`.`)[0];
                      const member = members.find(member => member.name === resultName);
                      return (member && patternExt.test(member.extension));
                    })
                  }

                  if (results.length > 0) {
                    const objectNamesLower = GlobalConfiguration.get(`ObjectBrowser.showNamesInLowercase`);

                    results.forEach(result => {
                      if (objectNamesLower === true) {
                        result.path = result.path.toLowerCase();
                      }
                      result.label = result.path;
                    });

                    results = results.sort((a, b) => {
                      return a.path.localeCompare(b.path);
                    });
                    // TODO: make this stand alone for HWK commands
                    setSearchResultsHwk(searchTerm, results);

                  } else {
                    vscode.window.showInformationMessage(t(`objectBrowser.HWKsearchSourceFile.notFound`
                      , searchTerm, parameters.path
                    ));
                  }

                } else {
                  vscode.window.showErrorMessage(t(`objectBrowser.HWKsearchSourceFile.noMembers`));
                }

              });

            } catch (e) {
              vscode.window.showErrorMessage(t(`objectBrowser.HWKsearchSourceFile.errorMessage`, e));
            }
          }
        }
        //  else {
        //   vscode.window.showErrorMessage(`Cannot search listings using nothing for the file name.`);
        // With HAWKEYE/DSPSCNSRC we converts no file / member /type values into generics *ALL
        // }

      } else {
        //Running from command.
      }
    }),
    vscode.commands.registerCommand(`Hawkeye-Pathfinder.displayFileSetsUsed`, async (node) => {
      const parameters = {
        path: node?.path,
        filter: node?.filter
      }

      if (!parameters.path) {
        const connection = getConnection();
        const input = await vscode.window.showInputBox({
          prompt: t(`objectBrowser.HWKdisplayFileSetsUsed.prompt`),
          title: t(`objectBrowser.HWKdisplayFileSetsUsed.title`),
          validateInput: (input) => {
            input = input.trim();
            const path = input.split(`/`);
            let checkPath;
            if (path.length > 2) {
              return t(`objectBrowser.HWKdisplayFileSetsUsed.invalidForm`)
              // } else if (path.length > 2) {                 
              // let checkMember = path[2].replace(/[*]/g, ``).split(`.`);
              // checkMember[0] = checkMember[0] !== `` ? checkMember[0] : `a`;
              // checkPath = path[0] + `/` + path[1] + `/` + checkMember[0] + `.` + (checkMember.length > 1 ? checkMember[1] : ``);
              // } else if (path.length > 1) {                 // Check filename
              // checkPath = input + (path[path.length - 1] === `` ? `a` : ``) + `/a.b`;
              // } else {                                      // Check library
              // checkPath = input + (path[path.length - 1] === `` ? `a` : ``) + `/a/a.a`;
            }
            // if (checkPath) {
            //   try {
            //     connection.parserMemberPath(checkPath);
            //   } catch (e: any) {
            //     return e;
            //   }
            // }
          }
        });

        if (input) {
          const path = input.trim().toUpperCase().split(`/`);
          // let member:string[] = [];
          // if (path.length < 3 || path[2] === ``) {
          //   member = [`*`, `*`];
          // } else if (!path[2].includes(`.`)) {
          //   member = [path[2], `*`];
          // } else {
          //   member = path[2].split(`.`);
          // }
          if (path.length == 1 || path[1] === ``) { path[1] = `*` }
          parameters.path = [path[0], path[1]].join('/');
        }
      }

      // Hawkeye-Pathfinder
      if (parameters.path) {
        const config = getConfig();
        const content = getContent();

        const pathParts = parameters.path.split(`/`);

        if (pathParts[1] !== ` `) {
          const aspText = ((config.sourceASP && config.sourceASP.length > 0) ? t(`objectBrowser.searchSourceFile.aspText`, config.sourceASP) : ``);

          const searchTerm = await vscode.window.showInputBox({
            prompt: t(`objectBrowser.HWKdisplayFileSetsUsed.prompt2`),
            value: `*NA`
          });

          if (searchTerm) {
            try {
              let members: IBMiMember[] = [];
              await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `Searching`,
              }, async progress => {
                progress.report({
                  message: t(`objectBrowser.HWKdisplayFileSetsUsed.progressMessage`, parameters.path)
                });
                // const members = await content.get MemberList(pathParts[0], pathParts[1], parameters.filter?.member);
                // const members = await content.get MemberList(`QGPL`, `QCLSRC`, parameters.filter?.member);
                // const members = 0;

                // if (members.length > 0) {
                // NOTE: if more messages are added, lower the timeout interval
                const timeoutInternal = 9000;
                const searchMessages = [
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage0`),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage1`, searchTerm, parameters.path),
                  // t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage2`, members.length, xrefLib, parameters.path),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage3`, searchTerm, parameters.path),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage4`, parameters.path),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage5`),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage6`),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage7`),
                  // t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage8`, members.length),
                  t(`objectBrowser.HWKdisplayFileSetsUsed.searchMessage9`, searchTerm, parameters.path),
                ];

                let currentMessage = 0;
                const messageTimeout = setInterval(() => {
                  if (currentMessage < searchMessages.length) {
                    progress.report({
                      message: searchMessages[currentMessage]
                    });
                    currentMessage++;
                  } else {
                    clearInterval(messageTimeout);
                  }
                }, timeoutInternal);
                // Hawkeye-Pathfinder-DSPSCNSRC
                // returns results member name with member type as extension
                let results = await HawkeyeSearch.HwkdisplayFileSetsUsed(instance, pathParts[0], pathParts[1], searchTerm, parameters?.filter?.protected);

                // Filter search result by member type filter.
                if (results.length > 0 && parameters.filter?.memberTypeFilter) {
                  const patternExt = new RegExp(`^` + parameters.filter?.memberTypeFilter.replace(/[*]/g, `.*`).replace(/[$]/g, `\\$`) + `$`);
                  results = results.filter(result => {
                    const resultPath = result.path.split(`/`);
                    const resultName = resultPath[resultPath.length - 1].split(`.`)[0];
                    const member = members.find(member => member.name === resultName);
                    return (member && patternExt.test(member.extension));
                  })
                }

                if (results.length > 0) {
                  const objectNamesLower = GlobalConfiguration.get(`ObjectBrowser.showNamesInLowercase`);

                  results.forEach(result => {
                    if (objectNamesLower === true) {
                      result.path = result.path.toLowerCase();
                    }
                    result.label = result.path;
                  });

                  results = results.sort((a, b) => {
                    return a.path.localeCompare(b.path);
                  });
                  // TODO: make this stand alone for HWK commands
                  // setSearchResults(parameters.path, results);
                  setSearchResultsHwk(parameters.path, results);

                } else {
                  vscode.window.showInformationMessage(t(`objectBrowser.HWKdisplayFileSetsUsed.notFound`
                    , searchTerm, parameters.path
                  ));
                }

                // } else {
                //   vscode.window.showErrorMessage(t(`objectBrowser.HWKdisplayFileSetsUsed.noMembers`));
                // }

              });

            } catch (e) {
              vscode.window.showErrorMessage(t(`objectBrowser.HWKdisplayFileSetsUsed.errorMessage`, e));
            }
          }
        }
        //  else {
        //   vscode.window.showErrorMessage(`Cannot search listings using nothing for the file name.`);
        // With HAWKEYE/DSPFILSETU we converts no file / member /type values into generics *ALL
        // }

      } else {
        //Running from command.
      }
    })
  );
}

function getConfig() {
  const config = instance.getConfig();
  if (config) {
    return config;
  }
  else {
    throw new Error(t('not.connected'));
  }
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