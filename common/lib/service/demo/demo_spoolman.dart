/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

/// A small in-memory Spoolman behind the demo printer's `server.spoolman.proxy`.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../network/json_rpc_client.dart';

class DemoSpoolman {
  DemoSpoolman() {
    final registered = DateTime.now().subtract(const Duration(days: 120)).toUtc().toIso8601String();
    _vendors.addAll([
      {'id': 1, 'registered': registered, 'name': 'Prusament', 'empty_spool_weight': 201.0, 'extra': <String, String>{}},
      {'id': 2, 'registered': registered, 'name': 'Polymaker', 'empty_spool_weight': 140.0, 'extra': <String, String>{}},
      {'id': 3, 'registered': registered, 'name': 'eSun', 'empty_spool_weight': 224.0, 'extra': <String, String>{}},
    ]);
    Map<String, dynamic> filament(int id, String name, int vendor, String material, String color, int nozzle, int bed,
            {double density = 1.24, double price = 24.99}) =>
        {
          'id': id,
          'registered': registered,
          'name': name,
          'vendor': _vendors.firstWhere((v) => v['id'] == vendor),
          'material': material,
          'price': price,
          'density': density,
          'diameter': 1.75,
          'weight': 1000.0,
          'spool_weight': _vendors.firstWhere((v) => v['id'] == vendor)['empty_spool_weight'],
          'color_hex': color,
          'settings_extruder_temp': nozzle,
          'settings_bed_temp': bed,
          'extra': <String, String>{},
        };
    _filaments.addAll([
      filament(1, 'Galaxy Black', 1, 'PLA', '1C1C1E', 215, 60),
      filament(2, 'Azure Blue', 1, 'PLA', '2F80ED', 215, 60),
      filament(3, 'Jungle Green', 2, 'PETG', '27AE60', 240, 80, density: 1.27),
      filament(4, 'Signal Red', 3, 'ABS', 'EB5757', 250, 100, density: 1.04, price: 19.99),
      filament(5, 'Orange', 2, 'PLA', 'F2994A', 210, 60),
    ]);
    Map<String, dynamic> spool(int id, int filamentId, double used, String location, {bool archived = false}) {
      final f = _filaments.firstWhere((f) => f['id'] == filamentId);
      return {
        'id': id,
        'registered': registered,
        'first_used': registered,
        'last_used': DateTime.now().subtract(Duration(days: id * 3)).toUtc().toIso8601String(),
        'filament': f,
        'initial_weight': 1000.0,
        'spool_weight': f['spool_weight'],
        'used_weight': used,
        'price': f['price'],
        'location': location,
        'lot_nr': 'LOT-${2400 + id}',
        'comment': null,
        'archived': archived,
        'extra': <String, String>{},
      };
    }

    _spools.addAll([
      spool(1, 2, 412.5, 'Printer'),
      spool(2, 1, 120.0, 'Dry box'),
      spool(3, 3, 655.0, 'Dry box'),
      spool(4, 4, 80.0, 'Shelf'),
      spool(5, 5, 990.0, 'Shelf', archived: true),
    ]);
  }

  final _vendors = <Map<String, dynamic>>[];
  final _filaments = <Map<String, dynamic>>[];
  final _spools = <Map<String, dynamic>>[];

  /// The spool moonraker tracks usage for.
  int? activeSpoolId = 1;

  /// Books [grams] onto the active spool while the demo prints.
  void consume(double grams) {
    final spool = _spools.where((s) => s['id'] == activeSpoolId).firstOrNull;
    if (spool == null) return;
    spool['used_weight'] = math.min(1000.0, (spool['used_weight'] as num) + grams);
    spool['last_used'] = DateTime.now().toUtc().toIso8601String();
  }

  /// Answers a `server.spoolman.proxy` call like moonraker does.
  dynamic proxy(Map<String, dynamic> params) {
    final v2 = params['use_v2_response'] == true;
    try {
      final (body, headers) = _handle(
        '${params['request_method'] ?? 'GET'}'.toUpperCase(),
        '${params['path'] ?? ''}',
        Uri.splitQueryString('${params['query'] ?? ''}'),
        params['body'] is Map ? (params['body'] as Map).cast<String, dynamic>() : const <String, dynamic>{},
      );
      if (!v2) return body;
      return {'response': body, 'response_headers': headers, 'error': null};
    } on _SpoolmanError catch (e) {
      if (!v2) throw JRpcError(e.status, e.message);
      return {
        'response': null,
        'error': {'status_code': e.status, 'message': e.message},
      };
    }
  }

