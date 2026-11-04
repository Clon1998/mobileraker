/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';

/// The entity shown in the detail pane of the Spoolman page's list-detail layout (larger layouts), per machine.
final spoolmanDetailSelectionProvider = NotifierProvider.autoDispose
    .family<SpoolmanDetailSelection, SpoolmanIdentifiableDtoMixin?, String>(SpoolmanDetailSelection.new);

class SpoolmanDetailSelection extends Notifier<SpoolmanIdentifiableDtoMixin?> {
  SpoolmanDetailSelection(this.machineUUID);

  final String machineUUID;

  @override
  SpoolmanIdentifiableDtoMixin? build() => null;

  void select(SpoolmanIdentifiableDtoMixin? entity) => state = entity;
}

/// Marks Spoolman details embedded in the detail pane of the Spoolman page instead of being their own page.
class EmbeddedSpoolmanDetail extends InheritedWidget {
  const EmbeddedSpoolmanDetail({super.key, required super.child});

  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<EmbeddedSpoolmanDetail>() != null;

  @override
  bool updateShouldNotify(EmbeddedSpoolmanDetail oldWidget) => false;
}

/// The scaffold of the Spoolman detail pages: a [RailScaffold] as their own page, a plain [Scaffold] when embedded in
/// the detail pane (the Spoolman page owns the rail).
class SpoolmanDetailScaffold extends StatelessWidget {
  const SpoolmanDetailScaffold({super.key, this.appBar, required this.body, this.floatingActionButton});

  final PreferredSizeWidget? appBar;

  final Widget body;

  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (EmbeddedSpoolmanDetail.of(context)) {
      // No heroes: the FAB would share the default hero tag with the Spoolman page's FAB.
      return HeroMode(
        enabled: false,
        child: Scaffold(appBar: appBar, body: body, floatingActionButton: floatingActionButton),
      );
    }
    return RailScaffold(appBar: appBar, body: body, floatingActionButton: floatingActionButton);
  }
}

mixin CommonSpoolmanDetailPagesController<State> {
  @protected
  Ref get ref;

  @protected
  String get machineUUID;

  @protected
  GoRouter get goRouterRef => ref.read(goRouterProvider);

  @protected
  SpoolmanService get spoolmanServiceRef => ref.read(spoolmanServiceProvider(machineUUID));

  @protected
  BottomSheetService get bottomSheetServiceRef => ref.read(bottomSheetServiceProvider);

  @protected
  DialogService get dialogServiceRef => ref.read(dialogServiceProvider);

  @protected
  SnackBarService get snackBarServiceRef => ref.read(snackBarServiceProvider);

  static final _detailRoutes = {
    ProRoutes.spoolman_details_spool.name,
    ProRoutes.spoolman_details_filament.name,
    ProRoutes.spoolman_details_vendor.name,
  };

  /// Whether the details are their own page (the top-most route), not embedded in the detail pane of the Spoolman page.
  /// Embedded details update the pane's selection instead of navigating.
  bool get _isOwnPage => _detailRoutes.contains(goRouterRef.state.name);

  SpoolmanDetailSelection get _paneSelection => ref.read(spoolmanDetailSelectionProvider(machineUUID).notifier);

  void onEntryTap(SpoolmanIdentifiableDtoMixin dto) async {
    // Embedded in the detail pane: entries of the type the pane (and its list) shows switch the pane, others open as
    // their own page.
    if (!_isOwnPage && ref.read(spoolmanDetailSelectionProvider(machineUUID)).runtimeType == dto.runtimeType) {
      _paneSelection.select(dto);
      return;
    }

    switch (dto) {
      case GetSpool spool:
        goRouterRef.pushNamed(ProRoutes.spoolman_details_spool.name, extra: [machineUUID, spool]);
        break;
      case GetFilament filament:
        goRouterRef.goNamed(ProRoutes.spoolman_details_filament.name, extra: [machineUUID, filament]);
        break;
      case GetVendor vendor:
        goRouterRef.pushNamed(ProRoutes.spoolman_details_vendor.name, extra: [machineUUID, vendor]);
        break;
    }
  }

  @protected
  Future<void> clone(SpoolmanIdentifiableDtoMixin entity) async {
    final route = switch (entity) {
      GetSpool() => ProRoutes.spoolman_form_spool,
      GetFilament() => ProRoutes.spoolman_form_filament,
      GetVendor() => ProRoutes.spoolman_form_vendor,
      _ => throw ArgumentError('Unknown entity type: $entity'),
    };

    final res = await goRouterRef.pushNamed(
      route.name,
      extra: [machineUUID, entity],
      queryParameters: {'isCopy': 'true'},
    );

    final (SpoolmanIdentifiableDtoMixin, ProRoutes)? copy = switch (res) {
      [GetSpool() && final newSpool, ...] => (newSpool, ProRoutes.spoolman_details_spool),
      GetFilament() && final newFilament => (newFilament, ProRoutes.spoolman_details_filament),
      GetVendor() && final newVendor => (newVendor, ProRoutes.spoolman_details_vendor),
      _ => null,
    };
    if (copy == null) return;

    if (_isOwnPage) {
      goRouterRef.replaceNamed(copy.$2.name, extra: [machineUUID, copy.$1]);
    } else {
      _paneSelection.select(copy.$1);
    }
  }

  @protected
  Future<void> delete(SpoolmanIdentifiableDtoMixin entity) async {
    var elementName = switch (entity) {
      GetSpool() => tr('pages.spoolman.spool.one'),
      GetFilament() => tr('pages.spoolman.filament.one'),
      GetVendor() => tr('pages.spoolman.vendor.one'),
      _ => throw ArgumentError('Unknown entity type: $entity'),
    };
    final ret = await dialogServiceRef.showDangerConfirm(
      title: tr('pages.spoolman.delete.confirm.title', args: [elementName]),
      body: tr('pages.spoolman.delete.confirm.body', args: [elementName]),
      actionLabel: tr('general.delete'),
    );
    if (ret?.confirmed != true) return;
    try {
      switch (entity) {
        case GetSpool():
          await spoolmanServiceRef.deleteSpool(entity);
          break;
        case GetFilament():
          await spoolmanServiceRef.deleteFilament(entity);
          break;
        case GetVendor():
          await spoolmanServiceRef.deleteVendor(entity);
          break;
        default:
          throw ArgumentError('Unknown entity type: $entity');
      }

      snackBarServiceRef.show(
        SnackBarConfig(
          title: tr('pages.spoolman.delete.success.title', args: [elementName]),
          message: tr('pages.spoolman.delete.success.message.one', args: [elementName]),
        ),
      );
      if (_isOwnPage) {
        goRouterRef.pop();
      } else {
        _paneSelection.select(null);
      }
    } catch (e) {
      snackBarServiceRef.show(
        SnackBarConfig(
          title: tr('pages.spoolman.delete.error.title', args: [elementName]),
          message: tr('pages.spoolman.delete.error.message', args: [elementName]),
        ),
      );
    }
  }
}
