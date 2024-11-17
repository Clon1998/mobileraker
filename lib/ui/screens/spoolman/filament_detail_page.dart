/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/spoolman_action_sheet_action_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/property_with_title.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_static_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/action_bottom_sheet.dart';
import 'common_detail.dart';

part 'filament_detail_page.g.dart';

@Riverpod(dependencies: [])
GetFilament _filament(Ref ref) {
  throw UnimplementedError();
}

class FilamentDetailPage extends StatelessWidget {
  const FilamentDetailPage({super.key, required this.machineUUID, required this.filament});

  final String machineUUID;

  final GetFilament filament;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [_filamentProvider.overrideWithValue(filament)],
      child: _FilamentDetailPage(key: Key('fd-${filament.id}'), machineUUID: machineUUID),
    );
  }
}

class _FilamentDetailPage extends ConsumerWidget {
  const _FilamentDetailPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_filamentDetailPageControllerProvider(machineUUID).notifier);
    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.onAction(Theme.of(context)),
        child: const Icon(Icons.more_vert),
      ),
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
  const _AppBar({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var filament = ref.watch(_filamentDetailPageControllerProvider(machineUUID));
    // pages.spoolman.filament.one
    var title = [
      if (filament.vendor != null) filament.vendor!.name,
      filament.name,
    ].join(' – ');

    if (filament.material != null) {
      title += ' (${filament.material})';
    }

    return AppBar(title: Text(title));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _FilamentInfo extends ConsumerWidget {
  const _FilamentInfo({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spoolmanCurrency = ref.watch(spoolmanCurrencyProvider(machineUUID));
    final controller = ref.watch(_filamentDetailPageControllerProvider(machineUUID).notifier);
    final filament = ref.watch(_filamentDetailPageControllerProvider(machineUUID));
    final dateFormatService = ref.watch(dateFormatServiceProvider);
    final dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());

    final numberFormatPrice =
        NumberFormat.simpleCurrency(locale: context.locale.toStringWithSeparator(), name: spoolmanCurrency);
    final numberFormatDouble =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);

    final hasVendor = filament.vendor != null;
    final properties = [
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.id'),
        property: filament.id.toString(),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.name'),
        property: filament.name ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.material'),
        property: filament.material ?? '–',
      ),
      GestureDetector(
        onTap: () {
          controller.onEntryTap(filament.vendor!);
        }.only(hasVendor),
        child: PropertyWithTitle(
          title: plural('pages.spoolman.vendor', 1),
          property: Text.rich(
            TextSpan(
              children: [
                if (hasVendor) ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      FlutterIcons.external_link_faw,
                      size: (DefaultTextStyle.of(context).style.fontSize ?? 14) + 2,
                    ),
                  ),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: SizedBox(width: 4),
                  ),
                ],
                TextSpan(
                  text: filament.vendor?.name ?? '–',
                  style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline)
                      .only(hasVendor),
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
        property: filament.price?.let(numberFormatPrice.format) ?? '–',
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
        property: filament.weight?.let(numberFormatDouble.formatGrams) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.spool_weight'),
        property: filament.spoolWeight?.let(numberFormatDouble.formatGrams) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.printer_edit.presets.hotend_temp'),
        property: filament.settingsExtruderTemp?.let((it) => '$it °C') ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.printer_edit.presets.bed_temp'),
        property: filament.settingsBedTemp?.let((it) => '$it °C') ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.article_number'),
        property: filament.articleNumber ?? '–',
      ),
    ];

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: SpoolWidget(color: filament.colorHex, height: 32),
            title: const Text('pages.spoolman.filament_details.info_card').tr(),
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
              itemCount: properties.length,
              itemBuilder: (BuildContext context, int index) {
                return properties[index];
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8) - const EdgeInsets.only(top: 8),
            child: PropertyWithTitle.text(
              title: tr('pages.spoolman.properties.comment'),
              property: filament.comment ?? '–',
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

  static const _initial = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_filamentDetailPageControllerProvider(machineUUID).notifier);
    final model = ref.watch(_filamentDetailPageControllerProvider(machineUUID).select((d) => d.id));
    useAutomaticKeepAlive();

    final filter = {'filament.id': model};
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer(builder: (context, ref, _) {
            final themeData = Theme.of(context);
            final numFormat = NumberFormat.compact(locale: context.locale.toStringWithSeparator());
            final total = ref.watch(spoolListProvider(machineUUID, pageSize: _initial, page: 0, filters: filter)
                .select((d) => d.valueOrNull?.totalItems));
            return ListTile(
              leading: const Icon(Icons.spoke_outlined),
              title: const Text('pages.spoolman.filament_details.spools_card').tr(),
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
              initialCount: _initial,
              type: SpoolmanListType.spools,
              filters: filter,
              onEntryTap: controller.onEntryTap,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

@Riverpod(dependencies: [_filament])
class _FilamentDetailPageController extends _$FilamentDetailPageController
    with CommonSpoolmanDetailPagesController<GetFilament> {
  @override
  GetFilament build(String machineUUID) {
    final initial = ref.watch(_filamentProvider);
    final fetched = ref.watch(filamentProvider(machineUUID, initial.id));

    return fetched.valueOrNull ?? initial;
  }

  @override
  bool updateShouldNotify(GetFilament prev, GetFilament next) {
    return prev != next;
  }

  void onAction(ThemeData themeData) async {
    final metaTags = [
      if (state.vendor != null) state.vendor!.name,
      if (state.material != null) state.material,
    ];

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
        subtitle: Text(metaTags.isEmpty ? tr('pages.spoolman.filament.one') : metaTags.join(' – '),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: SpoolWidget(color: state.colorHex, height: 33, width: 15),
        actions: [
          FilamentSpoolmanSheetAction.addSpool,
          DividerSheetAction.divider,
          FilamentSpoolmanSheetAction.edit,
          FilamentSpoolmanSheetAction.clone,
          FilamentSpoolmanSheetAction.delete,
        ],
      ),
    ));

    if (!res.confirmed) return;
    logger.i('[FilamentDetailPage] Selected action: ${res.data}');

    // Wait for the bottom sheet to close
    await Future.delayed(kThemeAnimationDuration);
    switch (res.data) {
      case FilamentSpoolmanSheetAction.edit:
        goRouterRef.pushNamed(ProRoutes.spoolman_form_filament.name, extra: [machineUUID, state]);
        break;
      case FilamentSpoolmanSheetAction.addSpool:
        goRouterRef.pushNamed(ProRoutes.spoolman_form_spool.name, extra: [machineUUID, state]);
        break;
      case FilamentSpoolmanSheetAction.clone:
        clone(state);
        break;
      case FilamentSpoolmanSheetAction.delete:
        delete(state);
        break;
    }
  }
}
