/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/color_picker_sheet.dart';
import 'package:mobileraker_pro/custom_themes/data/model/custom_theme_config.dart';
import 'package:mobileraker_pro/custom_themes/data/model/custom_theme_pack.dart';
import 'package:mobileraker_pro/custom_themes/service/custom_theme_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../setting/components/section_header.dart';

class CustomThemeEditorPage extends HookConsumerWidget {
  const CustomThemeEditorPage({super.key, this.initialPack});

  final CustomThemePack? initialPack;

  bool get _isEditMode => initialPack != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uuid = useMemoized(() => initialPack?.uuid ?? const Uuid().v4());
    final nameController = useTextEditingController(text: initialPack?.name ?? '');

    // Light theme state
    final lightPrimary = useState<int>(initialPack?.lightConfig.primaryColor ?? Colors.teal.toARGB32());
    final lightSecondary = useState<int?>(initialPack?.lightConfig.secondaryColor);
    final lightTertiary = useState<int?>(initialPack?.lightConfig.tertiaryColor);
    final lightSurface = useState<int?>(initialPack?.lightConfig.surfaceColor);
    final lightForeground = useState<int?>(initialPack?.lightConfig.onSurfaceColor);
    final lightAppBar = useState<int?>(initialPack?.lightConfig.appBarColor);
    final lightUseMaterial3 = useState<bool>(initialPack?.lightConfig.useMaterial3 ?? true);

    // Dark theme state
    final hasDarkTheme = useState<bool>(initialPack?.darkConfig != null);
    final darkPrimary = useState<int>(initialPack?.darkConfig?.primaryColor ?? Colors.teal.shade700.toARGB32());
    final darkSecondary = useState<int?>(initialPack?.darkConfig?.secondaryColor);
    final darkTertiary = useState<int?>(initialPack?.darkConfig?.tertiaryColor);
    final darkSurface = useState<int?>(initialPack?.darkConfig?.surfaceColor);
    final darkForeground = useState<int?>(initialPack?.darkConfig?.onSurfaceColor);
    final darkAppBar = useState<int?>(initialPack?.darkConfig?.appBarColor);
    final darkUseMaterial3 = useState<bool>(initialPack?.darkConfig?.useMaterial3 ?? true);

    // M3 FlexColorScheme options — light
    final lightBlendLevel = useState<int>(initialPack?.lightConfig.blendLevel ?? 0);
    final lightSurfaceModeIndex = useState<int>(initialPack?.lightConfig.surfaceModeIndex ?? 0);
    final lightAppBarStyleIndex = useState<int>(initialPack?.lightConfig.appBarStyleIndex ?? 4);
    final lightUsedColors = useState<int>(initialPack?.lightConfig.usedColors ?? 1);
    final lightIsWhite = useState<bool>(initialPack?.lightConfig.lightIsWhite ?? false);

    // M3 FlexColorScheme options — dark
    final darkBlendLevel = useState<int>(initialPack?.darkConfig?.blendLevel ?? 0);
    final darkSurfaceModeIndex = useState<int>(initialPack?.darkConfig?.surfaceModeIndex ?? 0);
    final darkAppBarStyleIndex = useState<int>(initialPack?.darkConfig?.appBarStyleIndex ?? 4);
    final darkUsedColors = useState<int>(initialPack?.darkConfig?.usedColors ?? 1);
    final darkIsTrueBlack = useState<bool>(initialPack?.darkConfig?.darkIsTrueBlack ?? false);

    // Font family — shared for both light and dark variants
    final fontFamily = useState<String?>(initialPack?.lightConfig.fontFamily);

    // Logo state — store picked file paths (not yet copied to docs dir)
    final logoPickedPath = useState<String?>(null);
    final logoDarkPickedPath = useState<String?>(null);
    // Persisted paths (already in docs dir, from existing pack)
    final logoSavedPath = useState<String?>(initialPack?.logoPath);
    final logoDarkSavedPath = useState<String?>(initialPack?.logoDarkPath);

    final isSaving = useState(false);

