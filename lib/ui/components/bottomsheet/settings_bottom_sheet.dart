/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import 'selection_bottom_sheet.dart';

class SettingsBottomSheet extends ConsumerWidget {
  const SettingsBottomSheet({super.key, required this.arguments});

  final SettingsBottomSheetArgs arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        title: Text(arguments.title, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );

    return SheetContentScaffold(
      topBar: title,
      body: _SettingsList(arguments: arguments),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({super.key, required this.arguments});

  final SettingsBottomSheetArgs arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 200),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16) + MediaQuery.viewPaddingOf(context),
        shrinkWrap: true,
        children: [
          for (final setting in arguments.settings)
            switch (setting) {
              SwitchSettingItem() => _BoolSetting(setting: setting),
              NumSettingItem() => _DoubleSetting(setting: setting),
              ChoiceSettingItem() => _ChoiceSetting(setting: setting),
              DividerSettingItem() => Divider(height: setting.height),
            },
        ],
      ),
    );
  }
}

class _BoolSetting extends ConsumerWidget {
  const _BoolSetting({super.key, required this.setting});

  final SwitchSettingItem setting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      value: ref.watch(boolSettingProvider(setting.settingKey, setting.defaultValue)),
      title: Text(setting.title),
      subtitle: setting.subtitle?.let(Text.new),
      onChanged: ((value) => ref.read(settingServiceProvider).write(setting.settingKey, value)).only(setting.enabled),
    );
  }
}

class _DoubleSetting extends ConsumerWidget {
  const _DoubleSetting({super.key, required this.setting});

  final NumSettingItem setting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //TODO: support int settings!
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SliderOrTextInput(
        value: ref.watch(doubleSettingProvider(setting.settingKey)),
        prefixText: setting.title,
        onChange: ((v) => ref.read(settingServiceProvider).write(setting.settingKey, v)).only(setting.enabled),
        submitOnChange: true,
      ),
    );
  }
}

class _ChoiceSetting extends ConsumerWidget {
  const _ChoiceSetting({super.key, required this.setting});

  final ChoiceSettingItem setting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallbackIndex = setting.options.indexOf(setting.defaultValue);
    final index = ref.watch(intSettingProvider(setting.settingKey, fallbackIndex));
    final current = setting.options.elementAtOrNull(index) ?? setting.defaultValue;

    final themeData = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      title: Text(setting.title),
      subtitle: setting.subtitle?.let(Text.new),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            setting.labelBuilder(current),
            style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.primary),
          ),
          Icon(Icons.chevron_right, color: themeData.disabledColor),
        ],
      ),
      enabled: setting.enabled,
      onTap: () => _pick(context, ref, current),
    );
  }

  // Opened as a genuine tap on this already-settled sheet — safe, unlike pushing a second
  // sheet programmatically right after the first one's own push resolves (see group_actions_fab.dart).
  Future<void> _pick(BuildContext context, WidgetRef ref, dynamic current) async {
    final result = await ref.read(bottomSheetServiceProvider).show(
          BottomSheetConfig(
            type: SheetType.selections,
            data: SelectionBottomSheetArgs(
              title: Text(setting.title),
              showSearch: false,
              options: [
                for (final option in setting.options)
                  SelectionOption(
                    value: option,
                    label: setting.labelBuilder(option),
                    subtitle: setting.optionSubtitleBuilder?.call(option),
                    selected: option == current,
                  ),
              ],
            ),
          ),
        );
    if (!result.confirmed || result.data == null) return;
    ref.read(settingServiceProvider).writeInt(setting.settingKey, setting.options.indexOf(result.data));
  }
}

@immutable
class SettingsBottomSheetArgs {
  const SettingsBottomSheetArgs({required this.title, required this.settings});

  final String title;
  final List<SettingItem> settings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsBottomSheetArgs &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          const DeepCollectionEquality().equals(settings, other.settings);

