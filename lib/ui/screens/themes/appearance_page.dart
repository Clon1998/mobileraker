/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/custom_themes/data/model/custom_theme_pack.dart';
import 'package:mobileraker_pro/custom_themes/service/custom_theme_service.dart';
import 'package:mobileraker_pro/custom_themes/ui/components/custom_theme_list_tile.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../routing/app_router.dart';
import '../../components/bottomsheet/action_bottom_sheet.dart';
import '../setting/components/section_header.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('pages.setting.ui.appearance.title').tr()),
      body: Center(
        child: ResponsiveLimit(
          child: CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                sliver: SliverToBoxAdapter(child: _ThemeSection()),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                sliver: SliverToBoxAdapter(child: _CustomThemesSectionHeader()),
              ),
              const _CustomThemesSliverContent(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SectionHeader(title: 'pages.setting.ui.appearance.theme_section'.tr()),
        const _ThemeSelector(),
        const _ThemeModeSelector(),
      ],
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);
    final themePackList = themeService.themePacks;

    final systemThemeIdx = ref.watch(intSettingProvider(AppSettingKeys.themePack)).clamp(0, themePackList.length - 1);
    final currentSystemThemePack = themePackList.elementAtOrNull(systemThemeIdx) ?? themePackList.firstOrNull;
    if (currentSystemThemePack == null) return const SizedBox.shrink();

    final activeTheme = ref.watch(activeThemeProvider).value;
    final usesSystemTheme = currentSystemThemePack == activeTheme?.themePack;

    final themeData = Theme.of(context);
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelStyle: themeData.textTheme.labelLarge,
        labelText: 'pages.setting.general.system_theme'.tr(),
        helperText: usesSystemTheme ? null : 'pages.setting.general.printer_theme_warning'.tr(),
        helperMaxLines: 3,
      ),
      child: DropdownButton<ThemePack>(
        value: currentSystemThemePack,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: themePackList.map((theme) {
          final brandingIcon = themeData.brightness == Brightness.light ? theme.brandingIcon : theme.brandingIconDark;
          return DropdownMenuItem(
            value: theme,
            child: Row(
              spacing: 8,
              children: [
                Image(
                  height: 32,
                  width: 32,
                  image: brandingIcon ?? Svg('assets/vector/mr_logo.svg'),
                  semanticLabel: theme.name,
                ),
                Flexible(child: Text(theme.name)),
              ],
            ),
          );
        }).toList(),
        onChanged: (ThemePack? themePack) {
          if (themePack == null) return;
          if (usesSystemTheme) {
            themeService.selectThemePack(themePack);
          } else {
            themeService.updateSystemThemePack(themePack);
          }
        },
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);

    final currentMode = ref.watch(activeThemeProvider.select((d) => d.value?.themeMode)) ?? ThemeMode.system;
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'pages.setting.general.system_theme_mode'.tr(),
      ),
      child: DropdownButton<ThemeMode>(
        value: currentMode,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final mode in ThemeMode.values)
            DropdownMenuItem(
              value: mode,
              child: const Text('theme_mode').tr(gender: mode.name),
            ),
        ],
        onChanged: (ThemeMode? themeMode) => themeService.selectThemeMode(themeMode ?? ThemeMode.system),
      ),
    );
  }
}

enum _CustomThemeAction with BottomSheetAction {
  newTheme('pages.setting.ui.appearance.new_theme', Icons.add),
  importTheme('pages.setting.ui.appearance.import_theme', Icons.file_download_outlined);

  const _CustomThemeAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}

enum _CustomThemeTileAction with BottomSheetAction {
  setActive('pages.setting.ui.appearance.set_active', Icons.check_circle_outline),
  edit('pages.setting.ui.appearance.edit_theme', Icons.edit_outlined),
  export('pages.setting.ui.appearance.export_theme', Icons.ios_share_outlined),
  clone('pages.setting.ui.appearance.clone_theme', Icons.content_copy_outlined),
  delete('general.delete', Icons.delete_outline);

  const _CustomThemeTileAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}

// Header row: "Custom Themes" title + single "+" button that opens an action sheet
class _CustomThemesSectionHeader extends ConsumerWidget {
  const _CustomThemesSectionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSupporter = ref.watch(isSupporterProvider);
    return Row(
      children: [
        Expanded(child: SectionHeader(title: 'pages.setting.ui.appearance.custom_themes'.tr())),
        if (isSupporter)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('pages.setting.ui.appearance.new_theme').tr(),
            onPressed: () => _showAddMenu(context, ref),
          ),
      ],
    );
  }

  Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
    final res = await ref
        .read(bottomSheetServiceProvider)
        .show(
          BottomSheetConfig(
            type: SheetType.actions,
            data: ActionBottomSheetArgs(
              title: const Text('pages.setting.ui.appearance.custom_themes').tr(),
              actions: [_CustomThemeAction.newTheme, _CustomThemeAction.importTheme],
            ),
          ),
        );

    if (!context.mounted) return;
    if (res case BottomSheetResult(confirmed: true, data: _CustomThemeAction action)) {
      switch (action) {
        case _CustomThemeAction.newTheme:
          context.pushNamed(AppRoute.settings_appearance_customThemeNew.name);
        case _CustomThemeAction.importTheme:
          await _importTheme(context, ref);
      }
    }
  }

  Future<void> _importTheme(BuildContext _, WidgetRef ref) async {
    final snackbarService = ref.read(snackBarServiceProvider);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withReadStream: true,
      withData: false,
    );
    if (result == null) return;
    try {
      final content = await utf8.decodeStream(result.files.firstOrNull!.readStream!);
      final json = jsonDecode(content) as Map<String, dynamic>;
      final pack = CustomThemePack.fromJson(json).copyWith(uuid: const Uuid().v4());
      await ref.read(customThemeServiceProvider).save(pack);
      snackbarService.show(SnackBarConfig(title: 'pages.setting.ui.appearance.theme_imported'.tr(args: [pack.name])));
    } catch (_) {
      snackbarService.show(
        SnackBarConfig(type: SnackbarType.error, title: 'pages.setting.ui.appearance.theme_import_failed'.tr()),
      );
    }
  }
}

