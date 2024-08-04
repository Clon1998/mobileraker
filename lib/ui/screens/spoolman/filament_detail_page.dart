/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker_pro/spoolman/dto/filament.dart';
import 'package:mobileraker_pro/spoolman/dto/spool.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/dto/vendor.dart';
import 'package:mobileraker_pro/ui/components/spoolman/property_with_title.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_scroll_pagination.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_static_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filament_detail_page.g.dart';

@Riverpod(dependencies: [])
Filament _filament(_FilamentRef ref) {
  throw UnimplementedError();
}

class FilamentDetailPage extends StatelessWidget {
  const FilamentDetailPage({super.key, required this.machineUUID, required this.filament});

  final String machineUUID;

  final Filament filament;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
        // Make sure we are able to access the vendor in all places
        overrides: [_filamentProvider.overrideWithValue(filament)],
        child: _FilamentDetailPage(key: Key('fd-${filament.id}'), machineUUID: machineUUID));
  }
}

class _FilamentDetailPage extends ConsumerWidget {
  const _FilamentDetailPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const _AppBar(),
      // floatingActionButton: _Fab(),
      body: ListView(
        children: [
          _FilamentInfo(machineUUID: machineUUID),
          // const _VendorInfo(),
          _FilamentSpools(machineUUID: machineUUID),
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
    var filament = ref.watch(_filamentProvider);
    return AppBar(
      title: Text('${filament.vendor?.name} – ${filament.name} ${filament.material}'),
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

class _FilamentInfo extends ConsumerWidget {
  const _FilamentInfo({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_filamentDetailPageControllerProvider(machineUUID).notifier);
    var filament = ref.watch(_filamentProvider);
    var dateFormatService = ref.watch(dateFormatServiceProvider);
    var dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());

    var numberFormatPrice = NumberFormat('0.##', context.locale.toStringWithSeparator());
    var numberFormatDouble =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);

    var properties = [
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.id'),
        property: filament.id.toString(),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.name'),
        property: filament.name ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.material'),
        property: filament.material ?? '-',
      ),
      GestureDetector(
        onTap: () {
          controller.onEntryTap(filament.vendor!);
        },
        child: PropertyWithTitle(
          title: plural('pages.spoolman.vendor', 1),
          property: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(FlutterIcons.external_link_faw,
                      size: (DefaultTextStyle.of(context).style.fontSize ?? 14) + 2),
                ),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: SizedBox(width: 4),
                ),
                TextSpan(
                  text: filament.vendor?.name,
                  style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.registered'),
        property: dateFormatGeneral.format(filament.registered),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.price'),
        property: filament.price?.let(numberFormatPrice.format) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.density'),
        property: '${numberFormatDouble.format(filament.density)} g/cm³',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.diameter'),
        property: '${numberFormatDouble.format(filament.diameter)} mm',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.weight'),
        property: filament.weight?.let(numberFormatDouble.formatGrams) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.spool_weight'),
        property: filament.spoolWeight?.let(numberFormatDouble.formatGrams) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.printer_edit.presets.hotend_temp'),
        property: filament.settingsExtruderTemp?.let((it) => '$it °C') ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.printer_edit.presets.bed_temp'),
        property: filament.settingsBedTemp?.let((it) => '$it °C') ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.article_number'),
        property: filament.articleNumber ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.comment'),
        property: filament.comment ?? '-',
      ),
    ];

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: SpoolWidget(
              color: filament.colorHex,
              height: 32,
            ),
            title: const Text('pages.spoolman.filament_details.info_card').tr(),
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
              itemCount: properties.length,
              itemBuilder: (BuildContext context, int index) {
                return properties[index];
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilamentSpools extends HookConsumerWidget {
  const _FilamentSpools({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_filamentDetailPageControllerProvider(machineUUID).notifier);
    var model = ref.watch(_filamentDetailPageControllerProvider(machineUUID));
    useAutomaticKeepAlive();

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.spoke_outlined),
            title: const Text('pages.spoolman.filament_details.spools_card').tr(),
          ),
          const Divider(),
          SpoolmanStaticPagination(
            // key: ValueKey(filters),
            machineUUID: machineUUID,
            type: SpoolmanListType.spools,
            filters: {'filament.id': model.id},
            onEntryTap: controller.onEntryTap,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

@Riverpod(dependencies: [_filament])
class _FilamentDetailPageController extends _$FilamentDetailPageController {
  @override
  Filament build(String machineUUID) {
    var filament = ref.watch(_filamentProvider);

    return filament;
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