  @override
  int get hashCode => Object.hash(title, const DeepCollectionEquality().hash(settings));
}

@immutable
sealed class SettingItem {
  const SettingItem({this.enabled = true});

  final bool enabled;
}

@immutable
class SwitchSettingItem extends SettingItem {
  const SwitchSettingItem({
    required this.settingKey,
    required this.title,
    this.subtitle,
    this.defaultValue = false,
    super.enabled,
  });

  final KeyValueStoreKey settingKey;
  final String title;
  final String? subtitle;
  final bool defaultValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwitchSettingItem &&
          runtimeType == other.runtimeType &&
          settingKey == other.settingKey &&
          title == other.title &&
          subtitle == other.subtitle &&
          defaultValue == other.defaultValue &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(settingKey, title, subtitle, defaultValue, enabled);
}

@immutable
class NumSettingItem extends SettingItem {
  const NumSettingItem({required this.settingKey, required this.title, this.defaultValue = 0, super.enabled});

  final KeyValueStoreKey settingKey;
  final String title;
  final num defaultValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NumSettingItem &&
          runtimeType == other.runtimeType &&
          settingKey == other.settingKey &&
          title == other.title &&
          defaultValue == other.defaultValue &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(settingKey, title, defaultValue, enabled);
}

@immutable
class ChoiceSettingItem<T> extends SettingItem {
  // Not const: labelBuilder is wrapped here (while T is still known) into a dynamic-parameter
  // closure. A field typed `String Function(T)` cannot be read back safely once this item is
  // held as the raw/erased `ChoiceSettingItem` (T becomes dynamic) — function parameter types
  // are contravariant, so `(T) => String` is not a subtype of `(dynamic) => String`, unlike
  // `List<T>`, whose covariant reads stay safe through that same erasure.
  ChoiceSettingItem({
    required this.settingKey,
    required this.title,
    required this.options,
    required String Function(T) labelBuilder,
    required this.defaultValue,
    this.subtitle,
    String Function(T)? optionSubtitleBuilder,
    super.enabled,
  }) : labelBuilder = ((value) => labelBuilder(value as T)),
       optionSubtitleBuilder = optionSubtitleBuilder == null ? null : ((value) => optionSubtitleBuilder(value as T));

  final KeyValueStoreKey settingKey;
  final String title;
  final String? subtitle;
  final List<T> options;
  final String Function(dynamic) labelBuilder;
  // Short blurb shown per-option in the picker sheet (not on the settings row itself).
  final String Function(dynamic)? optionSubtitleBuilder;
  final T defaultValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChoiceSettingItem &&
          runtimeType == other.runtimeType &&
          settingKey == other.settingKey &&
          title == other.title &&
          subtitle == other.subtitle &&
          const DeepCollectionEquality().equals(options, other.options) &&
          defaultValue == other.defaultValue &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      Object.hash(settingKey, title, subtitle, const DeepCollectionEquality().hash(options), defaultValue, enabled);
}

@immutable
class DividerSettingItem extends SettingItem {
  const DividerSettingItem({this.height = 4.0});

  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DividerSettingItem && runtimeType == other.runtimeType && height == other.height;

  @override
  int get hashCode => height.hashCode;
}

// @immutable
// class BuilderSettingItem<T, E> extends SettingItem {
//   const BuilderSettingItem({required this.settingKey, required this.builder, required this.defaultValue, this.extra, super.enabled});
//
//   final KeyValueStoreKey settingKey;
//   final T defaultValue;
//   final E? extra;
//   final Widget Function(BuildContext, T, E) builder;
//
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is BuilderSettingItem &&
//           runtimeType == other.runtimeType &&
//           settingKey == other.settingKey &&
//           defaultValue == other.defaultValue &&
//           builder == other.builder &&
//           extra == other.extra &&
//           enabled == other.enabled;
//
//   @override
//   int get hashCode => Object.hash(settingKey, builder, enabled, defaultValue, extra);
// }