    Future<void> pickLogo({required bool isDark}) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg', 'png'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.firstOrNull?.path;
      if (path == null) return;
      if (isDark) {
        logoDarkPickedPath.value = path;
      } else {
        logoPickedPath.value = path;
      }
    }

    Future<String?> copyLogoToDocuments(String? sourcePath, String destFileName) async {
      if (sourcePath == null) return null;
      final appDir = await getApplicationDocumentsDirectory();
      final logoDir = Directory('${appDir.path}/custom_themes/$uuid');
      await logoDir.create(recursive: true);
      final ext = sourcePath.contains('.') ? sourcePath.split('.').lastOrNull ?? 'png' : 'png';
      final dest = File('${logoDir.path}/$destFileName.$ext');
      await File(sourcePath).copy(dest.path);
      return dest.path;
    }

    Future<void> save() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('pages.setting.ui.appearance.theme_name_required'.tr())));
        return;
      }

      isSaving.value = true;
      try {
        final finalLogoPath = logoPickedPath.value != null
            ? await copyLogoToDocuments(logoPickedPath.value, 'logo_light')
            : logoSavedPath.value;
        final finalLogoDarkPath = logoDarkPickedPath.value != null
            ? await copyLogoToDocuments(logoDarkPickedPath.value, 'logo_dark')
            : logoDarkSavedPath.value;

        final lightConfig = CustomThemeConfig(
          primaryColor: lightPrimary.value,
          secondaryColor: lightSecondary.value,
          tertiaryColor: lightTertiary.value,
          surfaceColor: lightSurface.value,
          onSurfaceColor: lightForeground.value,
          appBarColor: lightAppBar.value,
          useMaterial3: lightUseMaterial3.value,
          fontFamily: fontFamily.value,
          blendLevel: lightBlendLevel.value,
          surfaceModeIndex: lightSurfaceModeIndex.value,
          appBarStyleIndex: lightAppBarStyleIndex.value,
          usedColors: lightUsedColors.value,
          lightIsWhite: lightIsWhite.value,
        );

        final darkConfig = hasDarkTheme.value
            ? CustomThemeConfig(
                primaryColor: darkPrimary.value,
                secondaryColor: darkSecondary.value,
                tertiaryColor: darkTertiary.value,
                surfaceColor: darkSurface.value,
                onSurfaceColor: darkForeground.value,
                appBarColor: darkAppBar.value,
                useMaterial3: darkUseMaterial3.value,
                fontFamily: fontFamily.value,
                blendLevel: darkBlendLevel.value,
                surfaceModeIndex: darkSurfaceModeIndex.value,
                appBarStyleIndex: darkAppBarStyleIndex.value,
                usedColors: darkUsedColors.value,
                darkIsTrueBlack: darkIsTrueBlack.value,
              )
            : null;

        final pack = CustomThemePack(
          uuid: uuid,
          name: name,
          lightConfig: lightConfig,
          darkConfig: darkConfig,
          logoPath: finalLogoPath,
          logoDarkPath: finalLogoDarkPath,
        );

        await ref.read(customThemeServiceProvider).save(pack);
        if (context.mounted) context.pop();
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> exportTheme() async {
      // Build configs from current state — avoids referencing the later-declared outer variables.
      final exportLight = CustomThemeConfig(
        primaryColor: lightPrimary.value,
        secondaryColor: lightSecondary.value,
        tertiaryColor: lightTertiary.value,
        surfaceColor: lightSurface.value,
        onSurfaceColor: lightForeground.value,
        appBarColor: lightAppBar.value,
        useMaterial3: lightUseMaterial3.value,
        fontFamily: fontFamily.value,
        blendLevel: lightBlendLevel.value,
        surfaceModeIndex: lightSurfaceModeIndex.value,
        appBarStyleIndex: lightAppBarStyleIndex.value,
        usedColors: lightUsedColors.value,
        lightIsWhite: lightIsWhite.value,
      );
      final exportDark = hasDarkTheme.value
          ? CustomThemeConfig(
              primaryColor: darkPrimary.value,
              secondaryColor: darkSecondary.value,
              tertiaryColor: darkTertiary.value,
              surfaceColor: darkSurface.value,
              onSurfaceColor: darkForeground.value,
              appBarColor: darkAppBar.value,
              useMaterial3: darkUseMaterial3.value,
              fontFamily: fontFamily.value,
              blendLevel: darkBlendLevel.value,
              surfaceModeIndex: darkSurfaceModeIndex.value,
              appBarStyleIndex: darkAppBarStyleIndex.value,
              usedColors: darkUsedColors.value,
              darkIsTrueBlack: darkIsTrueBlack.value,
            )
          : null;
      final pack = CustomThemePack(
        uuid: uuid,
        name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'Exported Theme',
        lightConfig: exportLight,
        darkConfig: exportDark,
        // logos are device-local paths — strip them so the file is shareable
        logoPath: null,
        logoDarkPath: null,
      );
      final json = jsonEncode(pack.toJson());
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

    Future<void> delete() async {
      if (!_isEditMode) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('pages.setting.ui.appearance.delete_theme_title').tr(),
          content: Text('pages.setting.ui.appearance.delete_theme_body'.tr(args: [nameController.text])),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('general.cancel').tr()),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('general.delete').tr()),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        await ref.read(customThemeServiceProvider).delete(initialPack!);
        if (context.mounted) context.pop();
      }
    }

    final lightConfig = CustomThemeConfig(
      primaryColor: lightPrimary.value,
      secondaryColor: lightSecondary.value,
      tertiaryColor: lightTertiary.value,
      surfaceColor: lightSurface.value,
      onSurfaceColor: lightForeground.value,
      appBarColor: lightAppBar.value,
      useMaterial3: lightUseMaterial3.value,
      fontFamily: fontFamily.value,
      blendLevel: lightBlendLevel.value,
      surfaceModeIndex: lightSurfaceModeIndex.value,
      appBarStyleIndex: lightAppBarStyleIndex.value,
      usedColors: lightUsedColors.value,
      lightIsWhite: lightIsWhite.value,
    );

    final darkConfig = hasDarkTheme.value
        ? CustomThemeConfig(
            primaryColor: darkPrimary.value,
            secondaryColor: darkSecondary.value,
            tertiaryColor: darkTertiary.value,
            surfaceColor: darkSurface.value,
            onSurfaceColor: darkForeground.value,
            appBarColor: darkAppBar.value,
            useMaterial3: darkUseMaterial3.value,
            fontFamily: fontFamily.value,
            blendLevel: darkBlendLevel.value,
            surfaceModeIndex: darkSurfaceModeIndex.value,
            appBarStyleIndex: darkAppBarStyleIndex.value,
            usedColors: darkUsedColors.value,
            darkIsTrueBlack: darkIsTrueBlack.value,
          )
        : null;

    // Apply the theme being edited to the whole editor so the UI is a live preview.
    // Use device brightness to pick the right variant; fall back to lightConfig when no
    // separate dark config has been defined.
    final deviceBrightness = MediaQuery.platformBrightnessOf(context);
    final previewPack = buildThemePack(
      CustomThemePack(uuid: '', name: '', lightConfig: lightConfig, darkConfig: darkConfig),
    );
    final editorTheme = deviceBrightness == Brightness.dark
        ? (previewPack.darkTheme ?? previewPack.lightTheme)
        : previewPack.lightTheme;

    return Theme(
      data: editorTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditMode ? 'pages.setting.ui.appearance.edit_theme'.tr() : 'pages.setting.ui.appearance.new_theme'.tr(),
          ),
          actions: [
            if (_isEditMode)
              IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: 'pages.setting.ui.appearance.export_theme'.tr(),
                onPressed: () => exportTheme(),
              ),
            if (_isEditMode)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'general.delete'.tr(),
                onPressed: () => delete(),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: isSaving.value ? null : () => save(),
          icon: isSaving.value
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_alt),
          label: const Text('general.save').tr(),
        ),
        body: Center(
          child: ResponsiveLimit(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                _IdentitySection(
                  nameController: nameController,
                  fontFamily: fontFamily.value,
                  onFontChanged: (v) => fontFamily.value = v,
                  logoPickedPath: logoPickedPath.value,
                  logoSavedPath: logoSavedPath.value,
                  logoDarkPickedPath: logoDarkPickedPath.value,
                  logoDarkSavedPath: logoDarkSavedPath.value,
                  onPickLogo: () => pickLogo(isDark: false),
                  onPickLogoDark: () => pickLogo(isDark: true),
                  onClearLogo: () {
                    logoPickedPath.value = null;
                    logoSavedPath.value = null;
                  },
                  onClearLogoDark: () {
                    logoDarkPickedPath.value = null;
                    logoDarkSavedPath.value = null;
                  },
                ),
                const Gap(16),
                _ColorSection(
                  title: 'pages.setting.ui.appearance.light_theme'.tr(),
                  primaryColor: lightPrimary.value,
                  secondaryColor: lightSecondary.value,
                  tertiaryColor: lightTertiary.value,
                  surfaceColor: lightSurface.value,
                  foregroundColor: lightForeground.value,
                  appBarColor: lightAppBar.value,
                  useMaterial3: lightUseMaterial3.value,
                  onPrimaryChanged: (v) => lightPrimary.value = v,
                  onSecondaryChanged: (v) => lightSecondary.value = v,
                  onTertiaryChanged: (v) => lightTertiary.value = v,
                  onSurfaceChanged: (v) => lightSurface.value = v,
                  onForegroundChanged: (v) => lightForeground.value = v,
                  onAppBarColorChanged: (v) => lightAppBar.value = v,
                  onMaterial3Changed: (v) => lightUseMaterial3.value = v,
                ),
                if (lightUseMaterial3.value) ...[
                  const Gap(8),
                  _M3OptionsSection(
                    isDark: false,
                    blendLevel: lightBlendLevel.value,
                    surfaceModeIndex: lightSurfaceModeIndex.value,
                    appBarStyleIndex: lightAppBarStyleIndex.value,
                    usedColors: lightUsedColors.value,
                    extremeSurface: lightIsWhite.value,
                    appBarColorSet: lightAppBar.value != null,
                    onBlendLevelChanged: (v) => lightBlendLevel.value = v,
                    onSurfaceModeChanged: (v) => lightSurfaceModeIndex.value = v,
                    onAppBarStyleChanged: (v) => lightAppBarStyleIndex.value = v,
                    onUsedColorsChanged: (v) => lightUsedColors.value = v,
                    onExtremeSurfaceChanged: (v) => lightIsWhite.value = v,
                  ),
                ],
                const Gap(16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('pages.setting.ui.appearance.separate_dark_theme').tr(),
                  subtitle: const Text('pages.setting.ui.appearance.separate_dark_theme_hint').tr(),
                  value: hasDarkTheme.value,
                  onChanged: (v) => hasDarkTheme.value = v,
                ),
                if (hasDarkTheme.value) ...[
                  const Gap(16),
                  _ColorSection(
                    title: 'pages.setting.ui.appearance.dark_theme'.tr(),
                    primaryColor: darkPrimary.value,
                    secondaryColor: darkSecondary.value,
                    tertiaryColor: darkTertiary.value,
                    surfaceColor: darkSurface.value,
                    foregroundColor: darkForeground.value,
                    appBarColor: darkAppBar.value,
                    useMaterial3: darkUseMaterial3.value,
                    onPrimaryChanged: (v) => darkPrimary.value = v,
                    onSecondaryChanged: (v) => darkSecondary.value = v,
                    onTertiaryChanged: (v) => darkTertiary.value = v,
                    onSurfaceChanged: (v) => darkSurface.value = v,
                    onForegroundChanged: (v) => darkForeground.value = v,
                    onAppBarColorChanged: (v) => darkAppBar.value = v,
                    onMaterial3Changed: (v) => darkUseMaterial3.value = v,
                  ),
                  if (darkUseMaterial3.value) ...[
                    const Gap(8),
                    _M3OptionsSection(
                      isDark: true,
                      blendLevel: darkBlendLevel.value,
                      surfaceModeIndex: darkSurfaceModeIndex.value,
                      appBarStyleIndex: darkAppBarStyleIndex.value,
                      usedColors: darkUsedColors.value,
                      extremeSurface: darkIsTrueBlack.value,
                      appBarColorSet: darkAppBar.value != null,
                      onBlendLevelChanged: (v) => darkBlendLevel.value = v,
                      onSurfaceModeChanged: (v) => darkSurfaceModeIndex.value = v,
                      onAppBarStyleChanged: (v) => darkAppBarStyleIndex.value = v,
                      onUsedColorsChanged: (v) => darkUsedColors.value = v,
                      onExtremeSurfaceChanged: (v) => darkIsTrueBlack.value = v,
                    ),
                  ],
                ],
                const Gap(16),
                _PreviewSection(lightConfig: lightConfig, darkConfig: darkConfig),
                const Gap(32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _kGoogleFontFamilies = [
  'DM Sans',
  'Inter',
  'Lato',
  'Montserrat',
  'Noto Sans',
  'Nunito',
  'Open Sans',
  'Outfit',
  'Plus Jakarta Sans',
  'Poppins',
  'Quicksand',
  'Raleway',
  'Roboto',
  'Source Sans 3',
  'Ubuntu',
];

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.nameController,
    required this.fontFamily,
    required this.onFontChanged,
    required this.logoPickedPath,
    required this.logoSavedPath,
    required this.logoDarkPickedPath,
    required this.logoDarkSavedPath,
    required this.onPickLogo,
    required this.onPickLogoDark,
    required this.onClearLogo,
    required this.onClearLogoDark,
  });

  final TextEditingController nameController;
  final String? fontFamily;
  final ValueChanged<String?> onFontChanged;
  final String? logoPickedPath;
  final String? logoSavedPath;
  final String? logoDarkPickedPath;
  final String? logoDarkSavedPath;
  final VoidCallback onPickLogo;
  final VoidCallback onPickLogoDark;
  final VoidCallback onClearLogo;
  final VoidCallback onClearLogoDark;

  String? get _effectiveLogo => logoPickedPath ?? logoSavedPath;

  String? get _effectiveLogoDark => logoDarkPickedPath ?? logoDarkSavedPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'pages.setting.ui.appearance.theme_identity'.tr()),
        TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'pages.setting.ui.appearance.theme_name'.tr()),
        ),
        const Gap(8),
        _FontFamilyTile(value: fontFamily, onChanged: onFontChanged),
        const Gap(16),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: _LogoPicker(
                label: 'pages.setting.ui.appearance.logo_light'.tr(),
                filePath: _effectiveLogo,
                onPick: onPickLogo,
                onClear: onClearLogo,
              ),
            ),
            Expanded(
              child: _LogoPicker(
                label: 'pages.setting.ui.appearance.logo_dark'.tr(),
                filePath: _effectiveLogoDark,
                onPick: onPickLogoDark,
                onClear: onClearLogoDark,
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          'pages.setting.ui.appearance.logo_hint'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FontFamilyTile extends StatelessWidget {
  const _FontFamilyTile({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('pages.setting.ui.appearance.font_family'.tr()),
      trailing: DropdownButton<String?>(
        value: value,
        underline: const SizedBox.shrink(),
        style: theme.textTheme.bodyMedium,
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('pages.setting.ui.appearance.font_family_system'.tr())),
          for (final family in _kGoogleFontFamilies)
            DropdownMenuItem<String?>(
              value: family,
              child: Text(family, style: GoogleFonts.getFont(family)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({required this.label, required this.filePath, required this.onPick, required this.onClear});

  final String label;
  final String? filePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final cs = themeData.colorScheme;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: filePath != null
            ? Stack(
                children: [
                  Center(child: _LogoPreview(filePath: filePath!)),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onClear,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: cs.error,
                        child: Icon(Icons.close, size: 14, color: cs.onError),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: cs.onSurfaceVariant),
                  Text(label, style: themeData.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.file(
        File(filePath),
        height: 48,
        semanticLabel: 'Logo preview',
        errorBuilder: (_, e, s) => const Icon(Icons.broken_image),
      ),
    );
  }
}

class _SwatchEntry {
  const _SwatchEntry({required this.icon, this.color, this.label, required this.onTap});

  final IconData icon;
  final Color? color;
  final String? label;
  final VoidCallback onTap;
}

class _ColorSection extends HookConsumerWidget {
  const _ColorSection({
    required this.title,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.surfaceColor,
    required this.foregroundColor,
    required this.appBarColor,
    required this.useMaterial3,
    required this.onPrimaryChanged,
    required this.onSecondaryChanged,
    required this.onTertiaryChanged,
    required this.onSurfaceChanged,
    required this.onForegroundChanged,
    required this.onAppBarColorChanged,
    required this.onMaterial3Changed,
  });

  final String title;
  final int primaryColor;
  final int? secondaryColor;
  final int? tertiaryColor;
  final int? surfaceColor;
  final int? foregroundColor;
  final int? appBarColor;
  final bool useMaterial3;
  final ValueChanged<int> onPrimaryChanged;
  final ValueChanged<int?> onSecondaryChanged;
  final ValueChanged<int?> onTertiaryChanged;
  final ValueChanged<int?> onSurfaceChanged;
  final ValueChanged<int?> onForegroundChanged;
  final ValueChanged<int?> onAppBarColorChanged;
  final ValueChanged<bool> onMaterial3Changed;

  Future<void> _pickColor(BuildContext _, WidgetRef ref, int? current, ValueChanged<int?> onChange) async {
    final currentHex = current != null ? colorToHex(Color(current), enableAlpha: false) : null;
    final result = await ref
        .read(bottomSheetServiceProvider)
        .show(
          BottomSheetConfig(
            type: SheetType.colorPicker,
            data: ColorPickerSheetArgs(initialColor: currentHex, clearIcon: Icons.format_color_reset_outlined),
          ),
        );
    if (result.confirmed) {
      final hexStr = result.data as String?;
      onChange(hexStr?.toColor()?.toARGB32());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        _ColorTile(
          title: 'pages.setting.ui.appearance.primary_color'.tr(),
          subtitle: 'pages.setting.ui.appearance.primary_color_hint'.tr(),
          swatches: [
            _SwatchEntry(
              icon: Icons.palette_outlined,
              color: Color(primaryColor),
              onTap: () => _pickColor(context, ref, primaryColor, (v) {
                if (v != null) onPrimaryChanged(v);
              }),
            ),
          ],
        ),
        _ColorTile(
          title: 'pages.setting.ui.appearance.secondary_color'.tr(),
          subtitle: 'pages.setting.ui.appearance.secondary_color_hint'.tr(),
          swatches: [
            _SwatchEntry(
              icon: Icons.palette_outlined,
              color: secondaryColor != null ? Color(secondaryColor!) : null,
              onTap: () => _pickColor(context, ref, secondaryColor, onSecondaryChanged),
            ),
          ],
        ),
        _ColorTile(
          title: 'pages.setting.ui.appearance.tertiary_color'.tr(),
          subtitle: 'pages.setting.ui.appearance.tertiary_color_hint'.tr(),
          swatches: [
            _SwatchEntry(
              icon: Icons.palette_outlined,
              color: tertiaryColor != null ? Color(tertiaryColor!) : null,
              onTap: () => _pickColor(context, ref, tertiaryColor, onTertiaryChanged),
            ),
          ],
        ),
        _ColorTile(
          title: 'pages.setting.ui.appearance.surface_color'.tr(),
          subtitle: 'pages.setting.ui.appearance.surface_color_hint'.tr(),
          swatches: [
            _SwatchEntry(
              icon: Icons.format_color_fill,
              label: 'pages.setting.ui.appearance.surface_background'.tr(),
              color: surfaceColor != null ? Color(surfaceColor!) : null,
              onTap: () => _pickColor(context, ref, surfaceColor, onSurfaceChanged),
            ),
            _SwatchEntry(
              icon: Icons.format_color_text,
              label: 'pages.setting.ui.appearance.surface_foreground'.tr(),
              color: foregroundColor != null ? Color(foregroundColor!) : null,
              onTap: () => _pickColor(context, ref, foregroundColor, onForegroundChanged),
            ),
          ],
        ),
        _ColorTile(
          title: 'pages.setting.ui.appearance.app_bar_color'.tr(),
          subtitle: 'pages.setting.ui.appearance.app_bar_color_hint'.tr(),
          swatches: [
            _SwatchEntry(
              icon: Icons.web_asset_outlined,
              color: appBarColor != null ? Color(appBarColor!) : null,
              onTap: () => _pickColor(context, ref, appBarColor, onAppBarColorChanged),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('pages.setting.ui.appearance.use_material3').tr(),
          subtitle: const Text('pages.setting.ui.appearance.use_material3_hint').tr(),
          value: useMaterial3,
          onChanged: onMaterial3Changed,
        ),
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.title, this.subtitle, required this.swatches});

  final String title;
  final String? subtitle;
  final List<_SwatchEntry> swatches;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: textTheme.bodyMedium),
                if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [for (final entry in swatches) _ColorSwatchButton(entry: entry)],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({required this.entry});

  final _SwatchEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasColor = entry.color != null;

    final Widget circle;
    if (hasColor) {
      final fgColor = ThemeData.estimateBrightnessForColor(entry.color!) == Brightness.dark
          ? Colors.white
          : Colors.black;
      circle = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: entry.color!,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).useMaterial3 ? cs.outline : cs.primary),
        ),
        child: Center(child: Icon(entry.icon, size: 15, color: fgColor)),
      );
    } else {
      circle = SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outline),
              ),
            ),
            Positioned.fill(
              child: ClipOval(
                child: CustomPaint(painter: _SlashPainter(color: cs.outlineVariant)),
              ),
            ),
            Icon(entry.icon, size: 15, color: cs.onSurfaceVariant),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: entry.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          circle,
          if (entry.label != null) Text(entry.label!, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  const _SlashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.15),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SlashPainter old) => old.color != color;
}

