/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/slider_or_text_input.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

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
