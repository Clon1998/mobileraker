/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:typed_data';
import 'dart:ui';

import 'package:common/data/enums/spoolman_action_sheet_action_enum.dart';
import 'package:common/service/app_router.dart';
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
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/misc/filament_extension.dart';
import 'package:mobileraker_pro/service/moonraker/spoolman_service.dart';
import 'package:mobileraker_pro/service/ui/pro_dialog_type.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/ui/components/spoolman/property_with_title.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_scroll_pagination.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_static_pagination.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../routing/app_router.dart';
import '../../components/bottomsheet/action_bottom_sheet.dart';

part 'spool_detail_page.freezed.dart';
part 'spool_detail_page.g.dart';

@Riverpod(dependencies: [])
GetSpool _spool(_SpoolRef ref) {
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
    final spool = ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spool));
    final controller = ref.watch(_spoolDetailPageControllerProvider(machineUUID).notifier);
    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final box = context.findRenderObject() as RenderBox?;
          final pos = box!.localToGlobal(Offset.zero) & box.size;

          controller.onAction(Theme.of(context), pos);
        },
        child: const Icon(Icons.menu),
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
              _SpoolList(
                key: Key('sameMat-${spool.id}'),
                machineUUID: machineUUID,
                title: const ListTile(
                  leading: Icon(Icons.spoke_outlined),
                  title: Text('Alternative Spools (Same Material)'),
                ),
                filters: {'filament.material': spool.filament.material},
              ),
              _SpoolList(
                key: Key('sameFil-${spool.id}'),
                machineUUID: machineUUID,
                title: const ListTile(
                  leading: Icon(Icons.color_lens_outlined),
                  title: Text('Alternative Spools (Same Filament)'),
                ),
                filters: {'filament.id': spool.filament.id},
              ),
            ],
            if (context.isLargerThanCompact)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: _SpoolList(
                        key: Key('sameMat-${spool.id}'),
                        machineUUID: machineUUID,
                        title: const ListTile(
                          leading: Icon(Icons.spoke_outlined),
                          title: Text('Alternative Spools (Same Material)'),
                        ),
                        filters: {'filament.material': spool.filament.material},
                      ),
                    ),
                    Flexible(
                      child: _SpoolList(
                        key: Key('sameFil-${spool.id}'),
                        machineUUID: machineUUID,
                        title: const ListTile(
                          leading: Icon(Icons.color_lens_outlined),
                          title: Text('Alternative Spools (Same Filament)'),
                        ),
                        filters: {'filament.id': spool.filament.id},
                      ),
                    ),
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

    var properties = [
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
                  text: spool.filament.vendor?.name,
                  style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
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
                  text: '${spool.filament.name} (${spool.filament.material})',
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
        property: (spool.price ?? spool.filament.price)?.let(numberFormatPrice.format) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.first_used'),
        property: spool.firstUsed?.let(dateFormatGeneral.format) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.last_used'),
        property: spool.lastUsed?.let(dateFormatGeneral.format) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.remaining_weight'),
        property: spool.remainingWeight?.let(numberFormatDouble.formatGrams) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.used_weight'),
        property: numberFormatDouble.formatGrams(spool.usedWeight),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.remaining_length'),
        property: spool.remainingLength?.let(numberFormatDouble.formatMillimeters) ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.used_length'),
        property: spool.usedLength.let(numberFormatDouble.formatMillimeters),
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.location'),
        property: spool.location ?? '-',
      ),
      PropertyWithTitle.text(
        title: tr('pages.spoolman.properties.lot_number'),
        property: spool.lotNr ?? '-',
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
              property: spool.comment ?? '-',
            ),
          ),
        ],
      ),
    );
  }
}

class _SpoolList extends HookConsumerWidget {
  const _SpoolList({super.key, required this.machineUUID, required this.title, required this.filters});

