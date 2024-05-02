export namespace ToolsStrings {
  export function Foundsearch(SearchTokens: String, SearchOver: String): boolean {
    let Words: string[];

    if (SearchTokens == '      ') {return false}
    if (SearchTokens.length == 0) {return false}
    if (SearchOver.length == 0) { return false }

    SearchTokens = SearchTokens.toLocaleUpperCase();
    SearchOver = SearchOver.toLocaleUpperCase();

    Words = SearchTokens.split(' ');
    for (let index = 0; index < Words.length; index++) {
      if (SearchOver.indexOf( Words[index] )==0) {return false}
    }
    
    return true;
  }

}