  (dynamic, Map<String, dynamic>?) _handle(
      String method, String path, Map<String, String> query, Map<String, dynamic> body) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty || parts.first != 'v1') throw _SpoolmanError(404, 'Not found');
    final resource = parts.elementAtOrNull(1);
    final id = int.tryParse(parts.elementAtOrNull(2) ?? '');
    final action = parts.elementAtOrNull(3);

    switch (resource) {
      case 'info':
        return (
          {
            'version': '0.21.0',
            'debug_mode': false,
            'automatic_backups': true,
            'data_dir': '/home/demo/.local/share/spoolman',
            'logs_dir': '/home/demo/.local/share/spoolman',
            'backups_dir': '/home/demo/.local/share/spoolman/backups',
            'db_type': 'sqlite',
            'git_commit': 'demo',
            'build_date': '2025-06-01T00:00:00Z',
          },
          null
        );
      case 'setting':
        final key = parts.elementAtOrNull(2);
        if (key == 'currency') return ({'value': jsonEncode('EUR'), 'is_set': true, 'type': 'string'}, null);
        throw _SpoolmanError(404, 'Setting not found');
      case 'field':
        return (<dynamic>[], null);
      case 'location':
        return ({for (final s in _spools) s['location']}.whereType<String>().toList(), null);
      case 'material':
        return ({for (final f in _filaments) f['material']}.whereType<String>().toList(), null);
      case 'spool' || 'filament' || 'vendor':
        final table = switch (resource) {
          'spool' => _spools,
          'filament' => _filaments,
          _ => _vendors,
        };
        if (id == null) {
          if (method == 'POST') return (_create(resource!, body), null);
          return _list(table, query, resource == 'spool');
        }
        final entity = table.where((e) => e['id'] == id).firstOrNull;
        if (entity == null) throw _SpoolmanError(404, 'No $resource with ID $id found.');
        switch ((method, action)) {
          case ('GET', null):
            return (entity, null);
          case ('PATCH', null):
            _update(resource!, entity, body);
            return (entity, null);
          case ('DELETE', null):
            table.remove(entity);
            return ({'message': 'Success!'}, null);
          case ('PUT', 'use'):
            final grams = (body['use_weight'] as num?)?.toDouble() ??
                ((body['use_length'] as num?)?.toDouble() ?? 0) * 2.98 / 1000;
            entity['used_weight'] = (entity['used_weight'] as num) + grams;
            return (entity, null);
          case ('PUT', 'measure'):
            final weight = (body['weight'] as num?)?.toDouble() ?? 0;
            final initial = (entity['initial_weight'] as num? ?? 1000).toDouble();
            final empty = (entity['spool_weight'] as num? ?? 0).toDouble();
            entity['used_weight'] = math.max(0.0, initial - (weight - empty));
            return (entity, null);
        }
        throw _SpoolmanError(405, 'Method not allowed');
    }
    throw _SpoolmanError(404, 'Not found');
  }

  (List<Map<String, dynamic>>, Map<String, dynamic>) _list(
      List<Map<String, dynamic>> table, Map<String, String> query, bool canArchive) {
    var rows = [
      for (final row in table)
        if (!canArchive || query['allow_archived'] == 'true' || row['archived'] != true) _withComputed(row),
    ];
    final total = rows.length;
    final offset = int.tryParse(query['offset'] ?? '') ?? 0;
    final limit = int.tryParse(query['limit'] ?? '');
    rows = rows.skip(offset).take(limit ?? rows.length).toList();
    return (rows, {'X-Total-Count': '$total'});
  }

  Map<String, dynamic> _withComputed(Map<String, dynamic> row) {
    if (!row.containsKey('used_weight')) return row;
    final used = (row['used_weight'] as num).toDouble();
    final initial = (row['initial_weight'] as num? ?? 1000).toDouble();
    final filament = row['filament'] as Map<String, dynamic>;
    // Length per gram for 1.75 mm filament: 1 / (density * cross-section).
    final mmPerGram = 1000 / ((filament['density'] as num) * math.pi * math.pow(1.75 / 2, 2));
    row
      ..['remaining_weight'] = math.max(0.0, initial - used)
      ..['used_length'] = used * mmPerGram
      ..['remaining_length'] = math.max(0.0, initial - used) * mmPerGram;
    return row;
  }

  Map<String, dynamic> _create(String resource, Map<String, dynamic> body) {
    final table = switch (resource) {
      'spool' => _spools,
      'filament' => _filaments,
      _ => _vendors,
    };
    final entity = <String, dynamic>{
      'id': table.fold<int>(0, (m, e) => math.max(m, e['id'] as int)) + 1,
      'registered': DateTime.now().toUtc().toIso8601String(),
      'extra': <String, String>{},
      if (resource == 'spool') ...{'used_weight': 0.0, 'archived': false},
      if (resource == 'filament') ...{'density': 1.24, 'diameter': 1.75},
      if (resource == 'vendor') 'name': 'Vendor',
    };
    _update(resource, entity, body);
    table.add(entity);
    return resource == 'spool' ? _withComputed(entity) : entity;
  }

  void _update(String resource, Map<String, dynamic> entity, Map<String, dynamic> body) {
    for (final MapEntry(:key, :value) in body.entries) {
      switch (key) {
        case 'filament_id':
          entity['filament'] = _filaments.firstWhere((f) => f['id'] == value,
              orElse: () => throw _SpoolmanError(404, 'No filament with ID $value found.'));
        case 'vendor_id':
          entity['vendor'] = value == null ? null : _vendors.where((v) => v['id'] == value).firstOrNull;
        case 'remaining_weight':
          entity['used_weight'] = (entity['initial_weight'] as num? ?? 1000) - (value as num);
        default:
          entity[key] = value;
      }
    }
    // Spools embed their filament, filaments their vendor: keep the copies current.
    if (resource == 'vendor') {
      for (final f in _filaments) {
        if ((f['vendor'] as Map?)?['id'] == entity['id']) f['vendor'] = entity;
      }
    }
    if (resource == 'filament') {
      for (final s in _spools) {
        if ((s['filament'] as Map)['id'] == entity['id']) s['filament'] = entity;
      }
    }
  }
}

class _SpoolmanError implements Exception {
  _SpoolmanError(this.status, this.message);

  final int status;
  final String message;
}
