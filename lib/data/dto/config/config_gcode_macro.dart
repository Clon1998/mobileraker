final RegExp paramsRegex = RegExp(r'params\.(\w+)(.*)', caseSensitive: false);

final RegExp defaultReg = RegExp(
    "\\|\\s*default\\s*\\(\\s*(([\"'])(?:\\\\.|[^\\2])*\\2|-?[0-9][^,)]*|(?:true|false))",
    caseSensitive: false);

Map<String, String> _parseParams(String gcode) {
  Map<String, String> paramsWithDefaults = {};

  for (RegExpMatch paramMatch in paramsRegex.allMatches(gcode)) {
    String? paramName = paramMatch.group(1);
    if (paramName == null) {
      continue;
    }

    String defaultMatchGrp = paramMatch.group(2) ?? '';
    RegExpMatch? defaultMatch = defaultReg.firstMatch(defaultMatchGrp);

    paramsWithDefaults[paramName] = defaultMatch?.group(1)?.trim() ?? '';
  }
  return paramsWithDefaults;
}

class ConfigGcodeMacro {
  final String macroName;
  final String gcode;
  final String? description;
  final Map<String, String> params;

  ConfigGcodeMacro.parse(this.macroName, Map<String, dynamic> json)
      : gcode = json['gcode'],
        description = json['description'],
        params = _parseParams(json['gcode']);
}
