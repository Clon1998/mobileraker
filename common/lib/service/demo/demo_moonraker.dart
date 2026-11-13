/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

/// A pretend Moonraker + Klipper for the demo printer.
///
/// It answers the JSON-RPC methods the app uses and pushes the same
/// notifications as the real thing, so every real screen (dashboard, files,
/// console, history, power, updates, job queue, Spoolman) runs on it unchanged.
/// Nothing leaves the phone and nothing is persisted: the demo starts fresh with
/// every app start. Object shapes follow real Klipper/Moonraker responses.
library;

import 'dart:async';
import 'dart:math' as math;

import '../../network/json_rpc_client.dart';
import 'demo_gcode.dart';
import 'demo_spoolman.dart';

typedef DemoNotify = void Function(String method, List<dynamic> params);

const _room = 24.0;

/// Number of samples moonraker keeps in its temperature store (20 min at 1 Hz).
const _temperatureStoreSize = 1200;

class DemoMoonraker {
  DemoMoonraker({bool autoTick = true}) {
    _seedTemperatureStore();
    _seedConsole();
    _startPrint('Gridfinity_bins_x4_PLA_2h05m.gcode', progress: 0.3, notifyChanges: false);
    if (autoTick) _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// The demo print runs this many times faster than real time, so visitors see progress move.
  static const speedUp = 8.0;

  final _listeners = <DemoNotify>[];
  Timer? _timer;
  var _disposed = false;
  final _random = math.Random(7);

  // ------------------------------------------------------------ state

  final Map<String, DemoGCodeFile> _gcodes = demoGCodeFiles();
  final Map<String, String> _configs = demoConfigFiles();

  /// Folders below a root, e.g. `gcodes/calibration`.
  final Set<String> _dirs = {'gcodes/calibration'};

  /// Plain files that are no g-code the demo generated: uploads, copies, config edits.
  final Map<String, String> _plain = {};

  final _database = <String, Map<String, dynamic>>{};
  final _console = <Map<String, dynamic>>[];
  late final List<Map<String, dynamic>> _history = _seedHistory();
  final _temperatureStore = <String, Map<String, List<double>>>{};
  final spoolman = DemoSpoolman();
  final _jobQueue = <Map<String, dynamic>>[];
  var _jobQueueState = 'ready';
  var _jobIdCounter = 0x66D99C90;
  var _updateBusy = false;
  final _webcams = <Map<String, dynamic>>[
    {
      'uid': 'b5f5e0b2-demo-4c1e-9b1d-1f4b2a6c9d10',
      'name': 'Demo cam',
      'location': 'printer',
      'service': 'mjpegstreamer-adaptive',
      'enabled': true,
      'icon': 'mdiWebcam',
      'target_fps': 15,
      'target_fps_idle': 5,
      'stream_url': '/webcam/?action=stream',
      'snapshot_url': '/webcam/?action=snapshot',
      'flip_horizontal': false,
      'flip_vertical': false,
      'rotation': 0,
      'aspect_ratio': '16:9',
      'extra_data': <String, dynamic>{},
      'source': 'database',
    },
  ];

  final Map<String, Map<String, dynamic>> _power = {
    'printer': {'device': 'printer', 'status': 'on', 'locked_while_printing': true, 'type': 'gpio'},
    'enclosure_light': {'device': 'enclosure_light', 'status': 'off', 'locked_while_printing': false, 'type': 'tasmota'},
    'air_filter': {'device': 'air_filter', 'status': 'off', 'locked_while_printing': false, 'type': 'shelly'},
  };

  final Map<String, Map<String, dynamic>> _services = {
    for (final name in ['klipper', 'moonraker', 'crowsnest', 'KlipperScreen', 'mobileraker'])
      name: {'active_state': 'active', 'sub_state': 'running'},
  };

  late final Map<String, Map<String, dynamic>> _updaters = {
    'moonraker': _gitRepo('moonraker', 'v0.9.3-12', 'v0.9.3-19', 'Arksine', behind: 7),
    'klipper': _gitRepo('klipper', 'v0.13.0-41', 'v0.13.0-41', 'Klipper3d'),
    'mainsail': {
      'name': 'mainsail',
      'configured_type': 'web',
      'channel': 'stable',
      'owner': 'mainsail-crew',
      'version': 'v2.13.2',
      'remote_version': 'v2.14.0',
      'rollback_version': 'v2.13.1',
      'is_valid': true,
      'info_tags': <String>[],
      'warnings': <String>[],
      'anomalies': <String>[],
    },
    'mobileraker': _gitRepo('mobileraker', 'v0.5.1-0', 'v0.5.1-0', 'Clon1998'),
    'crowsnest': _gitRepo('crowsnest', 'v4.1.9-1', 'v4.1.9-1', 'mainsail-crew'),
    'system': {
      'package_count': 6,
      'package_list': ['libssl3', 'openssl', 'python3', 'python3-minimal', 'libpython3.11', 'tzdata'],
    },
  };

  static const _macros = {
    'LOAD_FILAMENT': 'Heats the nozzle and loads filament',
    'UNLOAD_FILAMENT': 'Heats the nozzle and unloads filament',
    'CLEAN_NOZZLE': 'Wipes the nozzle on the brush',
    'PARK': 'Moves the toolhead out of the way',
    'LIGHTS_TOGGLE': 'Switches the case light',
    'PRINT_START': 'Heats up and prepares a print',
    'PRINT_END': 'Cools down and parks after a print',
  };

  /// Klipper status objects, exactly as `printer.objects.query` returns them.
  final Map<String, Map<String, dynamic>> status = {
    'webhooks': {'state': 'ready', 'state_message': 'Printer is ready'},
    'toolhead': {
      'homed_axes': 'xyz',
      'axis_minimum': [0.0, 0.0, -2.0, 0.0],
      'axis_maximum': [250.0, 250.0, 240.0, 0.0],
      'extruder': 'extruder',
      'position': [125.0, 125.0, 8.4, 0.0],
      'max_velocity': 300.0,
      'max_accel': 6000.0,
      'minimum_cruise_ratio': 0.5,
      'square_corner_velocity': 5.0,
      'print_time': 0.0,
      'estimated_print_time': 0.0,
    },
    'gcode_move': {
      'speed_factor': 1.0,
      'speed': 6000.0,
      'extrude_factor': 1.0,
      'absolute_coordinates': true,
      'absolute_extrude': true,
      'homing_origin': [0.0, 0.0, 0.0, 0.0],
      'position': [125.0, 125.0, 8.4, 0.0],
      'gcode_position': [125.0, 125.0, 8.4, 0.0],
    },
    'motion_report': {
      'live_position': [125.0, 125.0, 8.4, 0.0],
      'live_velocity': 0.0,
      'live_extruder_velocity': 0.0,
    },
    'extruder': {
      'temperature': 215.0,
      'target': 215.0,
      'power': 0.4,
      'can_extrude': true,
      'pressure_advance': 0.04,
      'smooth_time': 0.04,
    },
    'heater_bed': {'temperature': 60.0, 'target': 60.0, 'power': 0.3},
    'fan': {'speed': 0.8, 'rpm': null},
    'fan_generic exhaust_fan': {'speed': 0.0, 'rpm': null},
    'heater_fan hotend_fan': {'speed': 1.0, 'rpm': null},
    'led caselight': {
      'color_data': [
        [0.0, 0.0, 0.0, 1.0],
      ],
    },
    'neopixel status_leds': {
      'color_data': [
        [0.0, 0.6, 1.0, 0.0],
        [0.0, 0.6, 1.0, 0.0],
        [0.0, 0.6, 1.0, 0.0],
      ],
    },
    'temperature_sensor chamber': {'temperature': 38.2, 'measured_min_temp': 22.1, 'measured_max_temp': 41.5},
    'temperature_sensor raspberry_pi': {'temperature': 51.7, 'measured_min_temp': 39.0, 'measured_max_temp': 58.3},
    'filament_switch_sensor runout': {'filament_detected': true, 'enabled': true},
    'firmware_retraction': {
      'retract_length': 0.8,
      'retract_speed': 35.0,
      'unretract_extra_length': 0.0,
      'unretract_speed': 35.0,
    },
    'exclude_object': {'objects': <dynamic>[], 'excluded_objects': <dynamic>[], 'current_object': null},
    'bed_mesh': {
      'profile_name': 'default',
      'mesh_min': [20.0, 20.0],
      'mesh_max': [230.0, 230.0],
      'probed_matrix': _mesh,
      'mesh_matrix': _mesh,
      'profiles': {
        'default': {
          'points': _mesh,
          'mesh_params': {
            'min_x': 20.0,
            'max_x': 230.0,
            'min_y': 20.0,
            'max_y': 230.0,
            'x_count': 5,
            'y_count': 5,
            'mesh_x_pps': 2,
            'mesh_y_pps': 2,
            'algo': 'lagrange',
            'tension': 0.2,
          },
        },
      },
    },
    'print_stats': {
      'filename': '',
      'total_duration': 0.0,
      'print_duration': 0.0,
      'filament_used': 0.0,
      'state': 'standby',
      'message': '',
      'info': {'total_layer': null, 'current_layer': null},
    },
    'virtual_sdcard': {'file_path': null, 'progress': 0.0, 'is_active': false, 'file_position': 0, 'file_size': 0},
    'display_status': {'progress': 0.0, 'message': null},
    'idle_timeout': {'state': 'Printing', 'printing_time': 0.0},
    'pause_resume': {'is_paused': false},
    for (final macro in _macros.keys) 'gcode_macro $macro': <String, dynamic>{},
    'configfile': {
      'save_config_pending': false,
      'save_config_pending_items': <String, dynamic>{},
      'warnings': <dynamic>[],
      'settings': {
        'printer': {
          'kinematics': 'corexy',
          'max_velocity': 300.0,
          'max_accel': 6000.0,
          'max_z_velocity': 15.0,
          'max_z_accel': 300.0,
          'square_corner_velocity': 5.0,
        },
        'extruder': {
          'min_temp': 0.0,
          'max_temp': 290.0,
          'min_extrude_temp': 170.0,
          'nozzle_diameter': 0.4,
          'filament_diameter': 1.75,
          'max_extrude_only_velocity': 60.0,
          'max_extrude_only_accel': 1500.0,
          'max_extrude_only_distance': 200.0,
          'max_extrude_cross_section': 0.64,
          'max_power': 1.0,
          'pressure_advance': 0.04,
          'pressure_advance_smooth_time': 0.04,
          'heater_pin': 'PA2',
          'sensor_pin': 'PF4',
          'sensor_type': 'EPCOS 100K B57560G104F',
          'control': 'pid',
          'step_pin': 'PD5',
          'rotation_distance': 22.6789511,
          'gear_ratio': [
            [50.0, 10.0],
          ],
          'microsteps': 16,
        },
        'heater_bed': {
          'min_temp': 0.0,
          'max_temp': 120.0,
          'max_power': 1.0,
          'heater_pin': 'PA1',
          'sensor_type': 'Generic 3950',
          'control': 'pid',
        },
        'fan': {'max_power': 1.0, 'off_below': 0.0, 'pin': 'PA8', 'kick_start_time': 0.1, 'cycle_time': 0.01},
        'fan_generic exhaust_fan': {'max_power': 1.0, 'off_below': 0.0, 'pin': 'PD12', 'kick_start_time': 0.1, 'cycle_time': 0.01},
        'heater_fan hotend_fan': {
          'max_power': 1.0,
          'pin': 'PE5',
          'heater': ['extruder'],
          'heater_temp': 50.0,
          'fan_speed': 1.0,
          'kick_start_time': 0.1,
          'off_below': 0.0,
          'cycle_time': 0.01,
        },
        'led caselight': {'white_pin': 'PA10', 'cycle_time': 0.01, 'initial_white': 1.0},
        'neopixel status_leds': {'pin': 'PB0', 'chain_count': 3, 'color_order': ['GRB']},
        'temperature_sensor chamber': {'sensor_type': 'Generic 3950', 'min_temp': 0.0, 'max_temp': 100.0},
        'temperature_sensor raspberry_pi': {'sensor_type': 'temperature_host', 'min_temp': 0.0, 'max_temp': 100.0},
        'filament_switch_sensor runout': {'pause_on_runout': true, 'switch_pin': '^PG12'},
        'firmware_retraction': {
          'retract_length': 0.8,
          'retract_speed': 35.0,
          'unretract_extra_length': 0.0,
          'unretract_speed': 35.0,
        },
        'exclude_object': <String, dynamic>{},
        'bed_mesh': {
          'mesh_min': [20.0, 20.0],
          'mesh_max': [230.0, 230.0],
          'probe_count': [5, 5],
        },
        'virtual_sdcard': {'path': '/home/demo/printer_data/gcodes'},
        'pause_resume': <String, dynamic>{},
        'display_status': <String, dynamic>{},
        for (final axis in ['x', 'y'])
          'stepper_$axis': {
            'position_min': 0.0,
            'position_max': 250.0,
            'position_endstop': 250.0,
            'homing_speed': 80.0,
            'second_homing_speed': 40.0,
            'homing_retract_dist': 5.0,
            'rotation_distance': 40.0,
            'microsteps': 32,
            'step_pin': 'PF13',
            'dir_pin': 'PF12',
            'enable_pin': '!PF14',
            'endstop_pin': 'PG6',
            'full_steps_per_rotation': 200,
          },
        'stepper_z': {
          'position_min': -2.0,
          'position_max': 240.0,
          'position_endstop': 0.5,
          'homing_speed': 10.0,
          'second_homing_speed': 3.0,
          'homing_retract_dist': 3.0,
          'rotation_distance': 8.0,
          'microsteps': 32,
          'step_pin': 'PF11',
          'dir_pin': 'PG3',
          'enable_pin': '!PG5',
          'endstop_pin': 'PG10',
          'full_steps_per_rotation': 200,
        },
        for (final MapEntry(key: name, value: description) in _macros.entries)
          'gcode_macro ${name.toLowerCase()}': {
            'gcode': name.contains('FILAMENT') ? '{% set TEMP = params.TEMP|default(220)|float %}\nM109 S{TEMP}' : '',
            'description': description,
          },
      },
    },
  };

  static const _mesh = [
    [0.082, 0.041, 0.012, 0.035, 0.071],
    [0.051, 0.018, -0.011, 0.009, 0.044],
    [0.027, -0.006, -0.031, -0.012, 0.021],
    [0.046, 0.013, -0.015, 0.006, 0.038],
    [0.091, 0.052, 0.019, 0.043, 0.079],
  ];

  // ------------------------------------------------------------ listeners

  void addListener(DemoNotify listener) => _listeners.add(listener);

  void removeListener(DemoNotify listener) => _listeners.remove(listener);

  void notify(String method, List<dynamic> params) {
    if (_disposed) return;
    for (final l in List.of(_listeners)) {
      l(method, params);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _listeners.clear();
  }

  // ------------------------------------------------------------ RPC

  /// Answers a JSON-RPC call with the raw `result` moonraker would send. Throws [JRpcError] like a real server.
  Future<dynamic> call(String method, [dynamic params]) async {
    final p = params is Map ? params.cast<String, dynamic>() : const <String, dynamic>{};
    switch (method) {
      case 'server.connection.identify':
        return {'connection_id': 1};
      case 'server.info':
        return {
          'klippy_connected': true,
          'klippy_state': 'ready',
          'components': [
            'database',
            'file_manager',
            'klippy_apis',
            'machine',
            'data_store',
            'history',
            'webcam',
            'power',
            'update_manager',
            'job_queue',
            'spoolman',
            'announcements',
          ],
          'failed_components': <String>[],
          'registered_directories': ['gcodes', 'config', 'logs'],
          'warnings': <dynamic>[],
          'websocket_count': 2,
          'moonraker_version': 'v0.9.3-12-gdemo',
          'missing_klippy_requirements': <String>[],
          'api_version': [1, 5, 0],
          'api_version_string': '1.5.0',
        };
      case 'printer.info':
        return {
          'state': 'ready',
          'state_message': 'Printer is ready',
          'hostname': 'demo-printer',
          'klipper_path': '/home/demo/klipper',
          'python_path': '/home/demo/klippy-env/bin/python',
          'log_file': '/home/demo/printer_data/logs/klippy.log',
          'config_file': '/home/demo/printer_data/config/printer.cfg',
          'software_version': 'v0.13.0-41-gdemo',
          'cpu_info': '4 core ARMv8 Processor rev 3 (v8l)',
        };
      case 'printer.objects.list':
        return {'objects': status.keys.toList()};
      case 'printer.objects.query' || 'printer.objects.subscribe':
        final wanted = (p['objects'] as Map?)?.keys ?? status.keys;
        return {
          'eventtime': _now,
          'status': {
            for (final key in wanted)
              if (status.containsKey(key)) key: _copy(status[key]!),
          },
        };
      case 'printer.gcode.script':
        _runScript('${p['script']}');
        return 'ok';
      case 'printer.gcode.help':
        return {
          for (final MapEntry(key: name, value: description) in _macros.entries) name: description,
          'G28': 'Home the printer',
          'M104': 'Set the nozzle temperature',
          'M140': 'Set the bed temperature',
          'M106': 'Set the part cooling fan',
          'SET_HEATER_TEMPERATURE': 'Sets a heater temperature',
          'SET_GCODE_OFFSET': 'Set a virtual offset to g-code positions',
          'SET_LED': 'Set the color of an LED',
          'EXCLUDE_OBJECT': 'Cancel moves inside a specified object',
          'BED_MESH_CALIBRATE': 'Perform Mesh Bed Leveling',
          'FIRMWARE_RESTART': 'Restart firmware, host, and reload config',
        };
      case 'printer.print.pause':
        _setPrintState('paused');
        return 'ok';
      case 'printer.print.resume':
        _setPrintState('printing');
        return 'ok';
      case 'printer.print.cancel':
        _finish('cancelled');
        return 'ok';
      case 'printer.print.start':
        _startPrint('${p['filename']}');
        return 'ok';
      case 'printer.emergency_stop' || 'printer.firmware_restart' || 'printer.restart':
        // The demo printer shrugs these off and stays ready.
        _respond('// Demo printer: nothing was restarted');
        return 'ok';
      case 'machine.reboot' || 'machine.shutdown':
        _respond('// Demo printer: the host keeps running');
        return 'ok';
      case 'machine.services.restart' || 'machine.services.start' || 'machine.services.stop':
        final service = '${p['service']}';
        if (!_services.containsKey(service)) throw JRpcError(400, 'Invalid argument');
        _setService(service, method.endsWith('stop') ? ('inactive', 'dead') : ('active', 'running'));
        return 'ok';
      case 'machine.system_info':
        return {
          'system_info': {
            'provider': 'systemd_dbus',
            'cpu_info': {
              'cpu_count': 4,
              'bits': '64bit',
              'processor': 'aarch64',
              'cpu_desc': 'Raspberry Pi 4 Model B Rev 1.4',
              'serial_number': 'demo',
              'hardware_desc': 'BCM2835',
              'model': 'Raspberry Pi 4 Model B Rev 1.4',
              'total_memory': 3884096,
              'memory_units': 'kB',
            },
            'sd_info': <String, dynamic>{},
            'distribution': {'name': 'Debian GNU/Linux 12 (bookworm)', 'id': 'debian', 'version': '12'},
            'available_services': _services.keys.toList(),
            'service_state': _copy(_services),
            'virtualization': {'virt_type': 'none', 'virt_identifier': 'none'},
            'python': {
              'version': [3, 11, 2, 'final', 0],
              'version_string': '3.11.2',
            },
            'network': <String, dynamic>{},
            'canbus': <String, dynamic>{},
          },
        };
      case 'machine.proc_stats':
        return {
          'moonraker_stats': <dynamic>[],
          'throttled_state': {'bits': 0, 'flags': <String>[]},
          'cpu_temp': status['temperature_sensor raspberry_pi']!['temperature'],
          'network': <String, dynamic>{},
          'system_cpu_usage': {'cpu': 12.3},
          'system_memory': {'total': 3884096, 'available': 2914000, 'used': 970096},
          'websocket_connections': 2,
        };
      case 'machine.sudo.info':
        return {'sudo_access': true, 'linux_user': 'demo', 'sudo_requested': false, 'request_messages': <String>[]};
      case 'machine.sudo.password':
        return {'sudo_responses': <String>[], 'is_restarting': false};
      case 'server.gcode_store':
        final count = int.tryParse('${p['count'] ?? 100}') ?? 100;
        return {'gcode_store': _console.reversed.take(count).toList().reversed.toList()};
      case 'server.temperature_store':
        return _copy(_temperatureStore);
      case 'server.history.list':
        final start = int.tryParse('${p['start'] ?? 0}') ?? 0;
        final limit = int.tryParse('${p['limit'] ?? 50}') ?? 50;
        final jobs = p['order'] == 'asc' ? _history.reversed.toList() : _history;
        return {'count': _history.length, 'jobs': jobs.skip(start).take(limit).map(_copy).toList()};
      case 'server.history.get_job':
        final job = _history.where((j) => j['job_id'] == p['uid']).firstOrNull;
        if (job == null) throw JRpcError(404, 'Invalid job uid: ${p['uid']}');
        return {'job': _copy(job)};
      case 'server.history.totals':
        final done = _history.where((j) => j['status'] != 'in_progress');
        return {
          'job_totals': {
            'total_jobs': 37.0 + _history.length,
            'total_time': 412000.0 + done.fold(0.0, (s, j) => s + (j['total_duration'] as num)),
            'total_print_time': 388000.0 + done.fold(0.0, (s, j) => s + (j['print_duration'] as num)),
            'total_filament_used': 291000.0 + done.fold(0.0, (s, j) => s + (j['filament_used'] as num)),
            'longest_job': 21600.0,
            'longest_print': 20950.0,
          },
          'auxiliary_totals': <dynamic>[],
        };
      case 'server.history.delete_job':
        final deleted = [
          for (final j in _history)
            if (p['all'] == true || j['job_id'] == p['uid']) j['job_id'],
        ];
        _history.removeWhere((j) => deleted.contains(j['job_id']) && j['status'] != 'in_progress');
        for (final id in deleted) {
          notify('notify_history_changed', [
            {
              'action': 'deleted',
              'job': {'job_id': id},
            },
          ]);
        }
        return {'deleted_jobs': deleted};
      case 'server.files.roots':
        return [
          {'name': 'gcodes', 'path': '/home/demo/printer_data/gcodes', 'permissions': 'rw'},
          {'name': 'config', 'path': '/home/demo/printer_data/config', 'permissions': 'rw'},
          {'name': 'logs', 'path': '/home/demo/printer_data/logs', 'permissions': 'r'},
        ];
      case 'server.files.get_directory':
        return _directory('${p['path'] ?? 'gcodes'}', extended: p['extended'] == true);
      case 'server.files.list':
        final root = '${p['root'] ?? 'gcodes'}';
        return [
          for (final path in _allFiles())
            if (path.startsWith('$root/'))
              {
                'path': path.substring(root.length + 1),
                'modified': _modified(path),
                'size': _size(path),
                'permissions': 'rw',
              },
        ];
      case 'server.files.metadata':
        final name = '${p['filename']}';
        final file = _gcodes[name];
        if (file == null) {
          if (_plain.containsKey('gcodes/$name')) {
            return {'filename': name, 'size': _size('gcodes/$name'), 'modified': _modified('gcodes/$name')};
          }
          throw JRpcError(404, 'Metadata not available for <$name>');
        }
        final lastJob = _history.where((j) => j['filename'] == name).firstOrNull;
        return {
          ...file.metadata(_now),
          'filename': name,
          if (lastJob != null) 'print_start_time': lastJob['start_time'],
          if (lastJob != null) 'job_id': lastJob['job_id'],
        };
      case 'server.files.delete_file':
        return _deleteFile('${p['path']}');
      case 'server.files.post_directory':
        return _createDir('${p['path']}');
      case 'server.files.delete_directory':
        return _deleteDir('${p['path']}', force: p['force'] == true);
      case 'server.files.move' || 'server.files.copy':
        return _moveOrCopy('${p['source']}', '${p['dest']}', copy: method.endsWith('copy'));
      case 'server.files.zip':
        throw JRpcError(400, 'The demo printer cannot create archives');
      case 'server.webcams.list':
        return {'webcams': _copyList(_webcams)};
      case 'server.webcams.get_item':
        final cam = _webcams.where((c) => c['uid'] == p['uid'] || c['name'] == p['name']).firstOrNull;
        if (cam == null) throw JRpcError(404, 'Webcam not found');
        return {'webcam': _copy(cam)};
      case 'server.webcams.post_item':
        final existing = _webcams.where((c) => p['uid'] != null && c['uid'] == p['uid']).firstOrNull;
        final cam = {...?existing, ...p, 'uid': p['uid'] ?? 'demo-cam-${_webcams.length + 1}', 'source': 'database'};
        if (existing != null) _webcams.remove(existing);
        _webcams.add(cam);
        notify('notify_webcams_changed', [
          {'webcams': _copyList(_webcams)},
        ]);
        return {'webcam': _copy(cam)};
      case 'server.webcams.delete_item':
        final cam = _webcams.where((c) => c['uid'] == p['uid'] || c['name'] == p['name']).firstOrNull;
        if (cam == null) throw JRpcError(404, 'Webcam not found');
        _webcams.remove(cam);
        notify('notify_webcams_changed', [
          {'webcams': _copyList(_webcams)},
        ]);
        return {'webcam': _copy(cam)};
      case 'server.announcements.list':
        return {'entries': <dynamic>[], 'feeds': ['moonraker', 'klipper']};
      case 'server.announcements.dismiss':
        return {'entry_id': p['entry_id']};
      case 'server.database.list':
        return {'namespaces': _database.keys.toList(), 'backups': <String>[]};
      case 'server.database.get_item':
        return _dbGet('${p['namespace']}', p['key']?.toString());
      case 'server.database.post_item':
        return _dbPost('${p['namespace']}', '${p['key']}', p['value']);
      case 'server.database.delete_item':
        return _dbDelete('${p['namespace']}', '${p['key']}');
      case 'machine.device_power.devices':
        return {'devices': _copyList(_power.values.toList())};
      case 'machine.device_power.get_device':
        final device = _power['${p['device']}'];
        if (device == null) throw JRpcError(404, 'No valid device named ${p['device']}');
        return {device['device']: device['status']};
      case 'machine.device_power.post_device':
        return _postPower('${p['device']}', '${p['action']}');
      case 'machine.update.status' || 'machine.update.refresh':
        return _updateStatus();
      case 'machine.update.upgrade':
        final name = p['name']?.toString();
        _runUpdate(name == null ? _outdatedUpdaters() : [name], 'upgrade');
        return 'ok';
      case 'machine.update.recover':
        _runUpdate(['${p['name']}'], 'recover');
        return 'ok';
      case 'machine.update.rollback':
        _runUpdate(['${p['name']}'], 'rollback');
        return 'ok';
      case 'server.job_queue.status':
        return _jobQueueStatus();
      case 'server.job_queue.post_job':
        final names = (p['filenames'] as List? ?? [p['filename']]).whereType<String>();
        if (p['reset'] == true) _jobQueue.clear();
        for (final name in names) {
          _jobQueue.add({
            'filename': name,
            'job_id': (_jobIdCounter++).toRadixString(16).toUpperCase().padLeft(16, '0'),
            'time_added': _now,
            'time_in_queue': 0.0,
          });
        }
        _notifyJobQueue('jobs_added');
        return _jobQueueStatus();
      case 'server.job_queue.delete_job':
        if (p['all'] == true) {
          _jobQueue.clear();
        } else {
          final ids = (p['job_ids'] as List? ?? const []).map((e) => '$e').toSet();
          _jobQueue.removeWhere((j) => ids.contains(j['job_id']));
        }
        _notifyJobQueue('jobs_removed');
        return _jobQueueStatus();
      case 'server.job_queue.pause':
        _jobQueueState = 'paused';
        _notifyJobQueue('state_changed', withQueue: false);
        return _jobQueueStatus();
      case 'server.job_queue.start':
        _jobQueueState = 'ready';
        _notifyJobQueue('state_changed', withQueue: false);
        if (_job == null) _loadNextQueuedJob();
        return _jobQueueStatus();
      case 'server.spoolman.get_spool_id':
        return {'spool_id': spoolman.activeSpoolId};
      case 'server.spoolman.post_spool_id':
        spoolman.activeSpoolId = (p['spool_id'] as num?)?.toInt();
        notify('notify_active_spool_set', [
          {'spool_id': spoolman.activeSpoolId},
        ]);
        return {'spool_id': spoolman.activeSpoolId};
      case 'server.spoolman.status':
        return {'spoolman_connected': true, 'pending_reports': <dynamic>[], 'spool_id': spoolman.activeSpoolId};
      case 'server.spoolman.proxy':
        return spoolman.proxy(p);
      default:
        throw JRpcError(-32601, 'Method not found');
    }
  }

  // ------------------------------------------------------------ files

  /// Content of a file for HTTP downloads, null if there is none.
  String? fileContent(String path) {
    if (_plain[path] case final content?) return content;
    if (path.startsWith('gcodes/')) return _gcodes[path.substring(7)]?.content;
    if (path.startsWith('config/')) return _configs[path.substring(7)];
    if (path.startsWith('logs/')) return _console.map((e) => e['message']).join('\n');
    return null;
  }

  /// Stores an uploaded file, like `POST /server/files/upload`.
  Map<String, dynamic> upload(String root, String path, String content) {
    final full = '$root/$path';
    final existed = fileContent(full) != null;
    if (root == 'gcodes') _gcodes.remove(path);
    if (root == 'config') _configs.remove(path);
    _plain[full] = content;
    final item = _item(full);
    notify('notify_filelist_changed', [
      {'action': existed ? 'modify_file' : 'create_file', 'item': item},
    ]);
    return {'item': item, 'print_started': false, 'print_queued': false, 'action': 'create_file'};
  }

  Iterable<String> _allFiles() sync* {
    for (final name in _gcodes.keys) {
      yield 'gcodes/$name';
    }
    for (final name in _configs.keys) {
      yield 'config/$name';
    }
    yield* _plain.keys;
    yield 'logs/klippy.log';
    yield 'logs/moonraker.log';
  }

  double _modified(String path) {
    if (path.startsWith('gcodes/')) {
      final file = _gcodes[path.substring(7)];
      if (file != null) return _now - file.ageHours * 3600;
    }
    return _startTime - 86400 * 2;
  }

  int _size(String path) => fileContent(path)?.length ?? 0;

  Map<String, dynamic> _item(String full) {
    final root = full.split('/').first;
    return {
      'path': full.substring(root.length + 1),
      'root': root,
      'size': _size(full),
      'modified': _modified(full),
      'permissions': 'rw',
    };
  }

  Map<String, dynamic> _directory(String path, {bool extended = false}) {
    final dir = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final root = dir.split('/').first;
    if (dir != root && !_dirs.contains(dir)) throw JRpcError(404, 'Directory does not exist ($dir)');
    String? directChild(String full) {
      if (!full.startsWith('$dir/')) return null;
      final rest = full.substring(dir.length + 1);
      return rest.contains('/') ? null : rest;
    }

    return {
      'dirs': [
        for (final d in _dirs)
          if (directChild(d) case final name?)
            {'dirname': name, 'modified': _startTime - 86400 * 9, 'size': 4096, 'permissions': 'rw'},
      ],
      'files': [
        for (final f in _allFiles())
          if (directChild(f) case final name?)
            {
              if (extended && f.startsWith('gcodes/') && _gcodes[f.substring(7)] != null)
                ..._gcodes[f.substring(7)]!.metadata(_now),
              'filename': name,
              'modified': _modified(f),
              'size': _size(f),
              'permissions': root == 'logs' ? 'r' : 'rw',
            },
      ],
      'disk_usage': {'total': 31000000000, 'used': 9000000000, 'free': 22000000000},
      'root_info': {'name': root, 'permissions': root == 'logs' ? 'r' : 'rw'},
    };
  }

  void _guardWritable(String full) {
    if (full.startsWith('logs/')) throw JRpcError(403, 'Root logs is read-only');
    final printing = status['print_stats']!['filename'];
    if (_job != null && full == 'gcodes/$printing') throw JRpcError(403, 'File is loaded, DELETE not permitted');
  }

  Map<String, dynamic> _deleteFile(String full) {
    _guardWritable(full);
    final item = _item(full);
    final removed = _plain.remove(full) != null ||
        (full.startsWith('gcodes/') && _gcodes.remove(full.substring(7)) != null) ||
        (full.startsWith('config/') && _configs.remove(full.substring(7)) != null);
    if (!removed) throw JRpcError(404, 'File does not exist ($full)');
    for (final j in _history) {
      if ('gcodes/${j['filename']}' == full) j['exists'] = false;
    }
    notify('notify_filelist_changed', [
      {'action': 'delete_file', 'item': item},
    ]);
    return {'item': item, 'action': 'delete_file'};
  }

  Map<String, dynamic> _createDir(String full) {
    if (_dirs.contains(full)) throw JRpcError(400, 'Directory already exists ($full)');
    _guardWritable(full);
    _dirs.add(full);
    final item = {..._item(full), 'size': 4096};
    notify('notify_filelist_changed', [
      {'action': 'create_dir', 'item': item},
    ]);
    return {'item': item, 'action': 'create_dir'};
  }

  Map<String, dynamic> _deleteDir(String full, {required bool force}) {
    if (!_dirs.contains(full)) throw JRpcError(404, 'Directory does not exist ($full)');
    final content = [..._allFiles(), ..._dirs].where((p) => p.startsWith('$full/')).toList();
    if (content.isNotEmpty && !force) throw JRpcError(403, 'Directory contains files, use force to delete');
    for (final path in content) {
      _dirs.remove(path);
      if (fileContent(path) != null) _deleteFile(path);
    }
    _dirs.remove(full);
    final item = {..._item(full), 'size': 4096};
    notify('notify_filelist_changed', [
      {'action': 'delete_dir', 'item': item},
    ]);
    return {'item': item, 'action': 'delete_dir'};
  }

  Map<String, dynamic> _moveOrCopy(String source, String dest, {required bool copy}) {
    if (!copy) _guardWritable(source);
    if (dest.startsWith('logs/')) throw JRpcError(403, 'Root logs is read-only');
    final isDir = _dirs.contains(source);
    if (!isDir && fileContent(source) == null) throw JRpcError(404, 'File does not exist ($source)');
    // Moving into a folder keeps the name.
    if (_dirs.contains(dest) || dest == 'gcodes' || dest == 'config') dest = '$dest/${source.split('/').last}';

    final moves = isDir
        ? {
            source: dest,
            for (final p in [..._allFiles(), ..._dirs])
              if (p.startsWith('$source/')) p: '$dest${p.substring(source.length)}',
          }
        : {source: dest};
    for (final MapEntry(key: from, value: to) in moves.entries) {
      if (_dirs.contains(from)) {
        _dirs.add(to);
        if (!copy) _dirs.remove(from);
        continue;
      }
      final gcode = from.startsWith('gcodes/') ? _gcodes[from.substring(7)] : null;
      if (gcode != null && to.startsWith('gcodes/')) {
        _gcodes[to.substring(7)] = gcode;
      } else {
        _plain[to] = fileContent(from)!;
      }
      if (!copy) {
        _plain.remove(from);
        if (from.startsWith('gcodes/')) _gcodes.remove(from.substring(7));
        if (from.startsWith('config/')) _configs.remove(from.substring(7));
      }
    }
    final action = '${copy ? 'create' : 'move'}_${isDir ? 'dir' : 'file'}';
    final response = {
      'item': _item(dest),
      if (!copy) 'source_item': {'path': source.substring(source.indexOf('/') + 1), 'root': source.split('/').first},
      'action': action,
    };
    notify('notify_filelist_changed', [response]);
    return response;
  }

  // ------------------------------------------------------------ database

  dynamic _dbGet(String namespace, String? key) {
    final ns = _database[namespace];
    if (ns == null) throw JRpcError(404, "Namespace '$namespace' not found");
    if (key == null) return {'namespace': namespace, 'key': null, 'value': _copy(ns)};
    dynamic value = ns;
    for (final part in key.split('.')) {
      if (value is! Map || !value.containsKey(part)) {
        throw JRpcError(404, "Key '$key' in namespace '$namespace' not found");
      }
      value = value[part];
    }
    return {'namespace': namespace, 'key': key, 'value': value};
  }

  dynamic _dbPost(String namespace, String key, dynamic value) {
    Map<String, dynamic> target = _database.putIfAbsent(namespace, () => {});
    final parts = key.split('.');
    for (final part in parts.take(parts.length - 1)) {
      target = (target[part] is Map ? target[part] : (target[part] = <String, dynamic>{})) as Map<String, dynamic>;
    }
    target[parts.last] = value;
    return {'namespace': namespace, 'key': key, 'value': value};
  }

  dynamic _dbDelete(String namespace, String key) {
    final current = _dbGet(namespace, key);
    Map<String, dynamic> target = _database[namespace]!;
    final parts = key.split('.');
    for (final part in parts.take(parts.length - 1)) {
      target = target[part] as Map<String, dynamic>;
    }
    target.remove(parts.last);
    return current;
  }

  // ------------------------------------------------------------ power, services, updates, job queue

  Map<String, dynamic> _postPower(String name, String action) {
    final device = _power[name];
    if (device == null) throw JRpcError(404, 'No valid device named $name');
    if (device['locked_while_printing'] == true && _job != null) {
      throw JRpcError(400, 'Unable to change power for $name while printing');
    }
    device['status'] = switch (action) {
      'on' => 'on',
      'off' => 'off',
      _ => device['status'] == 'on' ? 'off' : 'on',
    };
    notify('notify_power_changed', [_copy(device)]);
    return {name: device['status']};
  }

  void _setService(String name, (String, String) state) {
    _services[name] = {'active_state': state.$1, 'sub_state': state.$2};
    notify('notify_service_state_changed', [
      {name: _copy(_services[name]!)},
    ]);
  }

  Map<String, dynamic> _gitRepo(String name, String version, String remote, String owner, {int behind = 0}) => {
        'name': name,
        'configured_type': 'git_repo',
        'channel': 'dev',
        'detected_type': 'git_repo',
        'remote_alias': 'origin',
        'branch': 'master',
        'owner': owner,
        'repo_name': name,
        'version': version,
        'remote_version': remote,
        'rollback_version': version,
        'full_version_string': '$version-gdemo',
        'current_hash': 'a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0',
        'remote_hash': behind > 0 ? 'f0e1d2c3b4a5f6e7d8c9b0a1f2e3d4c5b6a7f8e9' : 'a1b2c3d4e5f6a7b8c9d0a1b2c3d4e5f6a7b8c9d0',
        'is_valid': true,
        'corrupt': false,
        'is_dirty': false,
        'detached': false,
        'debug_enabled': false,
        'pristine': true,
        'commits_behind_count': behind,
        'commits_behind': [
          for (var i = 0; i < behind; i++)
            {
              'sha': 'f0e1d2c3b4a5f6e7d8c9b0a1f2e3d4c5b6a7f8e$i',
              'author': ['Arksine', 'Eric Callahan', 'Pedro Lamas'][i % 3],
              'date': '${(_startTime - 86400 * (i + 1)).round()}',
              'subject': [
                'file_manager: improve metadata extraction',
                'history: report auxiliary fields',
                'update_manager: faster refresh',
                'docs: update changelog',
                'webcam: validate stream urls',
                'power: support new tasmota firmware',
                'spoolman: retry pending reports',
              ][i % 7],
              'message': 'Signed-off-by: Demo <demo@mobileraker.com>',
              'tag': null,
            },
        ],
        'git_messages': <String>[],
        'info_tags': <String>[],
        'warnings': <String>[],
        'anomalies': <String>[],
      };

  List<String> _outdatedUpdaters() => [
        for (final MapEntry(:key, :value) in _updaters.entries)
          if ((key == 'system' && (value['package_count'] as int) > 0) ||
              (value['version'] != null && value['version'] != value['remote_version']))
            key,
      ];

  Map<String, dynamic> _updateStatus() => {
        'busy': _updateBusy,
        'github_rate_limit': 60,
        'github_requests_remaining': 57,
        'github_limit_reset_time': (_now + 3000).round(),
        'version_info': _copy(_updaters),
      };

  void _runUpdate(List<String> names, String action) {
    if (_updateBusy) throw JRpcError(400, 'Update already in progress');
    _updateBusy = true;
    () async {
      for (final name in names) {
        final updater = _updaters[name];
        if (updater == null) continue;
        final lines = switch ((name, action)) {
          ('system', _) => ['Updating packages...', 'Reading package lists...', 'Unpacking ${updater['package_count']} packages...', 'Setting up packages...'],
          (_, 'recover') => ['Recovering $name...', 'Resetting git repo...', 'Reinstalling dependencies...'],
          (_, 'rollback') => ['Rolling back $name to ${updater['rollback_version']}...', 'Checking out version...'],
          _ => ['Updating $name...', 'Fetching ${updater['remote_version']}...', 'Installing...', 'Restarting service...'],
        };
        for (final line in lines) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (_disposed) return;
          notify('notify_update_response', [
            {'application': name, 'proc_id': 4242, 'message': line, 'complete': false},
          ]);
        }
        if (name == 'system') {
          updater
            ..['package_count'] = 0
            ..['package_list'] = <String>[];
        } else if (action == 'rollback') {
          updater['version'] = updater['rollback_version'];
        } else if (action == 'upgrade') {
          updater
            ..['rollback_version'] = updater['version']
            ..['version'] = updater['remote_version']
            ..['commits_behind'] = <dynamic>[]
            ..['commits_behind_count'] = 0
            ..['current_hash'] = updater['remote_hash'];
        }
        notify('notify_update_response', [
          {'application': name, 'proc_id': 4242, 'message': 'Update of $name complete', 'complete': names.last == name},
        ]);
      }
      _updateBusy = false;
      notify('notify_update_refreshed', [_updateStatus()]);
    }();
  }

  Map<String, dynamic> _jobQueueStatus() => {
        'queued_jobs': [
          for (final j in _jobQueue) {...j, 'time_in_queue': _now - (j['time_added'] as num)},
        ],
        'queue_state': _jobQueueState,
      };

  void _notifyJobQueue(String action, {bool withQueue = true}) {
    notify('notify_job_queue_changed', [
      {
        'action': action,
        'updated_queue': withQueue ? _jobQueueStatus()['queued_jobs'] : null,
        'queue_state': _jobQueueState,
      },
    ]);
  }

  void _loadNextQueuedJob() {
    if (_jobQueueState != 'ready' || _jobQueue.isEmpty) return;
    final next = _jobQueue.removeAt(0);
    _notifyJobQueue('job_loaded');
    _startPrint(next['filename'] as String);
  }

  // ------------------------------------------------------------ G-code

  static final _arg = RegExp(r'([A-Z_]+)=("[^"]*"|\S+)', caseSensitive: false);
  static final _word = RegExp(r'\b([A-Z])(-?\d+\.?\d*)');

  void _runScript(String script) {
    _console.add({'message': script, 'time': _now, 'type': 'command'});
    for (final raw in script.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      final cmd = upper.split(RegExp(r'\s+')).first;
      final args = {for (final m in _arg.allMatches(line)) m.group(1)!.toUpperCase(): m.group(2)!.replaceAll('"', '')};
      final words = {
        for (final m in _word.allMatches(upper.substring(cmd.length))) m.group(1)!: double.parse(m.group(2)!),
      };
      double? num(String key) => double.tryParse(args[key] ?? '');

      switch (cmd) {
        case 'M104' || 'M109':
          _set('extruder', {'target': words['S'] ?? 0.0});
        case 'M140' || 'M190':
          _set('heater_bed', {'target': words['S'] ?? 0.0});
        case 'SET_HEATER_TEMPERATURE':
          final heater = (args['HEATER'] ?? 'extruder').toLowerCase();
          if (status.containsKey(heater)) _set(heater, {'target': num('TARGET') ?? 0.0});
        case 'TURN_OFF_HEATERS':
          _set('extruder', {'target': 0.0});
          _set('heater_bed', {'target': 0.0});
        case 'M106':
          _set('fan', {'speed': ((words['S'] ?? 255) / 255).clamp(0.0, 1.0)});
        case 'M107':
          _set('fan', {'speed': 0.0});
        case 'SET_FAN_SPEED':
          final fan = 'fan_generic ${args['FAN']?.toLowerCase()}';
          if (status.containsKey(fan)) _set(fan, {'speed': (num('SPEED') ?? 0).clamp(0.0, 1.0)});
        case 'SET_LED':
          final name = args['LED']?.toLowerCase();
          final led = status.keys.where((k) => k.endsWith(' $name') && k.split(' ').length == 2).firstOrNull;
          if (led != null) {
            final count = (status[led]!['color_data'] as List).length;
            final index = int.tryParse(args['INDEX'] ?? '');
            final color = [num('RED') ?? 0.0, num('GREEN') ?? 0.0, num('BLUE') ?? 0.0, num('WHITE') ?? 0.0];
            final current = _copyList(status[led]!['color_data'] as List);
            _set(led, {
              'color_data': [
                for (var i = 0; i < count; i++) index == null || index - 1 == i ? color : current[i],
              ],
            });
          }
        case 'SET_FILAMENT_SENSOR':
          final sensor = 'filament_switch_sensor ${args['SENSOR']?.toLowerCase()}';
          if (status.containsKey(sensor)) _set(sensor, {'enabled': args['ENABLE'] == '1'});
        case 'SET_GCODE_OFFSET':
          final origin = List<double>.from(status['gcode_move']!['homing_origin'] as List);
          if (num('Z_ADJUST') case final d?) origin[2] = double.parse((origin[2] + d).toStringAsFixed(4));
          if (num('Z') case final z?) origin[2] = z;
          _set('gcode_move', {'homing_origin': origin});
        case 'M220':
          _set('gcode_move', {'speed_factor': (words['S'] ?? 100) / 100});
        case 'M221':
          _set('gcode_move', {'extrude_factor': (words['S'] ?? 100) / 100});
        case 'SET_PRESSURE_ADVANCE':
          _set('extruder', {
            'pressure_advance': ?num('ADVANCE'),
            'smooth_time': ?num('SMOOTH_TIME'),
          });
        case 'SET_VELOCITY_LIMIT':
          _set('toolhead', {
            'max_velocity': ?num('VELOCITY'),
            'max_accel': ?num('ACCEL'),
            'square_corner_velocity': ?num('SQUARE_CORNER_VELOCITY'),
            'minimum_cruise_ratio': ?num('MINIMUM_CRUISE_RATIO'),
          });
        case 'SET_RETRACTION':
          _set('firmware_retraction', {
            'retract_length': ?num('RETRACT_LENGTH'),
            'retract_speed': ?num('RETRACT_SPEED'),
            'unretract_extra_length': ?num('UNRETRACT_EXTRA_LENGTH'),
            'unretract_speed': ?num('UNRETRACT_SPEED'),
          });
        case 'EXCLUDE_OBJECT':
          final name = args['NAME'];
          if (name != null) {
            final excluded = List<dynamic>.from(status['exclude_object']!['excluded_objects'] as List);
            if (!excluded.contains(name)) excluded.add(name);
            _set('exclude_object', {'excluded_objects': excluded});
            _respond('// Excluding object $name');
          }
        case 'BED_MESH_CALIBRATE':
          final mesh = [
            for (final row in _mesh) [for (final v in row) double.parse((v + (_random.nextDouble() - 0.5) * 0.01).toStringAsFixed(3))],
          ];
          final profiles = _copy(status['bed_mesh']!['profiles'] as Map<String, dynamic>);
          (profiles['default'] as Map)['points'] = mesh;
          _set('bed_mesh', {'profile_name': 'default', 'probed_matrix': mesh, 'mesh_matrix': mesh, 'profiles': profiles});
          _respond('// Mesh Bed Leveling Complete');
        case 'BED_MESH_CLEAR':
          _set('bed_mesh', {'profile_name': '', 'probed_matrix': <dynamic>[], 'mesh_matrix': <dynamic>[]});
        case 'BED_MESH_PROFILE':
          final load = args['LOAD'];
          final profiles = status['bed_mesh']!['profiles'] as Map;
          if (load != null && profiles[load] is Map) {
            final points = (profiles[load] as Map)['points'];
            _set('bed_mesh', {'profile_name': load, 'probed_matrix': points, 'mesh_matrix': points});
          }
        case 'G28':
          _set('toolhead', {'homed_axes': 'xyz'});
          _moveTo([125.0, 125.0, 10.0]);
        case 'M84' || 'M18':
          _set('toolhead', {'homed_axes': ''});
        case 'G90':
          _relative = false;
        case 'G91':
          _relative = true;
        case 'G0' || 'G1':
          final pos = List<double>.from(status['gcode_move']!['gcode_position'] as List);
          for (final (i, axis) in ['X', 'Y', 'Z'].indexed) {
            if (words[axis] case final v?) pos[i] = (_relative ? pos[i] + v : v).clamp(0.0, 250.0);
          }
          _moveTo(pos);
        case 'SDCARD_PRINT_FILE':
          _startPrint(args['FILENAME'] ?? '');
        case 'SDCARD_RESET_FILE':
          _set('print_stats', {'state': 'standby', 'filename': '', 'print_duration': 0.0, 'filament_used': 0.0});
          _set('virtual_sdcard', {'progress': 0.0, 'is_active': false, 'file_position': 0});
          _set('display_status', {'progress': 0.0, 'message': null});
        case 'M117':
          final text = line.length > 4 ? line.substring(4).trim() : '';
          _set('display_status', {'message': text.isEmpty ? null : text});
        case 'LIGHTS_TOGGLE':
          final on = ((status['led caselight']!['color_data'] as List).first as List).any((c) => c > 0);
          _runLine('SET_LED LED=caselight WHITE=${on ? 0 : 1}');
        case 'PAUSE':
          _setPrintState('paused');
        case 'RESUME':
          _setPrintState('printing');
        case 'CANCEL_PRINT':
          _finish('cancelled');
        case 'M83' || 'M82' || 'M400' || 'SAVE_GCODE_STATE' || 'RESTORE_GCODE_STATE':
          break;
        default:
          _respond(_macros.containsKey(cmd)
              ? '// Demo printer: pretended to run $cmd'
              : '// Demo printer: $cmd has no effect here');
      }
    }
  }

  void _runLine(String line) {
    final console = _console.length;
    _runScript(line);
    // Internal follow-up commands don't belong in the console.
    _console.removeRange(console, _console.length);
  }

  bool _relative = false;

  void _moveTo(List<double> xyz) {
    final pos = [xyz[0], xyz[1], xyz[2], 0.0];
    _set('gcode_move', {'gcode_position': pos, 'position': pos});
    _set('toolhead', {'position': pos});
    _set('motion_report', {'live_position': pos});
  }

  void _respond(String message) {
    _console.add({'message': message, 'time': _now, 'type': 'response'});
    notify('notify_gcode_response', [message]);
  }

  // ------------------------------------------------------------ print job

  Map<String, dynamic>? _job;

  void _startPrint(String filename, {double progress = 0, bool notifyChanges = true}) {
    final file = _gcodes[filename];
    if (file == null) {
      _respond('!! File $filename not found on the demo printer');
      return;
    }
    if (_job != null) {
      _respond('!! The demo printer is already printing');
      return;
    }
    final total = file.seconds.toDouble();
    final meta = file.metadata(_now);
    _job = {
      'job_id': (1000 + _history.length).toRadixString(16).toUpperCase().padLeft(6, '0'),
      'user': '',
      'filename': filename,
      'status': 'in_progress',
      'start_time': _now - total * progress / speedUp,
      'end_time': null,
      'print_duration': total * progress,
      'total_duration': total * progress,
      'filament_used': file.filamentMm * progress,
      'metadata': meta,
      'auxiliary_data': <dynamic>[],
      'exists': true,
    };
    _history.insert(0, _job!);
    _set('extruder', {'target': file.nozzle.toDouble()});
    _set('heater_bed', {'target': file.bed.toDouble()});
    _set('fan', {'speed': 0.8});
    _set('toolhead', {'homed_axes': 'xyz'});
    _set('idle_timeout', {'state': 'Printing'});
    _set('pause_resume', {'is_paused': false});
    _set('exclude_object', {
      'objects': [for (final o in file.objects) o.toExcludeObject()],
      'excluded_objects': <dynamic>[],
      'current_object': file.objects.first.name,
    });
    _set('print_stats', {
      'state': 'printing',
      'filename': filename,
      'message': '',
      'print_duration': total * progress,
      'total_duration': total * progress,
      'filament_used': file.filamentMm * progress,
      'info': {'total_layer': file.layers, 'current_layer': (file.layers * progress).round()},
    });
    _set('virtual_sdcard', {
      'progress': progress,
      'is_active': true,
      'file_path': '/home/demo/printer_data/gcodes/$filename',
      'file_size': file.size,
      'file_position': (file.size * progress).round(),
    });
    _set('display_status', {'progress': progress, 'message': null});
    if (notifyChanges) {
      _respond('// Demo printer: printing $filename');
      notify('notify_history_changed', [
        {'action': 'added', 'job': _copy(_job!)},
      ]);
    }
  }

  void _setPrintState(String state) {
    if (_job == null) return;
    _set('print_stats', {'state': state});
    _set('pause_resume', {'is_paused': state == 'paused'});
    _set('virtual_sdcard', {'is_active': state == 'printing'});
    if (state == 'paused') _moveTo([240.0, 240.0, (status['gcode_move']!['position'] as List)[2] + 10.0]);
  }

  void _finish(String state) {
    final job = _job;
    if (job == null) return;
    job
      ..['status'] = state == 'complete' ? 'completed' : state
      ..['end_time'] = _now
      ..['print_duration'] = status['print_stats']!['print_duration']
      ..['total_duration'] = status['print_stats']!['total_duration']
      ..['filament_used'] = status['print_stats']!['filament_used'];
    _job = null;
    _set('print_stats', {'state': state});
    _set('pause_resume', {'is_paused': false});
    _set('virtual_sdcard', {'is_active': false});
    _set('idle_timeout', {'state': 'Ready'});
    _set('exclude_object', {'current_object': null});
    _set('extruder', {'target': 0.0});
    _set('heater_bed', {'target': 0.0});
    _set('fan', {'speed': 0.0});
    _respond('// Demo printer: print ${state == 'complete' ? 'finished' : state}');
    notify('notify_history_changed', [
      {'action': 'finished', 'job': _copy(job)},
    ]);
    if (state == 'complete') {
      Timer(const Duration(seconds: 5), () {
        if (!_disposed && _job == null) _loadNextQueuedJob();
      });
    }
  }

  // ------------------------------------------------------------ simulation

  /// Advances the pretend printer by one second.
  void tick() {
    // Heaters approach their target, then hover around it.
    for (final (heater, rate) in [('extruder', 4.0), ('heater_bed', 1.5)]) {
      final temp = (status[heater]!['temperature'] as num).toDouble();
      final target = (status[heater]!['target'] as num).toDouble();
      final goal = target > 0 ? target : _room;
      final next = (goal - temp).abs() < rate
          ? goal + (_random.nextDouble() - 0.5) * 0.6
          : temp + rate * (goal > temp ? 1 : -0.6);
      _set(heater, {
        'temperature': double.parse(next.toStringAsFixed(2)),
        'power': target > 0 ? (next < target ? 1.0 : 0.35 + _random.nextDouble() * 0.1) : 0.0,
      });
    }
    _set('extruder', {'can_extrude': (status['extruder']!['temperature'] as num) >= 170});
    _set('heater_fan hotend_fan', {'speed': (status['extruder']!['temperature'] as num) > 50 ? 1.0 : 0.0});
    final chamber = (status['temperature_sensor chamber']!['temperature'] as num).toDouble();
    final chamberGoal = (status['heater_bed']!['target'] as num) > 0 ? 39.0 : 26.0;
    _set('temperature_sensor chamber', {
      'temperature': double.parse((chamber + (chamberGoal - chamber) * 0.02).toStringAsFixed(2)),
    });
    final pi = 50 + (_job != null ? 4 : 0) + (_random.nextDouble() - 0.5) * 2;
    _set('temperature_sensor raspberry_pi', {'temperature': double.parse(pi.toStringAsFixed(2))});
    _recordTemperatures();

    final job = _job;
    final stats = status['print_stats']!;
    if (job != null && stats['state'] == 'printing') {
      final file = _gcodes[stats['filename']];
      if (file == null) {
        _finish('error');
        return;
      }
      final total = file.seconds.toDouble();
      final factor = (status['gcode_move']!['speed_factor'] as num).toDouble();
      final duration = (stats['print_duration'] as num) + speedUp * factor;
      final progress = (duration / total).clamp(0.0, 1.0);
      final previousFilament = (stats['filament_used'] as num).toDouble();
      final filament = file.filamentMm * progress;
      // ~2.98 g per meter of 1.75 mm PLA
      spoolman.consume((filament - previousFilament) * 2.98 / 1000);
      final layer = (file.layers * progress).round();
      _set('print_stats', {
        'print_duration': duration,
        'total_duration': (stats['total_duration'] as num) + speedUp,
        'filament_used': filament,
        'info': {'total_layer': file.layers, 'current_layer': layer},
      });
      _set('virtual_sdcard', {'progress': progress, 'file_position': (file.size * progress).round()});
      _set('display_status', {'progress': progress});
      _set('idle_timeout', {'printing_time': duration});
      _set('motion_report', {'live_velocity': 120 + _random.nextDouble() * 60, 'live_extruder_velocity': 2.4});

      // The toolhead traces the objects that are still printed.
      final excluded = status['exclude_object']!['excluded_objects'] as List;
      final remaining = file.objects.where((o) => !excluded.contains(o.name)).toList();
      if (remaining.isEmpty) {
        _finish('complete');
        return;
      }
      final object = remaining[(duration ~/ 30) % remaining.length];
      final outline = object.outline(layer);
      final point = outline[(duration ~/ speedUp) % outline.length];
      _set('exclude_object', {'current_object': object.name});
      _moveTo([point[0], point[1], double.parse((file.height * progress).toStringAsFixed(2))]);
      if (progress >= 1) _finish('complete');
    } else {
      _set('motion_report', {'live_velocity': 0.0, 'live_extruder_velocity': 0.0});
    }
  }

  // ------------------------------------------------------------ seeds

  final double _startTime = DateTime.now().millisecondsSinceEpoch / 1000;

  void _seedTemperatureStore() {
    // The last 20 minutes: the printer heated up for the current print, then held its temperatures.
    List<double> curve(double from, double to, double noise, int heatUntil) => [
          for (var i = 0; i < _temperatureStoreSize; i++)
            double.parse(
              (i < heatUntil ? from + (to - from) * math.pow(i / heatUntil, 0.6) : to + (_random.nextDouble() - 0.5) * noise)
                  .toStringAsFixed(2),
            ),
        ];
    List<double> flat(double v) => List.filled(_temperatureStoreSize, v, growable: true);
    _temperatureStore
      ..['extruder'] = {
        'temperatures': curve(_room, 215, 0.8, 140),
        'targets': flat(215),
        'powers': [for (var i = 0; i < _temperatureStoreSize; i++) i < 140 ? 1.0 : 0.38],
      }
      ..['heater_bed'] = {
        'temperatures': curve(_room, 60, 0.4, 260),
        'targets': flat(60),
        'powers': [for (var i = 0; i < _temperatureStoreSize; i++) i < 260 ? 1.0 : 0.3],
      }
      ..['temperature_sensor chamber'] = {'temperatures': curve(_room, 38.2, 0.2, 900)}
      ..['temperature_sensor raspberry_pi'] = {'temperatures': curve(46, 51.7, 1.5, 300)};
  }

  void _recordTemperatures() {
    for (final MapEntry(key: sensor, value: series) in _temperatureStore.entries) {
      for (final (field, key) in [('temperatures', 'temperature'), ('targets', 'target'), ('powers', 'power')]) {
        final list = series[field];
        if (list == null) continue;
        list
          ..removeAt(0)
          ..add((status[sensor]![key] as num).toDouble());
      }
    }
  }

  void _seedConsole() {
    final t = _startTime - 1500;
    _console.addAll([
      {'message': 'FIRMWARE_RESTART', 'time': t, 'type': 'command'},
      {'message': '// Klipper state: Ready', 'time': t + 4, 'type': 'response'},
      {'message': 'G28', 'time': t + 60, 'type': 'command'},
      {'message': 'BED_MESH_CALIBRATE', 'time': t + 90, 'type': 'command'},
      {'message': '// Mesh Bed Leveling Complete', 'time': t + 160, 'type': 'response'},
      {'message': 'SDCARD_PRINT_FILE FILENAME="Gridfinity_bins_x4_PLA_2h05m.gcode"', 'time': t + 200, 'type': 'command'},
      {'message': '// Welcome to the Mobileraker demo printer! Commands you send here are simulated.', 'time': t + 201, 'type': 'response'},
    ]);
  }

  List<Map<String, dynamic>> _seedHistory() {
    Map<String, dynamic> job(int id, String file, String jobStatus, double hoursAgo, double share) {
      final gcode = _gcodes[file]!;
      final duration = gcode.seconds * share;
      return {
        'job_id': id.toRadixString(16).toUpperCase().padLeft(6, '0'),
        'user': '',
        'filename': file,
        'status': jobStatus,
        'start_time': _now - hoursAgo * 3600,
        'end_time': _now - hoursAgo * 3600 + duration,
        'print_duration': duration,
        'total_duration': duration + 240,
        'filament_used': gcode.filamentMm * share,
        'metadata': gcode.metadata(_now),
        'auxiliary_data': <dynamic>[],
        'exists': true,
      };
    }

    return [
      job(905, 'Twisted_vase_PETG_1h28m.gcode', 'completed', 20, 1),
      job(904, 'Cable_clips_x8_PLA_24m.gcode', 'completed', 27, 1),
      job(903, 'Planter_ABS_3h12m.gcode', 'cancelled', 49, 0.18),
      job(902, 'Planter_ABS_3h12m.gcode', 'completed', 74, 1),
      job(901, 'calibration/Calibration_cube_PLA_18m.gcode', 'completed', 96, 1),
      job(900, 'Twisted_vase_PETG_1h28m.gcode', 'klippy_shutdown', 120, 0.4),
    ];
  }

  // ------------------------------------------------------------ plumbing

  final _pending = <String, Map<String, dynamic>>{};

  var _flushScheduled = false;

  /// Changes fields of a status object and queues them for the next
  /// `notify_status_update` (sent once per turn of the event loop).
  void _set(String object, Map<String, dynamic> fields) {
    status[object]!.addAll(fields);
    (_pending[object] ??= {}).addAll(fields);
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(_flush);
  }

  void _flush() {
    _flushScheduled = false;
    if (_pending.isEmpty) return;
    final update = {for (final e in _pending.entries) e.key: _copy(e.value)};
    _pending.clear();
    notify('notify_status_update', [update, _now]);
  }

  double get _now => DateTime.now().millisecondsSinceEpoch / 1000;
}

/// Deep copy, so callers can't change the simulator's state by accident.
Map<String, dynamic> _copy(Map<String, dynamic> map) => {
      for (final MapEntry(:key, :value) in map.entries)
        key: switch (value) {
          Map() => _copy(value.cast<String, dynamic>()),
          List() => _copyList(value),
          _ => value,
        },
    };

List<dynamic> _copyList(List<dynamic> list) => [
      for (final v in list)
        switch (v) {
          Map() => _copy(v.cast<String, dynamic>()),
          List() => _copyList(v),
          _ => v,
        },
    ];
