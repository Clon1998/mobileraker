/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:common/data/enums/spoolman_action_sheet_action_enum.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/misc/filament_extension.dart';
import 'package:mobileraker_pro/service/ui/pro_dialog_type.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/property_with_title.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_static_pagination.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/bottomsheet/action_bottom_sheet.dart';
import 'common_detail.dart';

part 'spool_detail_page.freezed.dart';
part 'spool_detail_page.g.dart';

@Riverpod(dependencies: [])
GetSpool _spool(Ref ref) {
  throw UnimplementedError();
}

class SpoolDetailPage extends StatelessWidget {
  const SpoolDetailPage({super.key, required this.machineUUID, required this.spool});

  final String machineUUID;
  final GetSpool spool;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      // Make sure we are able to access the vendor in all places
      overrides: [_spoolProvider.overrideWithValue(spool)],
      child: _SpoolDetailPage(key: Key('spd-${spool.id}'), machineUUID: machineUUID),
    );
  }
}

class _SpoolDetailPage extends ConsumerWidget {
  const _SpoolDetailPage({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numFormat = NumberFormat.compact(locale: context.locale.toStringWithSeparator());
    final themeData = Theme.of(context);

    final spool = ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spool));
    final controller = ref.watch(_spoolDetailPageControllerProvider(machineUUID).notifier);
    final sameFilamentSpoolList = _SpoolList(
      key: Key('sameFil-${spool.id}'),
      machineUUID: machineUUID,
      titleBuilder: (ctx, total) => ListTile(
        leading: const Icon(Icons.color_lens_outlined),
        title: const Text('pages.spoolman.spool_details.alternative_spool.same_filament').tr(),
        trailing: total != null && total > 0
            ? Chip(
                visualDensity: VisualDensity.compact,
                label: Text(numFormat.format(total)),
                labelStyle: TextStyle(color: themeData.colorScheme.onSecondary),
                backgroundColor: themeData.colorScheme.secondary,
              )
            : null,
      ),
      filters: {'filament.id': spool.filament.id},
    );
    final sameMaterialSpoolList = _SpoolList(
      key: Key('sameMat-${spool.id}'),
      machineUUID: machineUUID,
      titleBuilder: (ctx, total) => ListTile(
        leading: const Icon(Icons.spoke_outlined),
        title: const Text('pages.spoolman.spool_details.alternative_spool.same_material').tr(),
        trailing: total != null && total > 0
            ? Chip(
                visualDensity: VisualDensity.compact,
                label: Text(numFormat.format(total)),
                labelStyle: TextStyle(color: themeData.colorScheme.onSecondary),
                backgroundColor: themeData.colorScheme.secondary,
              )
            : null,
      ),
      filters: {'filament.material': spool.filament.material},
    );
    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final box = context.findRenderObject() as RenderBox?;
          final pos = box!.localToGlobal(Offset.zero) & box.size;

