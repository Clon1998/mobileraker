/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/spoolman/dto/filament.dart';
import 'package:mobileraker_pro/spoolman/dto/spool.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/dto/vendor.dart';
import 'package:mobileraker_pro/ui/components/spoolman/property_with_title.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_scroll_pagination.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_static_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../routing/app_router.dart';

part 'vendor_detail_page.g.dart';

@Riverpod(dependencies: [])
Vendor _vendor(_VendorRef ref) {
  throw UnimplementedError();
}

class VendorDetailPage extends StatelessWidget {
  const VendorDetailPage({super.key, required this.machineUUID, required this.vendor});

  final String machineUUID;

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
        // Make sure we are able to access the vendor in all places
        overrides: [_vendorProvider.overrideWithValue(vendor)],
        child: _VendorDetailPage(key: Key('vd-${vendor.id}'), machineUUID: machineUUID));
  }
}

class _VendorDetailPage extends ConsumerWidget {
  const _VendorDetailPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const _AppBar(),
      // floatingActionButton: _Fab(),
      body: ListView(
        addAutomaticKeepAlives: true,
        children: [
          const _VendorInfo(),
          if (context.isCompact) ...[
            _VendorFilaments(machineUUID: machineUUID),
            _VendorSpools(machineUUID: machineUUID),
          ],
          if (context.isLargerThanCompact)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: _VendorFilaments(machineUUID: machineUUID),
                  ),
                  Flexible(
                    child: _VendorSpools(machineUUID: machineUUID),
                  ),
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
  const _AppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var vendor = ref.watch(_vendorProvider);
    return AppBar(
      title: const Text('pages.spoolman.vendor_details.page_title').tr(args: [vendor.name]),
      actions: <Widget>[
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
        //   child: MachineStateIndicator(
        //     ref.watch(selectedMachineProvider).valueOrFullNull,
        //   ),
        // ),
        // const FileSortModeSelector(),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _VendorInfo extends ConsumerWidget {
  const _VendorInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var vendor = ref.watch(_vendorProvider);
    var dateFormatService = ref.watch(dateFormatServiceProvider);
    var dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());

    var props = [
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
      if (vendor.comment != null)
        PropertyWithTitle.text(
          title: tr('pages.spoolman.properties.comment'),
          property: vendor.comment!,
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
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
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
        ],
      ),
    );
  }
}

class _VendorFilaments extends HookConsumerWidget {
  const _VendorFilaments({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_vendorDetailPageControllerProvider(machineUUID).notifier);
    var model = ref.watch(_vendorDetailPageControllerProvider(machineUUID));
    useAutomaticKeepAlive();

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('pages.spoolman.vendor_details.filaments_card').tr(),
          ),
          const Divider(),
          SpoolmanStaticPagination(
            // key: ValueKey(filters),
            machineUUID: machineUUID,
            type: SpoolmanListType.filaments,
            filters: {'vendor.id': model.id},
            onEntryTap: controller.onEntryTap,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_vendorDetailPageControllerProvider(machineUUID).notifier);
    var model = ref.watch(_vendorDetailPageControllerProvider(machineUUID));
    useAutomaticKeepAlive();

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.spoke_outlined),
            title: const Text('pages.spoolman.vendor_details.spools_card').tr(),
          ),
          const Divider(),
          SpoolmanStaticPagination(
            // key: ValueKey(filters),
            machineUUID: machineUUID,
            type: SpoolmanListType.spools,
            filters: {'filament.vendor.id': model.id},
            onEntryTap: controller.onEntryTap,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

@Riverpod(dependencies: [_vendor])
class _VendorDetailPageController extends _$VendorDetailPageController {
  @override
  Vendor build(String machineUUID) {
    var vendor = ref.watch(_vendorProvider);
    return vendor;
  }

  void onEntryTap(SpoolmanDtoMixin dto) async {
    switch (dto) {
      case Spool spool:
        ref.read(goRouterProvider).pushNamed(AppRoute.spoolman_spoolDetails.name, extra: [machineUUID, spool]);
        break;
      case Filament filament:
        ref.read(goRouterProvider).goNamed(AppRoute.spoolman_filamentDetails.name, extra: [machineUUID, filament]);
        break;
      case Vendor vendor:
        ref.read(goRouterProvider).pushNamed(AppRoute.spoolman_vendorDetails.name, extra: [machineUUID, vendor]);
        break;
    }
  }
}
