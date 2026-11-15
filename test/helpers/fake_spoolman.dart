/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/pagination_result.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker_pro/spoolman/dto/create_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/create_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/get_extra_field.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/create_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/update_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/update_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/update_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spool_group.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_entity_type_enum.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/spoolman_server_info.dart';

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

  static GetSpool spool(int id, GetFilament filament, {double usedWeight = 250, String? location}) => GetSpool(
    id: id,
    registered: _registered,
    filament: filament,
    usedWeight: usedWeight,
    remainingWeight: 1000 - usedWeight,
    usedLength: usedWeight * 330,
    location: location,
    archived: false,
  );
}

/// An in-memory Spoolman. Lists honour the filters the detail pages use (by filament, vendor and material).
class FakeSpoolmanService extends Fake implements SpoolmanService {
  FakeSpoolmanService({
    this.spools = const [],
    this.filaments = const [],
    this.vendors = const [],
    this.serverVersion,
  });

  final List<GetSpool> spools;
  final List<GetFilament> filaments;
  final List<GetVendor> vendors;

  /// The Spoolman version [getServerInfo] reports, without one it fails (the page then shows what all versions have).
  final String? serverVersion;

  static bool _matches(Map<String, dynamic>? filter, Object? Function(String key) valueOf) {
    if (filter == null) return true;
    for (final MapEntry(:key, :value) in filter.entries) {
      final actual = valueOf(key);
      // Filters this fake doesn't know (e.g. the filter chips) don't restrict the list.
      if (actual == _unknown) continue;
      // Like Spoolman: quoted is an exact match, empty or -1 (IDs) matches unset fields
      final expected = '$value'.replaceAll(RegExp(r'^"|"$'), '');
      if (actual == null ? !(expected.isEmpty || expected == '-1') : '$actual' != expected) return false;
    }
    return true;
  }

  static const _unknown = Object();