          controller.onAction(Theme.of(context), pos);
        },
        child: const Icon(Icons.more_vert),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            WarningCard(
              show: spool.archived,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              leadingIcon: const Icon(Icons.archive),
              // leadingIcon: Icon(Icons.layers_clear),
              title: const Text('pages.spoolman.spool_details.archived_warning.title').tr(),
              subtitle: const Text('pages.spoolman.spool_details.archived_warning.body').tr(),
            ),
            _SpoolInfo(machineUUID: machineUUID),
            if (context.isCompact) ...[
              sameFilamentSpoolList,
              sameMaterialSpoolList,
            ],
            if (context.isLargerThanCompact)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(child: sameMaterialSpoolList),
                    Flexible(child: sameFilamentSpoolList),
                  ],
                ),
              ),
          ],
        ),
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
    final spool = ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spool));

    final title = [
      if (spool.filament.vendor != null) spool.filament.vendor!.name,
      spool.filament.name,
    ].join(' – ');
    return AppBar(title: const Text('pages.spoolman.spool_details.page_title').tr(args: [title]));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SpoolInfo extends ConsumerWidget {
  const _SpoolInfo({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spoolmanCurrency = ref.watch(spoolmanCurrencyProvider(machineUUID));
    final controller = ref.watch(_spoolDetailPageControllerProvider(machineUUID).notifier);
    final spool = ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spool));
    final dateFormatService = ref.watch(dateFormatServiceProvider);
    final dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());

    final numberFormatDouble =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);
    final numberFormatPrice =
        NumberFormat.simpleCurrency(locale: context.locale.toStringWithSeparator(), name: spoolmanCurrency);

    final hasVendor = spool.filament.vendor != null;
    final properties = [
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.id'),
        property: spool.id.toString(),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.registered'),
        property: dateFormatGeneral.format(spool.registered),
      ),
      GestureDetector(
        onTap: () {
          controller.onEntryTap(spool.filament.vendor!);
        }.only(hasVendor),
        child: PropertyWithTitle(
          title: plural('pages.spoolman.vendor', 1),
          property: Text.rich(
            TextSpan(
              children: [
                if (hasVendor) ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(FlutterIcons.external_link_faw,
                        size: (DefaultTextStyle.of(context).style.fontSize ?? 14) + 2),
                  ),
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: SizedBox(width: 4),
                  ),
                ],
                TextSpan(
                  text: spool.filament.vendor?.name ?? '–',
                  style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline)
                      .only(hasVendor),
                ),
              ],
            ),
          ),
        ),
      ),
      GestureDetector(
        onTap: () {
          controller.onEntryTap(spool.filament);
        },
        child: PropertyWithTitle(
          title: plural('pages.spoolman.filament', 1),
          property: Text.rich(
            TextSpan(
              children: [
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
                TextSpan(
                  text:
                      '${spool.filament.name ?? tr('pages.spoolman.filament.one')}${spool.filament.material != null ? ' (${spool.filament.material})' : ''}',
                  style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.diameter'),
        property: spool.filament.diameter.let(numberFormatDouble.formatMillimeters),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.price'),
        property: (spool.price ?? spool.filament.price)?.let(numberFormatPrice.format) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.first_used'),
        property: spool.firstUsed?.let(dateFormatGeneral.format) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.last_used'),
        property: spool.lastUsed?.let(dateFormatGeneral.format) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.remaining_weight'),
        property: spool.remainingWeight?.let(numberFormatDouble.formatGrams) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.used_weight'),
        property: numberFormatDouble.formatGrams(spool.usedWeight),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.remaining_length'),
        property: spool.remainingLength?.let(numberFormatDouble.formatMillimeters) ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.used_length'),
        property: spool.usedLength.let(numberFormatDouble.formatMillimeters),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.location'),
        property: spool.location ?? '–',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.lot_number'),
        property: spool.lotNr ?? '–',
      ),
    ];

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: SpoolWidget(
              color: spool.filament.colorHex,
              height: 32,
              // width: 15,
            ),
            title: const Text('pages.spoolman.spool_details.info_card').tr(),
            trailing: Consumer(
              builder: (context, ref, child) {
                final themeData = Theme.of(context);
                final isActive =
                    ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spoolIsActive));

                return AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  child: isActive
                      ? Chip(
                          key: const Key('active_chip'),
                          label: const Text('Spool is Active'),
                          backgroundColor: themeData.colorScheme.primary,
                          labelStyle: TextStyle(color: themeData.colorScheme.onPrimary),
                        )
                      : const SizedBox.shrink(key: Key('inactive_spool_chip')),
                );
              },
            ),
          ),
          if (spool.progress != null)
            LinearProgressIndicator(
              backgroundColor: spool.filament.color,
              value: spool.progress,
            ),
          if (spool.progress == null) const Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
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
              property: spool.comment ?? '–',
            ),
          ),
        ],
      ),
    );
  }
}

class _SpoolList extends ConsumerWidget {
  const _SpoolList({super.key, required this.machineUUID, required this.titleBuilder, required this.filters});

  final String machineUUID;
  final Widget Function(BuildContext context, int? total) titleBuilder;
  final Map<String, dynamic>? filters;

