/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/gcode_thumbnail.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:hooks_riverpod/experimental/persist.dart';

part 'folder_cache_entry.freezed.dart';
part 'folder_cache_entry.g.dart';

@freezed
sealed class FolderCacheEntry with _$FolderCacheEntry {
  @HiveType(typeId: 13)
  const factory FolderCacheEntry({
    @HiveField(0) required String folderPath,
    // Absolute UTC expiry time — set by HiveFolderCacheStorage.write(), null means never expires.
    @HiveField(1) DateTime? expireAt,
    @HiveField(2) @Default([]) List<CachedFolder> folders,
    @HiveField(3) @Default([]) List<CachedGCodeFile> gcodeFiles,
    @HiveField(4) @Default([]) List<CachedGenericFile> genericFiles,
  }) = _FolderCacheEntry;

  const FolderCacheEntry._();

  FolderContentWrapper toFolderContentWrapper() {
    return FolderContentWrapper(
      folderPath,
      folders.map((f) => f.toFolder()).toList(),
      [
        ...gcodeFiles.map((f) => f.toGCodeFile()),
        ...genericFiles.map((f) => f.toGenericFile()),
      ],
    );
  }

  factory FolderCacheEntry.fromFolderContentWrapper(FolderContentWrapper wrapper) {
    return FolderCacheEntry(
      folderPath: wrapper.folderPath,
      // expireAt is set by HiveFolderCacheStorage.write() — not known at encode time.
      folders: wrapper.folders.map(CachedFolder.fromFolder).toList(),
      gcodeFiles: wrapper.files.whereType<GCodeFile>().map(CachedGCodeFile.fromGCodeFile).toList(),
      genericFiles: wrapper.files.whereType<GenericFile>().map(CachedGenericFile.fromGenericFile).toList(),
    );
  }
}

/// Hive-backed [Storage] implementation for the file browser cache.
///
/// All operations are synchronous, which lets [persist()] set the cached state
/// immediately in [build()] before the first [await].
final class HiveFolderCacheStorage extends Storage<String, FolderCacheEntry> {
  HiveFolderCacheStorage() : _box = Hive.box<FolderCacheEntry>('fileContentCache');

  final Box<FolderCacheEntry> _box;

  @override
  PersistedData<FolderCacheEntry>? read(String key) {
    final entry = _box.get(key);
    if (entry == null) return null;
    return PersistedData(entry, expireAt: entry.expireAt);
  }

  @override
  void write(String key, FolderCacheEntry value, StorageOptions options) {
    final expireAt = options.cacheTime.duration != null
        ? DateTime.now().toUtc().add(options.cacheTime.duration!)
        : null;
    _box.put(key, value.copyWith(expireAt: expireAt));
  }

  @override
  void delete(String key) => _box.delete(key);

  @override
  void deleteOutOfDate() {
    final now = DateTime.now().toUtc();
    final staleKeys = _box.keys.where((k) {
      final entry = _box.get(k as String);
      return entry?.expireAt != null && entry!.expireAt!.isBefore(now);
    }).toList();
    _box.deleteAll(staleKeys);
  }
}

@freezed
sealed class CachedFolder with _$CachedFolder {
  @HiveType(typeId: 14)
  const factory CachedFolder({
    @HiveField(0) required String name,
    @HiveField(1) required String parentPath,
    @HiveField(2) required double modified,
    @HiveField(3) required int size,
    @HiveField(4) @Default('') String permissions,
  }) = _CachedFolder;

  const CachedFolder._();

  Folder toFolder() => Folder(name: name, parentPath: parentPath, modified: modified, size: size, permissions: permissions);

  factory CachedFolder.fromFolder(Folder f) => CachedFolder(
        name: f.name,
        parentPath: f.parentPath,
        modified: f.modified,
        size: f.size,
        permissions: f.permissions,
      );
}

@freezed
sealed class CachedGCodeFile with _$CachedGCodeFile {
  @HiveType(typeId: 15)
  const factory CachedGCodeFile({
    @HiveField(0) required String name,
    @HiveField(1) required String parentPath,
    @HiveField(2) required double modified,
    @HiveField(3) required int size,
    @HiveField(4) double? printStartTime,
    @HiveField(5) String? jobId,
    @HiveField(6) String? slicer,
    @HiveField(7) String? slicerVersion,
    @HiveField(8) int? gcodeStartByte,
    @HiveField(9) int? gcodeEndByte,
    @HiveField(10) int? layerCount,
    @HiveField(11) double? objectHeight,
    @HiveField(12) double? estimatedTime,
    @HiveField(13) @Default([]) List<double> nozzleDiameter,
    @HiveField(14) double? layerHeight,
    @HiveField(15) double? firstLayerHeight,
    @HiveField(16) double? firstLayerTempBed,
    @HiveField(17) double? firstLayerTempExtruder,
    @HiveField(18) double? chamberTemp,
    @HiveField(19) String? filamentName,
    @HiveField(20) List<String>? filamentColors,
    @HiveField(21) List<String>? extruderColors,
    @HiveField(22) List<int>? filamentTemps,
    @HiveField(23) String? filamentType,
    @HiveField(24) double? filamentTotal,
    @HiveField(25) int? filamentChangeCount,
    @HiveField(26) double? filamentWeightTotal,
    @HiveField(27) List<double>? filamentWeights,
    @HiveField(28) int? mmuPrint,
    @HiveField(29) List<int>? referencedTools,
    @HiveField(30) @Default([]) List<CachedGCodeThumbnail> thumbnails,
  }) = _CachedGCodeFile;

