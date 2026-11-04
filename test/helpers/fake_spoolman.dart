/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/pagination_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker_pro/spoolman/dto/get_extra_field.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/create_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/update_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_entity_type_enum.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';

/// Spoolman test data.
abstract final class SpoolmanFixtures {
  static final _registered = DateTime(2025, 1, 1);

  static GetVendor vendor(int id, String name) => GetVendor(id: id, registered: _registered, name: name);

  static GetFilament filament(
    int id,
    String name, {
    GetVendor? vendor,
    String material = 'PLA',
    String color = 'FF0000',
  }) => GetFilament(
    id: id,
    registered: _registered,
    name: name,
    vendor: vendor,
    material: material,
    density: 1.24,
    diameter: 1.75,
    weight: 1000,
    colorHex: color,
  );

  static GetSpool spool(int id, GetFilament filament, {double usedWeight = 250}) => GetSpool(
    id: id,
    registered: _registered,
    filament: filament,
    usedWeight: usedWeight,
    remainingWeight: 1000 - usedWeight,
    usedLength: usedWeight * 330,
    archived: false,
  );
}

/// An in-memory Spoolman. Lists honour the filters the detail pages use (by filament, vendor and material).
class FakeSpoolmanService extends Fake implements SpoolmanService {
  FakeSpoolmanService({this.spools = const [], this.filaments = const [], this.vendors = const []});

  final List<GetSpool> spools;
  final List<GetFilament> filaments;
  final List<GetVendor> vendors;

  static bool _matches(Map<String, dynamic>? filter, Object? Function(String key) valueOf) {
    if (filter == null) return true;
    for (final MapEntry(:key, :value) in filter.entries) {
      final actual = valueOf(key);
      // Filters this fake doesn't know (e.g. the filter chips) don't restrict the list.
      if (actual == _unknown) continue;
      if ('$actual' != '$value') return false;
    }
    return true;
  }

  static const _unknown = Object();

  static Object? _spoolValue(GetSpool s, String key) => switch (key) {
    'filament.id' => s.filament.id,
    'filament.material' => s.filament.material,
    'filament.vendor.id' => s.filament.vendor?.id,
    _ => _unknown,
  };

  static Object? _filamentValue(GetFilament f, String key) => switch (key) {
    'vendor.id' => f.vendor?.id,
    'material' => f.material,
    _ => _unknown,
  };

  static PaginationResult<T> _page<T>(List<T> all, int? page, int? pageSize) {
    final size = pageSize ?? (all.isEmpty ? 1 : all.length);
    final p = page ?? 0;
    return PaginationResult(all.skip(p * size).take(size).toList(), all.length, p, size);
  }

  @override
  Future<PaginationResult<GetSpool>> spoolList({int? pageSize, int? page, Map<String, dynamic>? filter}) async => _page(
    [
      for (final s in spools)
        if (_matches(filter, (k) => _spoolValue(s, k))) s,
    ],
    page,
    pageSize,
  );

  @override
  Future<PaginationResult<GetFilament>> filamentList({int? pageSize, int? page, Map<String, dynamic>? filter}) async =>
      _page(
        [
          for (final f in filaments)
            if (_matches(filter, (k) => _filamentValue(f, k))) f,
        ],
        page,
        pageSize,
      );

  @override
  Future<PaginationResult<GetVendor>> vendorList({int? pageSize, int? page, Map<String, dynamic>? filter}) async =>
      _page(vendors, page, pageSize);

  @override
  Future<GetSpool?> spool(int id) async => spools.where((s) => s.id == id).firstOrNull;

  @override
  Future<GetFilament?> filament(int id) async => filaments.where((f) => f.id == id).firstOrNull;

  @override
  Future<GetVendor?> vendor(int id) async => vendors.where((v) => v.id == id).firstOrNull;

  @override
  Future<GetSpool?> getActiveSpool() async => null;

  @override
  Stream<GetSpool?> get activeSpoolStream => const Stream.empty();

  @override
  Future<String> getSystemCurrency() async => 'EUR';

  @override
  Future<List<GetExtraField>> getExtraFieldsFor(SpoolmanEntityType type) async => [];

  @override
  Future<List<String>> allMaterials() async => {for (final f in filaments) ?f.material}.toList();

  /// Spools sent to [createSpool] / [updateSpool].
  final List<CreateSpool> created = [];
  final List<UpdateSpool> updated = [];

  @override
  Future<GetSpool> createSpool(CreateSpool spool) async {
    created.add(spool);
    return SpoolmanFixtures.spool(100 + created.length, spool.filament);
  }

  @override
  Future<GetSpool> updateSpool(UpdateSpool spool) async {
    updated.add(spool);
    return spools.firstWhere((s) => s.id == spool.id);
  }

  @override
  Future<List<String>> allLocations() async => {for (final s in spools) ?s.location}.toList();
}

/// No active spool, without the provider's 30 s refresh timer.
class _NoActiveSpool extends ActiveSpool {
  @override
  Stream<GetSpool?> build(String machineUUID) => Stream.value(null);
}

/// Overrides for a machine whose Spoolman is [service].
List<Override> spoolmanOverrides(String machineUUID, FakeSpoolmanService service) => [
  spoolmanServiceProvider(machineUUID).overrideWithValue(service),
  activeSpoolProvider(machineUUID).overrideWith(_NoActiveSpool.new),
];