  static Object? _spoolValue(GetSpool s, String key) => switch (key) {
    'filament.id' => s.filament.id,
    'filament.material' => s.filament.material,
    'filament.vendor.id' => s.filament.vendor?.id,
    'location' => s.location,
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

  /// The filters of the spool list and group requests, e.g. to check the sort.
  final List<Map<String, dynamic>?> spoolListFilters = [];
  final List<Map<String, dynamic>?> groupFilters = [];
  final List<Map<String, dynamic>?> filamentListFilters = [];
  final List<Map<String, dynamic>?> vendorListFilters = [];

  @override
  Future<PaginationResult<GetSpool>> spoolList({int? pageSize, int? page, Map<String, dynamic>? filter}) async {
    spoolListFilters.add(filter);
    return _page(
    [
      for (final s in spools)
        if (_matches(filter, (k) => _spoolValue(s, k))) s,
    ],
    page,
    pageSize,
  );
  }

  @override
  Future<PaginationResult<GetFilament>> filamentList({int? pageSize, int? page, Map<String, dynamic>? filter}) async {
    filamentListFilters.add(filter);
    return _page(
        [
          for (final f in filaments)
            if (_matches(filter, (k) => _filamentValue(f, k))) f,
        ],
        page,
        pageSize,
      );
  }

  @override
  Future<PaginationResult<GetVendor>> vendorList({int? pageSize, int? page, Map<String, dynamic>? filter}) async {
    vendorListFilters.add(filter);
    return _page(vendors, page, pageSize);
  }

  @override
  Future<SpoolmanServerInfo> getServerInfo() async {
    if (serverVersion == null) throw UnimplementedError('No Spoolman version set');
    return SpoolmanServerInfo(
      version: serverVersion!,
      debugMode: false,
      automaticBackups: false,
      dataDir: '',
      logsDir: '',
      backupsDir: '',
      dbType: 'sqlite',
      gitCommit: '',
    );
  }

  /// Groups the [spools] matching the filter like Spoolman, sorted by the group's title.
  @override
  Future<PaginationResult<SpoolGroup>> spoolGroups(
    SpoolGroupBy groupBy, {
    int? pageSize,
    int? page,
    Map<String, dynamic>? filter,
  }) async {
    groupFilters.add(filter);
    final byKey = <String?, List<GetSpool>>{};
    for (final s in spools) {
      if (!_matches(filter, (k) => _spoolValue(s, k))) continue;
      final key = switch (groupBy) {
        SpoolGroupBy.filament => '${s.filament.id}',
        SpoolGroupBy.vendor => s.filament.vendor?.id.toString(),
        SpoolGroupBy.material => s.filament.material,
        SpoolGroupBy.location => s.location,
      };
      (byKey[key] ??= []).add(s);
    }
    final groups = [
      for (final MapEntry(:key, value: members) in byKey.entries)
        SpoolGroup(
          groupBy: groupBy.name,
          key: key,
          spoolCount: members.length,
          inUseCount: members.where((s) => s.usedWeight > 0).length,
          totalRemainingWeight: members.fold<double>(0, (sum, s) => sum + (s.remainingWeight ?? 0)),
          filament: groupBy == SpoolGroupBy.filament ? members.first.filament : null,
          vendor: groupBy == SpoolGroupBy.vendor ? members.first.filament.vendor : null,
        ),
    ];
    String title(SpoolGroup g) => g.filament?.name ?? g.vendor?.name ?? g.key ?? '';
    groups.sort((a, b) => title(a).compareTo(title(b)));
    return _page(groups, page, pageSize);
  }

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

  /// Filaments and vendors sent to the create / update calls.
  final List<CreateFilament> createdFilaments = [];
  final List<UpdateFilament> updatedFilaments = [];
  final List<CreateVendor> createdVendors = [];
  final List<UpdateVendor> updatedVendors = [];

  @override
  Future<GetFilament> createFilament(CreateFilament filament) async {
    createdFilaments.add(filament);
    return SpoolmanFixtures.filament(200 + createdFilaments.length, filament.name ?? '', vendor: filament.vendor);
  }

  @override
  Future<GetFilament> updateFilament(UpdateFilament filament) async {
    updatedFilaments.add(filament);
    return filaments.firstWhere((f) => f.id == filament.id);
  }

  @override
  Future<GetVendor> createVendor(CreateVendor vendor) async {
    createdVendors.add(vendor);
    return SpoolmanFixtures.vendor(300 + createdVendors.length, vendor.name);
  }

  @override
  Future<GetVendor> updateVendor(UpdateVendor vendor) async {
    updatedVendors.add(vendor);
    return vendors.firstWhere((v) => v.id == vendor.id);
  }

  /// The actions of the detail pages, e.g. `delete spool 7`, `activate 7`, `adjust 7 weight 10.0`.
  final List<String> actions = [];

  /// Whether deletes fail, like a Spoolman that is not reachable.
  bool failDeletes = false;

  Future<T> _delete<T>(String what, int id, T entity) async {
    if (failDeletes) throw Exception('Spoolman not reachable');
    actions.add('delete $what $id');
    return entity;
  }

  @override
  Future<GetSpool> deleteSpool(GetSpool spool) => _delete('spool', spool.id, spool);

  @override
  Future<GetFilament> deleteFilament(GetFilament filament) => _delete('filament', filament.id, filament);

  @override
  Future<GetVendor> deleteVendor(GetVendor vendor) => _delete('vendor', vendor.id, vendor);

  static final _ok = RpcResponse(jsonrpc: '2.0', id: 1, result: const {});

  @override
  Future<RpcResponse> setActiveSpool(GetSpool spool) async {
    actions.add('activate ${spool.id}');
    return _ok;
  }

  @override
  Future<RpcResponse> clearActiveSpool() async {
    actions.add('deactivate');
    return _ok;
  }

  @override
  Future<GetSpool> archiveSpool(GetSpool spool, [bool archive = true]) async {
    actions.add('${archive ? 'archive' : 'unarchive'} ${spool.id}');
    return spool.copyWith(archived: archive);
  }

  @override
  Future<GetSpool> adjustFilamentOnSpool({required GetSpool spool, double? length, double? weight}) async {
    actions.add('adjust ${spool.id} ${length != null ? 'length $length' : 'weight $weight'}');
    return spool;
  }

  @override
  Future<GetSpool> measureSpool({required GetSpool spool, required double grossWeight}) async {
    actions.add('measure ${spool.id} $grossWeight');
    return spool;
  }
}

/// A fixed active spool (none by default), without the provider's 30 s refresh timer.
class _FixedActiveSpool extends ActiveSpool {
  _FixedActiveSpool(this.spool);

  final GetSpool? spool;

  @override
  Stream<GetSpool?> build(String machineUUID) => Stream.value(spool);
}

/// Overrides for a machine whose Spoolman is [service], with [activeSpool] as the active spool.
List<Override> spoolmanOverrides(String machineUUID, FakeSpoolmanService service, {GetSpool? activeSpool}) => [
  spoolmanServiceProvider(machineUUID).overrideWithValue(service),
  activeSpoolProvider(machineUUID).overrideWith(() => _FixedActiveSpool(activeSpool)),
];
