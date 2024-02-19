# Code for IBM i - Winco Fork

Using this fork to add in Winco personalized changes to the extension.  For instance, you can create filters that link to Aldon Project, or a filter that represents information from one of several hawkeye cross reference tools.

## * Aldon tasks
  1. You have to create a filter that limits to one library environment.
  2. You can limit results to a certain source file by specifying a source file in the filter.
  3. To link this filter to an Aldon project, add this pattern in the member input, `#PCR#####VV`, where ##### is the PCr number and VV is the PCR version.
## * Hawkeye cross reference
  1. The source library needs to be main production copy of source, like WFISRC, DTSUSER, etc. 
  2. Filter to all source files using Q*.
  3. Make the member the source object you are looking up cross reference for.  This object needs to be qualified to its actual object location.
  4. Make the member type a special value that matches the cross reference command like `$HWK$FSU`.
     - $HWK : always required
       - $FSU : DSPFILSETU
       - $DOU : DSPOBJU
       - $DPO : DSPPGMOBJ

## * Actions added
  <img src="Actions.png">
  
## * Key short-cuts added
  * Atl+D : Delete Line
  * Alt+J : Join Line
  * Alt+T : Transform to Title Case
  * Alt+U : Transform to Upper Case
  * Alt+I : Transform to Lower Case
  * Shift+Alt+V : Convert to Free Format RPGLE
  * Ctrl+Alt+O : Open Outline View


[GitHub star the original repo 🌟](https://github.com/codefori/vscode-ibmi)
https://github.com/codefori/vscode-ibmi
 
 
<img src="./icon.png" align="right">

Maintain your RPGLE, CL, COBOL, C/CPP on IBM i right from Visual Studio Code. Edit and compile all ILE languages, view errors inline, content assist for RPGLE and CL, source date support, and much more. Code for IBM i has thousands of daily users and a rapidly increasing number of downloads. We embrace open-source so that we can best support our community.

* [Install original from Marketplace](https://marketplace.visualstudio.com/items?itemName=HalcyonTechLtd.code-for-ibmi) 💻
* [Watch some tutorials](https://www.youtube.com/playlist?list=PLNl31cqBafCp-ml8WqPeriHWLD1bkg7KL) 📺
* [View Codefori documentation](https://codefori.github.io/docs/#/) 📘
* [See previous releases](https://github.com/codefori/vscode-ibmi/releases) 🔎
* Build from source (see below!) 🔨
* [Use our IBM i API in your own extension](https://codefori.github.io/docs/#/pages/api/extending) 🛠

![https://marketplace.visualstudio.com/items?itemName=HalcyonTechLtd.code-for-ibmi](https://img.shields.io/visual-studio-marketplace/v/HalcyonTechLtd.code-for-ibmi?style=flat-square) 
![https://marketplace.visualstudio.com/items?itemName=HalcyonTechLtd.code-for-ibmi](https://img.shields.io/visual-studio-marketplace/i/HalcyonTechLtd.code-for-ibmi?style=flat-square) 
![](https://img.shields.io/visual-studio-marketplace/r/HalcyonTechLtd.code-for-ibmi?style=flat-square) 
![](https://img.shields.io/github/contributors/codefori/vscode-ibmi?style=flat-square) 
![](https://img.shields.io/github/issues-pr/codefori/vscode-ibmi?style=flat-square) 
![https://github.com/codefori/vscode-ibmi/issues](https://img.shields.io/github/issues/codefori/vscode-ibmi?style=flat-square)

---

### Building from source

1. This project requires VS Code and Node.js.
2. fork & clone repo
3. `npm i`
4. 'Run Extension' from vscode debug.

---

* Aldon project filter example 
  <img src="./Aldon-Filter.png" align="left">
* Hawkeye cross reference filter example 
  <img src="./Hawkeye-Filter.png" align="left">
