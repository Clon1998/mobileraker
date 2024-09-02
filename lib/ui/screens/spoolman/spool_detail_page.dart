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
import 'package:common/ui/animation/SizeAndFadeTransition.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/misc/filament_extension.dart';
import 'package:mobileraker_pro/service/moonraker/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';

import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
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
    var spool = ref.watch(_spoolProvider);

    var action = ref.watch(_spoolDetailPageControllerProvider(machineUUID).notifier).onAction;
    return Scaffold(
      appBar: _AppBar(machineUUID: machineUUID),
      floatingActionButton: FloatingActionButton(
        onPressed: () => action.call(Theme.of(context)),
        child: const Icon(Icons.mode),
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
    var spool = ref.watch(_spoolProvider);
    var isActive =
        ref.watch(_spoolDetailPageControllerProvider(machineUUID).selectAs((data) => data.activeSpool?.id == spool.id));
    var controller = ref.watch(_spoolDetailPageControllerProvider(machineUUID).notifier);

    final title = [
      if (spool.filament.vendor != null) spool.filament.vendor!.name,
      spool.filament.name,
    ].join(' – ');
    return AppBar(
      title: const Text('pages.spoolman.spool_details.page_title').tr(args: [title]),
      actions: <Widget>[
        AnimatedSwitcher(
          transitionBuilder: (child, animation) => SizeAndFadeTransition(sizeAndFadeFactor: animation, child: child),
          duration: kThemeAnimationDuration,
          child: isActive.valueOrNull == true
              ? AsyncIconButton(
                  key: const Key('spool_ia'),
                  onPressed: controller.onSetInactive,
                  icon: const Icon(Icons.unpublished_outlined),
                )
              : AsyncIconButton(
                  key: const Key('spool_a'),
                  onPressed: controller.onSetActive,
                  icon: const Icon(Icons.check_circle_outline),
                ),
        ),

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

class _SpoolInfo extends ConsumerWidget {
  const _SpoolInfo({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spoolmanCurrency = ref.watch(spoolmanCurrencyProvider(machineUUID));
    var controller = ref.watch(_spoolDetailPageControllerProvider(machineUUID).notifier);
    var spool = ref.watch(_spoolProvider);
    var dateFormatService = ref.watch(dateFormatServiceProvider);
    var dateFormatGeneral = dateFormatService.add_Hm(DateFormat.yMMMd());

    var numberFormatDouble =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 2);
    var numberFormatPrice =
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
                var isActive = ref.watch(_spoolDetailPageControllerProvider(machineUUID)
                    .selectAs((data) => data.activeSpool?.id == spool.id));

                var themeData = Theme.of(context);

                return isActive.valueOrNull == true
                    ? Chip(
                        label: const Text('Spool is Active'),
                        backgroundColor: themeData.colorScheme.primary,
                        labelStyle: TextStyle(color: themeData.colorScheme.onPrimary),
                      )
                    : const SizedBox.shrink();
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
    useAutomaticKeepAlive();

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
              exclude: ref.watch(_spoolProvider),
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

  @override
  Future<_Model> build(String machineUUID) async {
    var spool = ref.watch(_spoolProvider);
    var spoolmanService = ref.watch(spoolmanServiceProvider(machineUUID));

    return _Model(
      spool: spool,
      activeSpool: await ref.watch(activeSpoolProvider(machineUUID).future),
    );
  }

  void onEntryTap(SpoolmanIdentifiableDtoMixin dto) async {
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

  onAction(ThemeData themeData) async {
    final spool = state.requireValue.spool;

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
          SpoolSpoolmanSheetAction.edit,
          SpoolSpoolmanSheetAction.clone,
          SpoolSpoolmanSheetAction.consumeFilament,
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
        _generateAndShareQrCode();
        break;
      case SpoolSpoolmanSheetAction.edit:
        await _goRouter.pushNamed(AppRoute.spoolman_form_spool.name, extra: [machineUUID, spool]);
        ref.invalidateSelf();
        break;
      case SpoolSpoolmanSheetAction.clone:
        // await _goRouter.pushNamed(AppRoute.spoolman_form_spool.name, extra: [machineUUID, spool], queryParameters: {});
        // ref.invalidateSelf();
        break;
      case SpoolSpoolmanSheetAction.delete:
        //TODO : Add confirmation dialog
        await ref.read(spoolmanServiceProvider(machineUUID)).deleteSpool(spool);
        _goRouter.pop();
        break;
    }
  }

  Future<void> onSetActive() async {
    // await Future.delayed(Duration(seconds: 4));
    await ref.read(spoolmanServiceProvider(machineUUID)).setActiveSpool(state.value!.spool);
  }

  Future<void> onSetInactive() async {
    await ref.read(spoolmanServiceProvider(machineUUID)).clearActiveSpool();
  }

  Future<void> _generateAndShareQrCode() async {
    try {
      final spool = state.requireValue.spool;
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
        //TODO
        // sharePositionOrigin: origin,
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
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required GetSpool spool,
    GetSpool? activeSpool,
  }) = __Model;
}
