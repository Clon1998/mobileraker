class ConfigFile {
  ConfigFile();

  ConfigFile.parse(this.rawConfig) {
    //ToDo parse the config for e.g. EXTRUDERS (Temp settings), ...

  }

  Map<String, dynamic> rawConfig = {};

  bool saveConfigPending = false;

  bool get hasQuadGantry => rawConfig.containsKey("quad_gantry_level");

  bool get hasBedMesh => rawConfig.containsKey("bed_mesh");
}
