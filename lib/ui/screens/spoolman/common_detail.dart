/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';

mixin CommonSpoolmanDetailPagesController<State> {
  @protected
  AutoDisposeNotifierProviderRef<State> get ref;

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

  void onEntryTap(SpoolmanIdentifiableDtoMixin dto) async {
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

    final res =
        await goRouterRef.pushNamed(route.name, extra: [machineUUID, entity], queryParameters: {'isCopy': 'true'});

    switch (res) {
      case [GetSpool() && final newSpool, ...]:
        goRouterRef.replaceNamed(ProRoutes.spoolman_details_spool.name, extra: [machineUUID, newSpool]);
        break;
      case GetFilament() && final newFilament:
        goRouterRef.replaceNamed(ProRoutes.spoolman_details_filament.name, extra: [machineUUID, newFilament]);
        break;
      case GetVendor() && final newVendor:
        goRouterRef.replaceNamed(ProRoutes.spoolman_details_vendor.name, extra: [machineUUID, newVendor]);
        break;
      default:
        // Do nothing
        break;
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

      snackBarServiceRef.show(SnackBarConfig(
        title: tr('pages.spoolman.delete.success.title', args: [elementName]),
        message: tr('pages.spoolman.delete.success.message.one', args: [elementName]),
      ));
      goRouterRef.pop();
    } catch (e) {
      snackBarServiceRef.show(SnackBarConfig(
        title: tr('pages.spoolman.delete.error.title', args: [elementName]),
        message: tr('pages.spoolman.delete.error.message', args: [elementName]),
      ));
    }
  }
}