  const CachedGCodeFile._();

  GCodeFile toGCodeFile() => GCodeFile(
        name: name,
        parentPath: parentPath,
        modified: modified,
        size: size,
        printStartTime: printStartTime,
        jobId: jobId,
        slicer: slicer,
        slicerVersion: slicerVersion,
        gcodeStartByte: gcodeStartByte,
        gcodeEndByte: gcodeEndByte,
        layerCount: layerCount,
        objectHeight: objectHeight,
        estimatedTime: estimatedTime,
        nozzleDiameter: nozzleDiameter,
        layerHeight: layerHeight,
        firstLayerHeight: firstLayerHeight,
        firstLayerTempBed: firstLayerTempBed,
        firstLayerTempExtruder: firstLayerTempExtruder,
        chamberTemp: chamberTemp,
        filamentName: filamentName,
        filamentColors: filamentColors,
        extruderColors: extruderColors,
        filamentTemps: filamentTemps,
        filamentType: filamentType,
        filamentTotal: filamentTotal,
        filamentChangeCount: filamentChangeCount,
        filamentWeightTotal: filamentWeightTotal,
        filamentWeights: filamentWeights,
        mmuPrint: mmuPrint,
        referencedTools: referencedTools,
        thumbnails: thumbnails.map((t) => t.toThumbnail()).toList(),
      );

  factory CachedGCodeFile.fromGCodeFile(GCodeFile f) => CachedGCodeFile(
        name: f.name,
        parentPath: f.parentPath,
        modified: f.modified,
        size: f.size,
        printStartTime: f.printStartTime,
        jobId: f.jobId,
        slicer: f.slicer,
        slicerVersion: f.slicerVersion,
        gcodeStartByte: f.gcodeStartByte,
        gcodeEndByte: f.gcodeEndByte,
        layerCount: f.layerCount,
        objectHeight: f.objectHeight,
        estimatedTime: f.estimatedTime,
        nozzleDiameter: f.nozzleDiameter,
        layerHeight: f.layerHeight,
        firstLayerHeight: f.firstLayerHeight,
        firstLayerTempBed: f.firstLayerTempBed,
        firstLayerTempExtruder: f.firstLayerTempExtruder,
        chamberTemp: f.chamberTemp,
        filamentName: f.filamentName,
        filamentColors: f.filamentColors,
        extruderColors: f.extruderColors,
        filamentTemps: f.filamentTemps,
        filamentType: f.filamentType,
        filamentTotal: f.filamentTotal,
        filamentChangeCount: f.filamentChangeCount,
        filamentWeightTotal: f.filamentWeightTotal,
        filamentWeights: f.filamentWeights,
        mmuPrint: f.mmuPrint,
        referencedTools: f.referencedTools,
        thumbnails: f.thumbnails.map(CachedGCodeThumbnail.fromThumbnail).toList(),
      );
}

@freezed
sealed class CachedGenericFile with _$CachedGenericFile {
  @HiveType(typeId: 16)
  const factory CachedGenericFile({
    @HiveField(0) required String name,
    @HiveField(1) required String parentPath,
    @HiveField(2) required double modified,
    @HiveField(3) required int size,
    @HiveField(4) @Default('') String permissions,
  }) = _CachedGenericFile;

  const CachedGenericFile._();

  GenericFile toGenericFile() =>
      GenericFile(name: name, parentPath: parentPath, modified: modified, size: size, permissions: permissions);

  factory CachedGenericFile.fromGenericFile(GenericFile f) => CachedGenericFile(
        name: f.name,
        parentPath: f.parentPath,
        modified: f.modified,
        size: f.size,
        permissions: f.permissions,
      );
}

@freezed
sealed class CachedGCodeThumbnail with _$CachedGCodeThumbnail {
  @HiveType(typeId: 17)
  const factory CachedGCodeThumbnail({
    @HiveField(0) required int width,
    @HiveField(1) required int height,
    @HiveField(2) required int size,
    @HiveField(3) required String relativePath,
  }) = _CachedGCodeThumbnail;

  const CachedGCodeThumbnail._();

  GCodeThumbnail toThumbnail() =>
      GCodeThumbnail(width: width, height: height, size: size, relativePath: relativePath);

  factory CachedGCodeThumbnail.fromThumbnail(GCodeThumbnail t) =>
      CachedGCodeThumbnail(width: t.width, height: t.height, size: t.size, relativePath: t.relativePath);
}