  final String machineUUID;
  final Widget title;
  final Map<String, dynamic>? filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // useAutomaticKeepAlive();
    final spool = ref.watch(_spoolDetailPageControllerProvider(machineUUID).select((data) => data.spool));

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          title,
          const Divider(),
          Flexible(
            child: SpoolmanStaticPagination(
              key: ValueKey(filters),
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
class _SpoolDetailPageController extends _$SpoolDetailPageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  _Model build(String machineUUID) {
    final initialSpool = ref.watch(_spoolProvider);
    final fetchedSpool = ref.watch(spoolProvider(machineUUID, initialSpool.id));
    final activeSpool = ref.watch(activeSpoolProvider(machineUUID));

    // ref.listenSelf((prev, next) {
    //   if (next.fetchedSpool case AsyncValue(value: null, hasValue: true)) {
    //     logger.w('Spool with ID ${next.initialSpool.id} not found on machine $machineUUID');
    //     _goRouter.pop();
    //   }
    // });

    return _Model(
      initialSpool: initialSpool,
      fetchedSpool: fetchedSpool,
      spoolIsActive: activeSpool.valueOrNull?.id == (fetchedSpool.valueOrNull?.id ?? initialSpool.id),
    );
  }

  void onEntryTap(SpoolmanIdentifiableDtoMixin dto) {
    switch (dto) {
      case GetSpool spool:
        _goRouter.goNamed(AppRoute.spoolman_details_spool.name, extra: [machineUUID, spool]);
        break;
      case GetFilament filament:
        _goRouter.pushNamed(AppRoute.spoolman_details_filament.name, extra: [machineUUID, filament]);
        break;
      case GetVendor vendor:
        _goRouter.pushNamed(AppRoute.spoolman_details_vendor.name, extra: [machineUUID, vendor]);
        break;
    }
  }

  void onAction(ThemeData themeData, Rect pos) async {
    final spool = state.spool;
    final isActive = state.spoolIsActive;

    final res = await _bottomSheetService.show(BottomSheetConfig(
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
        subtitle: Text(
          '${spool.filament.vendor?.name} – ${spool.filament.material}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: SpoolWidget(
          color: spool.filament.colorHex,
          height: 33,
          width: 15,
        ),
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
        _goRouter.pushNamed(AppRoute.spoolman_form_spool.name, extra: [machineUUID, spool]);
        break;
      case SpoolSpoolmanSheetAction.clone:
        _cloneSpool();
        break;
      case SpoolSpoolmanSheetAction.adjustFilament:
        _adjustFilament();
        break;
      case SpoolSpoolmanSheetAction.delete:
        _deleteSpool();
        break;
      case SpoolSpoolmanSheetAction.activate:
        _spoolmanService.setActiveSpool(spool);
        break;
      case SpoolSpoolmanSheetAction.deactivate:
        _spoolmanService.clearActiveSpool();
        break;
      case SpoolSpoolmanSheetAction.archive:
        _spoolmanService.archiveSpool(spool);
        break;
      case SpoolSpoolmanSheetAction.unarchive:
        _spoolmanService.archiveSpool(spool, false);
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
      ).catchError((_) => null);
    } catch (e, s) {
      logger.e('Error while generating and sharing QR Code', e, s);
      _snackBarService.show(SnackBarConfig.stacktraceDialog(
        dialogService: _dialogService,
        snackTitle: 'Unexpected Error',
        snackMessage: 'An unexpected error occurred while generating the QR Code. Please try again.',
        exception: e,
        stack: s,
      ));
    }
  }

  Future<void> _cloneSpool() async {
    final spool = state.spool;
    final res = await _goRouter
        .pushNamed(AppRoute.spoolman_form_spool.name, extra: [machineUUID, spool], queryParameters: {'isCopy': 'true'});
    if (res == null) return;
    if (res case [GetSpool() && final newSpool, ...]) {
      _goRouter.replaceNamed(AppRoute.spoolman_details_spool.name, extra: [machineUUID, newSpool]);
    }
  }

  Future<void> _adjustFilament() async {
    final spool = state.spool;

    // Open dialog to select the amount to consume
    final res = await _dialogService.show(DialogRequest(type: ProDialogType.consumeSpool));

    if (res?.confirmed != true) return;
    try {
      switch (res?.data) {
        case (num() && final amount, 'mm'):
          logger.i('Consuming $amount mm of filament');
          await _spoolmanService.adjustFilamentOnSpool(spool: spool, length: amount.toDouble());
          break;
        case (num() && final amount, 'g'):
          logger.i('Consuming $amount g of filament');
          await _spoolmanService.adjustFilamentOnSpool(spool: spool, weight: amount.toDouble());
          break;
      }
      // required to wait for rebuild of provider...
      // await Future.delayed(Duration(milliseconds: 250));

      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.info,
        title: tr('pages.spoolman.update.success.title', args: [tr('pages.spoolman.spool.one')]),
        message: tr('pages.spoolman.update.success.message', args: [tr('pages.spoolman.spool.one')]),
      ));
    } catch (e, s) {
      logger.e('Error while adjusting filament on spool', e, s);
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: tr('pages.spoolman.update.error.title', args: [tr('pages.spoolman.spool.one')]),
        message: tr('pages.spoolman.update.error.message'),
      ));
    }
  }

  Future<void> _deleteSpool() async {
    final spool = state.spool;
    final ret = await _dialogService.showDangerConfirm(
      title: tr('pages.spoolman.delete.confirm.title', args: [tr('pages.spoolman.spool.one')]),
      body: tr('pages.spoolman.delete.confirm.body', args: [tr('pages.spoolman.spool.one')]),
      actionLabel: tr('general.delete'),
    );
    if (ret?.confirmed != true) return;
    await _spoolmanService.deleteSpool(spool);

    _snackBarService.show(SnackBarConfig(
      title: tr('pages.spoolman.delete.success.title', args: [tr('pages.spoolman.spool.one')]),
      message: tr('pages.spoolman.delete.success.message.one', args: [tr('pages.spoolman.spool.one')]),
    ));
    _goRouter.pop();
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