// Returns a sliver — either SliverFillRemaining (empty/gate) or SliverList (packs)
class _CustomThemesSliverContent extends ConsumerWidget {
  const _CustomThemesSliverContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSupporter = ref.watch(isSupporterProvider);

    if (!isSupporter) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SupporterOnlyFeature(
              text: const Text('components.supporter_only_feature.custom_themes').tr(),
            ),
          ),
        ),
      );
    }

    final customPacks = ref.watch(customThemePacksProvider);

    return customPacks.when(
      loading: () => const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
      data: (packs) {
        if (packs.isEmpty) {
          final themeData = Theme.of(context);
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(Icons.palette_outlined, size: 56, color: themeData.colorScheme.outlineVariant),
                  Text(
                    'pages.setting.ui.appearance.custom_themes_empty'.tr(),
                    textAlign: TextAlign.center,
                    style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          sliver: SliverList.separated(
            itemCount: packs.length,
            itemBuilder: (ctx, i) => CustomThemeListTile(
              key: ValueKey(packs[i].uuid),
              pack: packs[i],
              onEdit: () => ctx.pushNamed(AppRoute.settings_appearance_customThemeEdit.name, extra: packs[i]),
              onMore: () => _showTileMenu(ctx, ref, packs[i]),
            ),
            separatorBuilder: (_, _) => const SizedBox(height: 6),
          ),
        );
      },
    );
  }

  Future<void> _showTileMenu(BuildContext context, WidgetRef ref, CustomThemePack pack) async {
    final res = await ref
        .read(bottomSheetServiceProvider)
        .show(
          BottomSheetConfig(
            type: SheetType.actions,
            data: ActionBottomSheetArgs(
              title: Text(pack.name),
              actions: [
                _CustomThemeTileAction.setActive,
                _CustomThemeTileAction.edit,
                _CustomThemeTileAction.export,
                _CustomThemeTileAction.clone,
                DividerSheetAction.divider,
                _CustomThemeTileAction.delete,
              ],
            ),
          ),
        );

    if (!context.mounted) return;
    if (res case BottomSheetResult(confirmed: true, data: _CustomThemeTileAction action)) {
      switch (action) {
        case _CustomThemeTileAction.setActive:
          _setThemeActive(ref, pack);
        case _CustomThemeTileAction.edit:
          context.pushNamed(AppRoute.settings_appearance_customThemeEdit.name, extra: pack);
        case _CustomThemeTileAction.export:
          await _exportTheme(pack);
        case _CustomThemeTileAction.clone:
          await _cloneTheme(ref, pack);
        case _CustomThemeTileAction.delete:
          await _confirmDelete(context, ref, pack);
      }
    }
  }

  void _setThemeActive(WidgetRef ref, CustomThemePack pack) {
    final themeService = ref.read(themeServiceProvider);
    final matching = themeService.themePacks.firstWhereOrNull((tp) => tp.name == pack.name);
    if (matching != null) themeService.selectThemePack(matching);
  }

  Future<void> _exportTheme(CustomThemePack pack) async {
    // Strip device-local logo paths so the file is shareable cross-device.
    final exportPack = pack.copyWith(logoPath: null, logoDarkPath: null);
    final json = jsonEncode(exportPack.toJson());
    final tmpDir = await getTemporaryDirectory();
    final safeName = pack.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final file = File('${tmpDir.path}/mobileraker_theme_$safeName.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Mobileraker Theme: ${pack.name}',
      ),
    );
  }

  Future<void> _cloneTheme(WidgetRef ref, CustomThemePack pack) async {
    final cloned = pack.copyWith(uuid: const Uuid().v4(), name: '${pack.name} (Copy)');
    await ref.read(customThemeServiceProvider).save(cloned);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CustomThemePack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('pages.setting.ui.appearance.delete_theme_title').tr(),
        content: Text('pages.setting.ui.appearance.delete_theme_body'.tr(args: [pack.name])),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('general.cancel').tr()),
          TextButton(onPressed: () => ctx.pop(true), child: const Text('general.delete').tr()),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(customThemeServiceProvider).delete(pack);
    }
  }
}