  static const _initial = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // useAutomaticKeepAlive();
    final spool = ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spool));

    final totalItems = ref.watch(spoolListProvider(machineUUID, pageSize: _initial, page: 0, filters: filters)
        .select((d) => d.valueOrNull?.totalItems?.let((d) => max(d - 1, 0))));

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          titleBuilder(context, totalItems),
          const Divider(),
          Flexible(
            child: SpoolmanStaticPagination(
              // key: ValueKey(filters),
              initialCount: _initial,
              machineUUID: machineUUID,
              type: SpoolmanListType.spools,
              exclude: spool,
              filters: filters,
              onEntryTap: ref.read(_spoolDetailPageControllerProvider(machineUUID).notifier).onEntryTap,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

@Riverpod(dependencies: [_spool])
class _SpoolDetailPageController extends _$SpoolDetailPageController with CommonSpoolmanDetailPagesController<_Model> {
  @override
  _Model build(String machineUUID) {
    final initialSpool = ref.watch(_spoolProvider);
    final fetchedSpool = ref.watch(spoolProvider(machineUUID, initialSpool.id));
    final activeSpool = ref.watch(activeSpoolProvider(machineUUID));

    return _Model(
      initialSpool: initialSpool,
      fetchedSpool: fetchedSpool,
      spoolIsActive: activeSpool.valueOrNull?.id == (fetchedSpool.valueOrNull?.id ?? initialSpool.id),
    );
  }

  @override
  bool updateShouldNotify(_Model prev, _Model next) {
    return prev != next;
  }

  void onAction(ThemeData themeData, Rect pos) async {
    final spool = state.spool;
    final isActive = state.spoolIsActive;

    final metaTags = [
      if (spool.filament.vendor != null) spool.filament.vendor!.name,
      if (spool.filament.material != null) spool.filament.material,
    ];

    final res = await bottomSheetServiceRef.show(BottomSheetConfig(
      type: SheetType.actions,
      isScrollControlled: true,
      data: ActionBottomSheetArgs(
        title: RichText(
          text: TextSpan(
            text: '#${spool.id} ',
            style: themeData.textTheme.titleSmall
                ?.copyWith(fontSize: themeData.textTheme.titleSmall?.fontSize?.let((it) => it - 2)),
            children: [
              TextSpan(text: '${spool.filament.name}', style: themeData.textTheme.titleSmall),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(metaTags.isEmpty ? tr('pages.spoolman.spool.one') : metaTags.join(' – '),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: SpoolWidget(color: spool.filament.colorHex, height: 33, width: 15),
        actions: [
          if (!isActive) SpoolSpoolmanSheetAction.activate,
          if (isActive) SpoolSpoolmanSheetAction.deactivate,
          SpoolSpoolmanSheetAction.edit,
          SpoolSpoolmanSheetAction.clone,
          SpoolSpoolmanSheetAction.adjustFilament,
          SpoolSpoolmanSheetAction.shareQrCode,
          if (!spool.archived) SpoolSpoolmanSheetAction.archive,
          if (spool.archived) SpoolSpoolmanSheetAction.unarchive,
          SpoolSpoolmanSheetAction.delete,
        ],
      ),
    ));

    if (!res.confirmed) return;
    logger.i('[SpoolDetailPage] Action: ${res.data}');

    // Wait for the bottom sheet to close
    await Future.delayed(kThemeAnimationDuration);
    switch (res.data) {
      case SpoolSpoolmanSheetAction.shareQrCode:
        _generateAndShareQrCode(pos);
        break;
      case SpoolSpoolmanSheetAction.edit:
        goRouterRef.pushNamed(ProRoutes.spoolman_form_spool.name, extra: [machineUUID, spool]);
        break;
      case SpoolSpoolmanSheetAction.clone:
        clone(state.spool);
        break;
      case SpoolSpoolmanSheetAction.adjustFilament:
        _adjustFilament();
        break;
      case SpoolSpoolmanSheetAction.delete:
        delete(state.spool);
        break;
      case SpoolSpoolmanSheetAction.activate:
        spoolmanServiceRef.setActiveSpool(spool);
        break;
      case SpoolSpoolmanSheetAction.deactivate:
        spoolmanServiceRef.clearActiveSpool();
        break;
      case SpoolSpoolmanSheetAction.archive:
        spoolmanServiceRef.archiveSpool(spool);
        break;
      case SpoolSpoolmanSheetAction.unarchive:
        spoolmanServiceRef.archiveSpool(spool, false);
        break;
    }
  }

  Future<void> _generateAndShareQrCode(Rect origin) async {
    try {
      final spool = state.spool;
      final qrData = 'web+spoolman:s-${spool.id}';

      logger.i('Generating QR Code for spool ${spool.id} with data: $qrData');

      final qrCode = QrCode.fromData(
        data: qrData,
        errorCorrectLevel: QrErrorCorrectLevel.H,
      );

      final qrImage = QrImage(qrCode);
      final qrImageBytes = await qrImage.toImageAsBytes(
        size: 512,
        format: ImageByteFormat.png,
        decoration: const PrettyQrDecoration(
          image: PrettyQrDecorationImage(image: AssetImage('assets/icon/mr_logo.png')),
        ),
      );
      final bytes = Uint8List.sublistView(qrImageBytes!);

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'spoolman-sID_${spool.id}.png')],
        subject: 'Spool QR',
        sharePositionOrigin: origin,
      );
    } catch (e, s) {
      logger.e('Error while generating and sharing QR Code', e, s);
      snackBarServiceRef.show(SnackBarConfig.stacktraceDialog(
        dialogService: dialogServiceRef,
        snackTitle: 'Unexpected Error',
        snackMessage: 'An unexpected error occurred while generating the QR Code. Please try again.',
        exception: e,
        stack: s,
      ));
    }
  }

  Future<void> _adjustFilament() async {
    final spool = state.spool;

    // Open dialog to select the amount to consume
    final res = await dialogServiceRef.show(DialogRequest(type: ProDialogType.consumeSpool));

    if (res?.confirmed != true) return;
    try {
      switch (res?.data) {
        case (num() && final amount, 'mm'):
          logger.i('Consuming $amount mm of filament');
          await spoolmanServiceRef.adjustFilamentOnSpool(spool: spool, length: amount.toDouble());
          break;
        case (num() && final amount, 'g'):
          logger.i('Consuming $amount g of filament');
          await spoolmanServiceRef.adjustFilamentOnSpool(spool: spool, weight: amount.toDouble());
          break;
      }
      // required to wait for rebuild of provider...
      // await Future.delayed(Duration(milliseconds: 250));

      snackBarServiceRef.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.update.success.title', args: [tr('pages.spoolman.spool.one')]),
        message: tr('pages.spoolman.update.success.message', args: [tr('pages.spoolman.spool.one')]),
      ));
    } catch (e, s) {
      logger.e('Error while adjusting filament on spool', e, s);
      snackBarServiceRef.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.update.error.title', args: [tr('pages.spoolman.spool.one')]),
        message: tr('pages.spoolman.update.error.message'),
      ));
    }
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required GetSpool initialSpool,
    required AsyncValue<GetSpool?> fetchedSpool,
    @Default(false) bool spoolIsActive,
  }) = __Model;

  GetSpool get spool => fetchedSpool.valueOrNull ?? initialSpool;
}
