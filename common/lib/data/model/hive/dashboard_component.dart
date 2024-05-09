/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'dashboard_component.g.dart';

@HiveType(typeId: 10)
class DashboardComponent extends HiveObject {
  DashboardComponent({
    required this.type,
    this.showWhilePrinting = true,
    this.showBeforePrinterReady = false,
  });

  DashboardComponent._({
    required this.uuid,
    required this.type,
    this.showWhilePrinting = true,
    this.showBeforePrinterReady = false,
  });

  @HiveField(0)
  String uuid = const Uuid().v4();

  @HiveField(1)
  DashboardComponentType type;

  @HiveField(2)
  bool showWhilePrinting;

  @HiveField(3)
  bool showBeforePrinterReady;

  DashboardComponent copyWith({
    DashboardComponentType? type,
    bool? showWhilePrinting,
    bool? showBeforePrinterReady,
  }) {
    return DashboardComponent._(
      uuid: uuid,
      type: type ?? this.type,
      showWhilePrinting: showWhilePrinting ?? this.showWhilePrinting,
      showBeforePrinterReady: showBeforePrinterReady ?? this.showBeforePrinterReady,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardComponent &&
          runtimeType == other.runtimeType &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          (identical(type, other.type) || type == other.type) &&
          (identical(showWhilePrinting, other.showWhilePrinting) || showWhilePrinting == other.showWhilePrinting) &&
          (identical(showBeforePrinterReady, other.showBeforePrinterReady) ||
              showBeforePrinterReady == other.showBeforePrinterReady);

  // const DeepCollectionEquality().equals(components, other.components);

  @override
  int get hashCode => Object.hash(
        uuid,
        type,
        showWhilePrinting,
        showBeforePrinterReady,
      );

  @override
  String toString() {
    return 'DashboardComponent{uuid: $uuid, type: $type, showWhilePrinting: $showWhilePrinting}';
  }

  Map<String, dynamic> export() {
    return {
      'version': 1,
      'type': type.name,
      'showWhilePrinting': showWhilePrinting,
      'showBeforePrinterReady': showBeforePrinterReady,
    };
  }
}
