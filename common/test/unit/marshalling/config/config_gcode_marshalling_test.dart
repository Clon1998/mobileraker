/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConfigGcodeMacro.fromJson() creates ConfigGCode instance from JSON', () {
    const jsonString = '''
    {
    "gcode": "\\n{% set USE_HEATER = (params.USE_HEATER|default(False)) %}\\n{% set EOFFSET = printer['configfile'].config[\\\"probe\\\"][\\\"z_offset\\\"]|float %}\\n{% set TARGET_TEMP = printer.extruder.target %}\\n\\n\\n\\n{% if \\\"xyz\\\" in printer.toolhead.homed_axes %}\\nstatus_cleaning\\n\\nSAVE_GCODE_STATE NAME=clean_nozzle\\nSET_GCODE_OFFSET Z=0\\n\\nG91\\n\\n\\n{% set Ry = printer.configfile.config[\\\"stepper_y\\\"][\\\"position_max\\\"]|float %}\\n{ action_respond_info(\\\"Cleaning purge_spd: %.1f and ret_spd: %.1f use_heater: %s\\\" % (purge_spd * 60, purge_ret_sped * 60, params.USE_HEATER)) }\\n\\n{% if enable_purge %}\\n\\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\\nG90\\nG1 X{bucket_start + (bucket_width / 2)} Y{brush_front + brush_depth} F{prep_spd_xy*60}\\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\\n\\n\\n{% if params.USE_HEATER and printer[\\\"gcode_macro PRINT_START\\\"].target_extruder_tmp >= purge_temp_min %}\\nM109 S{printer[\\\"gcode_macro PRINT_START\\\"].target_extruder_tmp}\\n{% endif %}\\n\\n\\n{% if printer.extruder.temperature >= purge_temp_min %}\\nM83\\nG1 E{purge_len} F{purge_spd * 60}\\nG1 E-{purge_ret} F{purge_ret_sped * 60}\\nG4 P{ooze_dwell * 1000}\\nG92 E0\\n{% endif %}\\n\\n{% endif %}\\n\\n\\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\\nG1 X{brush_start + brush_width} F{prep_spd_xy*60}\\nG1 Y{brush_front + (brush_depth / 2)}\\n\\n\\n\\nG1 Z{brush_top + EOFFSET - 2} F{prep_spd_z*60}\\n\\n\\n{% for wipes in range(1, (wipe_qty + 1)) %}\\nG1 X{brush_start} Y{brush_front} F{wipe_spd_xy*60}\\nG1 X{brush_start + brush_width} Y{brush_front + brush_depth} F{wipe_spd_xy*60}\\n{% endfor %}\\n\\n\\nM117 Cleaned!\\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\\nG1 X{brush_start + brush_width + bucket_width/4} F{prep_spd_xy*60}\\n\\n\\nRESTORE_GCODE_STATE NAME=clean_nozzle\\nstatus_ready\\n{% else %}\\n\\n\\n{ action_raise_error(\\\"Please home your axes!\\") }\\nM117 Please home first!\\n\\n{% endif %}",
    "description": "G-Code macro",
    "variable_location_bucket_rear": "False",
    "variable_enable_purge": "True",
    "variable_purge_len": "20",
    "variable_purge_spd": "8",
    "variable_purge_ret_sped": "20",
    "variable_purge_temp_min": "201",
    "variable_purge_ret": "25",
    "variable_ooze_dwell": "4",
    "variable_brush_top": "8",
    "variable_clearance_z": "15",
    "variable_wipe_qty": "10",
    "variable_prep_spd_xy": "200",
    "variable_prep_spd_z": "25",
    "variable_wipe_spd_xy": "300",
    "variable_brush_start": "228.2",
    "variable_brush_width": "32.5",
    "variable_brush_front": "302",
    "variable_brush_depth": "3",
    "variable_bucket_width": "30",
    "variable_bucket_start": "265"
  }
  ''';

    final jsonMap = json.decode(jsonString);
    final configGcode = ConfigGcodeMacro.fromJson('clean_nozzle', jsonMap);

    expect(configGcode.description, 'G-Code macro');
    expect(configGcode.macroName, 'clean_nozzle');
    expect(configGcode.gcode,
        "\n{% set USE_HEATER = (params.USE_HEATER|default(False)) %}\n{% set EOFFSET = printer['configfile'].config[\"probe\"][\"z_offset\"]|float %}\n{% set TARGET_TEMP = printer.extruder.target %}\n\n\n\n{% if \"xyz\" in printer.toolhead.homed_axes %}\nstatus_cleaning\n\nSAVE_GCODE_STATE NAME=clean_nozzle\nSET_GCODE_OFFSET Z=0\n\nG91\n\n\n{% set Ry = printer.configfile.config[\"stepper_y\"][\"position_max\"]|float %}\n{ action_respond_info(\"Cleaning purge_spd: %.1f and ret_spd: %.1f use_heater: %s\" % (purge_spd * 60, purge_ret_sped * 60, params.USE_HEATER)) }\n\n{% if enable_purge %}\n\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\nG90\nG1 X{bucket_start + (bucket_width / 2)} Y{brush_front + brush_depth} F{prep_spd_xy*60}\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\n\n\n{% if params.USE_HEATER and printer[\"gcode_macro PRINT_START\"].target_extruder_tmp >= purge_temp_min %}\nM109 S{printer[\"gcode_macro PRINT_START\"].target_extruder_tmp}\n{% endif %}\n\n\n{% if printer.extruder.temperature >= purge_temp_min %}\nM83\nG1 E{purge_len} F{purge_spd * 60}\nG1 E-{purge_ret} F{purge_ret_sped * 60}\nG4 P{ooze_dwell * 1000}\nG92 E0\n{% endif %}\n\n{% endif %}\n\n\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\nG1 X{brush_start + brush_width} F{prep_spd_xy*60}\nG1 Y{brush_front + (brush_depth / 2)}\n\n\n\nG1 Z{brush_top + EOFFSET - 2} F{prep_spd_z*60}\n\n\n{% for wipes in range(1, (wipe_qty + 1)) %}\nG1 X{brush_start} Y{brush_front} F{wipe_spd_xy*60}\nG1 X{brush_start + brush_width} Y{brush_front + brush_depth} F{wipe_spd_xy*60}\n{% endfor %}\n\n\nM117 Cleaned!\nG1 Z{brush_top + EOFFSET - 2 + clearance_z} F{prep_spd_z*60}\nG1 X{brush_start + brush_width + bucket_width/4} F{prep_spd_xy*60}\n\n\nRESTORE_GCODE_STATE NAME=clean_nozzle\nstatus_ready\n{% else %}\n\n\n{ action_raise_error(\"Please home your axes!\") }\nM117 Please home first!\n\n{% endif %}");
    expect(configGcode.params.length, 1);
    expect(configGcode.params, contains('USE_HEATER'));
    expect(configGcode.params['USE_HEATER'], '');
  });
}
