/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/spoolman_action_sheet_action_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/property_with_title.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_static_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/action_bottom_sheet.dart';
import 'common_detail.dart';

part 'vendor_detail_page.g.dart';

@Riverpod(dependencies: [])
GetVendor _vendor(Ref ref) {
  throw UnimplementedError();
}

class VendorDetailPage extends StatelessWidget {
  const VendorDetailPage({super.key, required this.machineUUID, required this.vendor});

  final String machineUUID;

  final GetVendor vendor;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [_vendorProvider.overrideWithValue(vendor)],
      child: _VendorDetailPage(key: Key('vd-${vendor.id}'), machineUUID: machineUUID),
    );
  }
}

class _VendorDetailPage extends ConsumerWidget {
  const _VendorDetailPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_vendorDetailPageControllerProvider(machineUUID).notifier);
    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.onAction(Theme.of(context)),
        child: const Icon(Icons.more_vert),
      ),
      body: ListView(
        addAutomaticKeepAlives: true,
        children: [
          _VendorInfo(machineUUID: machineUUID),
          if (context.isCompact) ...[
            _VendorFilaments(machineUUID: machineUUID),
            _VendorSpools(machineUUID: machineUUID),
          ],
          if (context.isLargerThanCompact)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(child: _VendorFilaments(machineUUID: machineUUID)),
                  Flexible(child: _VendorSpools(machineUUID: machineUUID)),
                ],
              ),
            ),
        ],
      ),
      // body: _SpoolTab(),
    );
  }
}

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(_vendorDetailPageControllerProvider(machineUUID));
    return AppBar(
      title: const Text('pages.spoolman.vendor_details.page_title').tr(args: [vendor.name]),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _VendorInfo extends ConsumerWidget {
  const _VendorInfo({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(_vendorDetailPageControllerProvider(machineUUID));
    final dateFormatService = ref.watch(dateFormatServiceProvider);
    final dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());

    final numberFormatDouble =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);

    final props = [
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.id'),
        property: vendor.id.toString(),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.name'),
        property: vendor.name,
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.registered'),
        property: dateFormatGeneral.format(vendor.registered),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.spool_weight'),
        property: vendor.spoolWeight?.let(numberFormatDouble.formatGrams) ?? '–',
      ),
    ];

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.factory_outlined),
            title: const Text('pages.spoolman.vendor_details.info_card').tr(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0),
            child: AlignedGridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
              itemCount: props.length,
              itemBuilder: (BuildContext context, int index) {
                return props[index];
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8) - const EdgeInsets.only(top: 8),
            child: PropertyWithTitle.text(
              title: tr('pages.spoolman.properties.comment'),
              property: vendor.comment ?? '–',
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorFilaments extends HookConsumerWidget {
  const _VendorFilaments({super.key, required this.machineUUID});

  final String machineUUID;

  static const _initial = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_vendorDetailPageControllerProvider(machineUUID).notifier);
    var model = ref.watch(_vendorDetailPageControllerProvider(machineUUID));
    useAutomaticKeepAlive();

    var filter = {'vendor.id': model.id};
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(builder: (context, ref, _) {
            final themeData = Theme.of(context);
            final numFormat = NumberFormat.compact(locale: context.locale.toStringWithSeparator());
            final total = ref.watch(filamentListProvider(machineUUID, pageSize: _initial, page: 0, filters: filter)
                .select((d) => d.valueOrNull?.totalItems));
            return ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: const Text('pages.spoolman.vendor_details.filaments_card').tr(),
              trailing: total != null && total > 0
                  ? Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(numFormat.format(total)),
                      labelStyle: TextStyle(color: themeData.colorScheme.onSecondary),
                      backgroundColor: themeData.colorScheme.secondary,
                    )
                  : null,
            );
          }),
          const Divider(),
          Flexible(
            child: SpoolmanStaticPagination(
              machineUUID: machineUUID,
              type: SpoolmanListType.filaments,
              filters: filter,
              initialCount: _initial,
              onEntryTap: controller.onEntryTap,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VendorSpools extends HookConsumerWidget {
  const _VendorSpools({super.key, required this.machineUUID});

  final String machineUUID;

  static const _initial = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_vendorDetailPageControllerProvider(machineUUID).notifier);
    var model = ref.watch(_vendorDetailPageControllerProvider(machineUUID));
    useAutomaticKeepAlive();

    final filters = {'filament.vendor.id': model.id};

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(builder: (context, ref, _) {
            final themeData = Theme.of(context);
            final numFormat = NumberFormat.compact(locale: context.locale.toStringWithSeparator());
            final total = ref.watch(spoolListProvider(machineUUID, pageSize: _initial, page: 0, filters: filters)
                .select((d) => d.valueOrNull?.totalItems));
            return ListTile(
              leading: const Icon(Icons.spoke_outlined),
              title: const Text('pages.spoolman.vendor_details.spools_card').tr(),
              trailing: total != null && total > 0
                  ? Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(numFormat.format(total)),
                      labelStyle: TextStyle(color: themeData.colorScheme.onSecondary),
                      backgroundColor: themeData.colorScheme.secondary,
                    )
                  : null,
            );
          }),
          const Divider(),
          Flexible(
            child: SpoolmanStaticPagination(
              // key: ValueKey(filters),
              machineUUID: machineUUID,
              type: SpoolmanListType.spools,
              filters: filters,
              onEntryTap: controller.onEntryTap,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

@Riverpod(dependencies: [_vendor])
class _VendorDetailPageController extends _$VendorDetailPageController
    with CommonSpoolmanDetailPagesController<GetVendor> {
  @override
  GetVendor build(String machineUUID) {
    final initial = ref.watch(_vendorProvider);
    final fetched = ref.watch(vendorProvider(machineUUID, initial.id));

    return fetched.valueOrNull ?? initial;
  }

  @override
  bool updateShouldNotify(GetVendor prev, GetVendor next) {
    return prev != next;
  }

  void onAction(ThemeData themeData) async {
    final res = await bottomSheetServiceRef.show(BottomSheetConfig(
      type: SheetType.actions,
      isScrollControlled: true,
      data: ActionBottomSheetArgs(
        title: RichText(
          text: TextSpan(
            text: '#${state.id} ',
            style: themeData.textTheme.titleSmall
                ?.copyWith(fontSize: themeData.textTheme.titleSmall?.fontSize?.let((it) => it - 2)),
            children: [
              TextSpan(text: '${state.name}', style: themeData.textTheme.titleSmall),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(tr('pages.spoolman.vendor.one'), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          VendorSpoolmanSheetAction.addFilament,
          DividerSheetAction.divider,
          VendorSpoolmanSheetAction.edit,
          VendorSpoolmanSheetAction.clone,
          VendorSpoolmanSheetAction.delete,
        ],
      ),
    ));

    if (!res.confirmed) return;
    logger.i('[VendorDetailPage] Action: ${res.data}');

    // Wait for the bottom sheet to close
    await Future.delayed(kThemeAnimationDuration);
    switch (res.data) {
      case VendorSpoolmanSheetAction.edit:
        goRouterRef.pushNamed(ProRoutes.spoolman_form_vendor.name, extra: [machineUUID, state]);
        break;
      case VendorSpoolmanSheetAction.addFilament:
        goRouterRef.pushNamed(ProRoutes.spoolman_form_filament.name, extra: [machineUUID, state]);
        break;
      case VendorSpoolmanSheetAction.clone:
        clone(state);
        break;
      case VendorSpoolmanSheetAction.delete:
        delete(state);
        break;
    }
  }
}