const _kSurfaceModeLabels = [
  'pages.setting.ui.appearance.surface_mode_0',
  'pages.setting.ui.appearance.surface_mode_1',
  'pages.setting.ui.appearance.surface_mode_2',
  'pages.setting.ui.appearance.surface_mode_3',
  'pages.setting.ui.appearance.surface_mode_4',
];

const _kAppBarStyleLabels = [
  'pages.setting.ui.appearance.app_bar_style_0',
  'pages.setting.ui.appearance.app_bar_style_1',
  'pages.setting.ui.appearance.app_bar_style_2',
  'pages.setting.ui.appearance.app_bar_style_3',
  'pages.setting.ui.appearance.app_bar_style_4',
];

class _M3OptionsSection extends ConsumerWidget {
  const _M3OptionsSection({
    required this.isDark,
    required this.blendLevel,
    required this.surfaceModeIndex,
    required this.appBarStyleIndex,
    required this.usedColors,
    required this.extremeSurface,
    required this.appBarColorSet,
    required this.onBlendLevelChanged,
    required this.onSurfaceModeChanged,
    required this.onAppBarStyleChanged,
    required this.onUsedColorsChanged,
    required this.onExtremeSurfaceChanged,
  });

  final bool isDark;
  final int blendLevel;
  final int surfaceModeIndex;
  final int appBarStyleIndex;
  final int usedColors;
  final bool extremeSurface;
  final bool appBarColorSet;
  final ValueChanged<int> onBlendLevelChanged;
  final ValueChanged<int> onSurfaceModeChanged;
  final ValueChanged<int> onAppBarStyleChanged;
  final ValueChanged<int> onUsedColorsChanged;
  final ValueChanged<bool> onExtremeSurfaceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'pages.setting.ui.appearance.m3_options'.tr()),

        // Blend level
        InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'pages.setting.ui.appearance.blend_level'.tr(),
            helperText: 'pages.setting.ui.appearance.blend_level_hint'.tr(),
            helperMaxLines: 3,
          ),
          child: Slider(
            value: blendLevel.toDouble(),
            min: 0,
            max: 40,
            divisions: 40,
            label: '$blendLevel',
            onChanged: (v) => onBlendLevelChanged(v.toInt()),
          ),
        ),
        const Gap(8),

        // Surface mode
        InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'pages.setting.ui.appearance.surface_mode'.tr(),
            helperText: 'pages.setting.ui.appearance.surface_mode_hint'.tr(),
            helperMaxLines: 3,
          ),
          child: DropdownButton<int>(
            value: surfaceModeIndex,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final (i, label) in _kSurfaceModeLabels.indexed) DropdownMenuItem(value: i, child: Text(label.tr())),
            ],
            onChanged: (v) {
              if (v != null) onSurfaceModeChanged(v);
            },
          ),
        ),
        const Gap(8),

        // App bar style
        InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'pages.setting.ui.appearance.app_bar_style'.tr(),
            helperText: appBarColorSet
                ? 'pages.setting.ui.appearance.app_bar_style_overridden'.tr()
                : 'pages.setting.ui.appearance.app_bar_style_hint'.tr(),
            helperMaxLines: 3,
          ),
          child: DropdownButton<int>(
            value: appBarStyleIndex,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            disabledHint: Text(
              (_kAppBarStyleLabels.elementAtOrNull(appBarStyleIndex) ?? _kAppBarStyleLabels.lastOrNull ?? '').tr(),
            ),
            onChanged: appBarColorSet
                ? null
                : (v) {
                    if (v != null) onAppBarStyleChanged(v);
                  },
            items: [
              for (final (i, label) in _kAppBarStyleLabels.indexed) DropdownMenuItem(value: i, child: Text(label.tr())),
            ],
          ),
        ),
        const Gap(8),

        // Used colors
        InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: 'pages.setting.ui.appearance.used_colors'.tr(),
            helperText: 'pages.setting.ui.appearance.used_colors_hint'.tr(),
            helperMaxLines: 3,
          ),
          child: Slider(
            value: usedColors.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$usedColors',
            onChanged: (v) => onUsedColorsChanged(v.toInt()),
          ),
        ),

        // True black / pure white
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            isDark
                ? 'pages.setting.ui.appearance.dark_is_true_black'.tr()
                : 'pages.setting.ui.appearance.light_is_white'.tr(),
          ),
          subtitle: Text(
            isDark
                ? 'pages.setting.ui.appearance.dark_is_true_black_hint'.tr()
                : 'pages.setting.ui.appearance.light_is_white_hint'.tr(),
          ),
          value: extremeSurface,
          onChanged: onExtremeSurfaceChanged,
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.lightConfig, required this.darkConfig});

  final CustomThemeConfig lightConfig;
  final CustomThemeConfig? darkConfig;

  @override
  Widget build(BuildContext context) {
    final lightTheme = buildThemePack(CustomThemePack(uuid: '', name: '', lightConfig: lightConfig)).lightTheme;
    final effectiveDarkConfig = darkConfig ?? lightConfig;
    final darkTheme = buildThemePack(
      CustomThemePack(uuid: '', name: '', lightConfig: effectiveDarkConfig, darkConfig: effectiveDarkConfig),
    ).darkTheme!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'pages.setting.ui.appearance.theme_preview'.tr()),
        Row(
          spacing: 8,
          children: [
            Expanded(child: _ThemePreviewCard(themeData: lightTheme)),
            Expanded(child: _ThemePreviewCard(themeData: darkTheme)),
          ],
        ),
      ],
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({required this.themeData});

  final ThemeData themeData;

  @override
  Widget build(BuildContext context) {
    final cs = themeData.colorScheme;
    return Theme(
      data: themeData,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Container(
              height: 20,
              color: themeData.appBarTheme.backgroundColor ?? cs.primary,
              width: double.infinity,
              child: Center(
                child: Container(height: 6, width: 40, color: themeData.appBarTheme.foregroundColor ?? cs.onPrimary),
              ),
            ),
            Container(height: 7, color: cs.onSurface.withValues(alpha: 0.12), width: 80),
            Container(height: 5, color: cs.onSurface.withValues(alpha: 0.07), width: 60),
            Row(
              spacing: 4,
              children: [
                _PreviewChip(color: cs.primaryContainer, foreground: cs.onPrimaryContainer),
                _PreviewChip(color: cs.secondaryContainer, foreground: cs.onSecondaryContainer),
                _PreviewChip(color: cs.tertiaryContainer, foreground: cs.onTertiaryContainer),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: cs.secondary, borderRadius: BorderRadius.circular(6)),
                child: Center(child: Icon(Icons.add, size: 14, color: cs.onSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.color, required this.foreground});

  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Container(height: 5, width: 16, color: foreground.withValues(alpha: 0.7)),
    );
  }
}
