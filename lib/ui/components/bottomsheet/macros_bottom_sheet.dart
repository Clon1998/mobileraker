/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/macro/macro_command.dart';
import 'package:mobileraker/ui/components/macro/sent_feedback_icon.dart';
import 'package:mobileraker/ui/components/macro/use_sent_feedback.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class MacrosBottomSheetArgs {
  const MacrosBottomSheetArgs({required this.machineUUID, this.groupUUID});

  final String machineUUID;

  /// The group to preselect, null shows the macros of all groups.
  final String? groupUUID;
}

/// Searchable list of all visible macros of a machine with a group filter. Macros with params (or with
/// "confirm macro execution" on) expand inline to fill them in before running.
class MacrosBottomSheet extends HookConsumerWidget {
  const MacrosBottomSheet({super.key, required this.args});

  final MacrosBottomSheetArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineUUID = args.machineUUID;
    final groupsAsync = ref.watch(machineSettingsProvider(machineUUID).selectAs((d) => d.macroGroups));
    final configMacrosAsync = ref.watch(printerProvider(machineUUID).selectAs((d) => d.configFile.gcodeMacros));
    final printStateAsync = ref.watch(printerProvider(machineUUID).selectAs((d) => d.print.state));
    final canReceive =
        ref.watch(klipperProvider(machineUUID).selectAs((d) => d.klippyCanReceiveCommands)).value ?? false;

    final search = useTextEditingController();
    // Same debounce as SelectionBottomSheet
    final query = useDebounced(useValueListenable(search).text.trim(), const Duration(milliseconds: 400)) ?? '';
    final selectedGroup = useState<String?>(args.groupUUID);
    final expanded = useState<String?>(null);

    final themeData = Theme.of(context);

    final groups = groupsAsync.value;
    final configMacros = configMacrosAsync.value;
    final printState = printStateAsync.value;

    if (groups == null || configMacros == null || printState == null) {
      return SheetContentScaffold(
        topBar: _Header(count: null, search: search),
        body: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }

    // A preselected group might have been deleted in the meantime
    final group = groups.where((g) => g.uuid == selectedGroup.value).firstOrNull;
    final available = _visibleMacros(group == null ? groups : [group], printState, configMacros);
    final macros = query.isEmpty ? available : _search(available, configMacros, query);

    return SheetContentScaffold(
      topBar: _Header(
        count: _visibleMacros(groups, printState, configMacros).length,
        search: search,
        groups: groups,
        selectedGroup: group?.uuid,
        onGroupSelected: (uuid) {
          selectedGroup.value = uuid;
          expanded.value = null;
        },
      ),
      // Not shrink-wrapped: the sheet keeps its full height instead of jumping while searching/filtering
      body: macros.isEmpty
          ? Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  query.isEmpty
                      ? tr('pages.dashboard.control.macro_card.no_macros')
                      : tr('bottom_sheets.macros.no_results'),
                  textAlign: TextAlign.center,
                  style: themeData.textTheme.bodyMedium?.copyWith(color: themeData.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              // Like SelectionBottomSheet: M3 tiles are indented left, rounded only there and run to the right edge;
              // M2: flat rows with dividers
              padding:
                  (themeData.useMaterial3 ? const EdgeInsets.fromLTRB(12, 12, 0, 16) : EdgeInsets.zero) +
                  MediaQuery.viewPaddingOf(context).copyWith(top: 0),
              itemCount: macros.length,
              separatorBuilder: (_, _) => themeData.useMaterial3
                  ? const SizedBox(height: 6)
                  : const Divider(height: 0, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final macro = macros[index];
                return _MacroTile(
                  key: ValueKey(macro.configName),
                  machineUUID: machineUUID,
                  macro: macro,
                  config: configMacros[macro.configName]!,
                  enabled: canReceive,
                  expanded: expanded.value == macro.configName,
                  onExpandedChanged: (value) => expanded.value = value ? macro.configName : null,
                );
              },
            ),
    );
  }

  /// Ranks [macros] by [String.searchScore] like [SelectionBottomSheet] (same cut-off), best match first. The name
  /// (split at underscores) counts fully, the description at 70% so name hits stay on top.
  static List<GCodeMacro> _search(List<GCodeMacro> macros, Map<String, ConfigGcodeMacro> configMacros, String term) {
    final tokens = term.split(RegExp(r'[\W,]+')).where((t) => t.isNotEmpty);
    return macros
        .map((m) {
          final description = configMacros[m.configName]!.userDescription;
          final nameScore = m.name.searchScore(term, tokens);
          final descriptionScore = (description?.searchScore(term, tokens) ?? 0) * 0.7;
          return (m, max(nameScore, descriptionScore));
        })
        .where((e) => e.$2 > 150)
        .sortedBy<num>((e) => -e.$2)
        .map((e) => e.$1)
        .toList();
  }

  /// Visible macros of [groups] for the [printState] that exist on the printer, without duplicates.
  static List<GCodeMacro> _visibleMacros(
    List<MacroGroup> groups,
    PrintState printState,
    Map<String, ConfigGcodeMacro> configMacros,
  ) {
    final seen = <String>{};
    return [
      for (final group in groups)
        for (final macro in group.filtered(printState))
          if (configMacros.containsKey(macro.configName) && seen.add(macro.configName)) macro,
    ];
  }
}

/// Same structure as the other sheets' headers (e.g. [SelectionBottomSheet]): compact title tile, search, divider.
class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.search,
    this.groups = const [],
    this.selectedGroup,
    this.onGroupSelected,
  });

  final int? count;
  final TextEditingController search;
  final List<MacroGroup> groups;
  final String? selectedGroup;
  final ValueChanged<String?>? onGroupSelected;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            titleAlignment: ListTileTitleAlignment.center,
            title: Text(tr('bottom_sheets.macros.title'), style: themeData.textTheme.headlineSmall),
            subtitle: count == null
                ? null
                : Text(plural('bottom_sheets.macros.available', count!), style: themeData.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '${MaterialLocalizations.of(context).searchFieldLabel}…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: tr('pages.files.search.clear_search'),
                  icon: const Icon(Icons.clear),
                  onPressed: search.clear,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (groups.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                children: [
                  for (final (uuid, name) in [
                    (null, tr('bottom_sheets.macros.all')),
                    ...groups.map((g) => (g.uuid, g.name)),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: selectedGroup == uuid,
                        showCheckmark: false,
                        onSelected: (_) => onGroupSelected?.call(uuid),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Divider(height: 0),
        ],
      ),
    );
  }
}

class _MacroTile extends HookConsumerWidget {
  const _MacroTile({
    super.key,
    required this.machineUUID,
    required this.macro,
    required this.config,
    required this.enabled,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final String machineUUID;
  final GCodeMacro macro;
  final ConfigGcodeMacro config;
  final bool enabled;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormBuilderState>.new);
    final alwaysConfirm = ref.watch(boolSettingProvider(AppSettingKeys.confirmMacroExecution));
    final needsInput = config.params.isNotEmpty || alwaysConfirm;

    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final description = config.userDescription;

    final (sent, showSent) = useSentFeedback();

    void run(Map<String, String?> params) {
      HapticFeedback.selectionClick();
      ref.read(printerServiceProvider(machineUUID)).gCode(macroCommand(config.macroName, params));
      onExpandedChanged(false);
      showSent();
    }

    void onTap() {
      if (needsInput) {
        onExpandedChanged(!expanded);
      } else {
        run(const {});
      }
    }

    final m3 = themeData.useMaterial3;
    // M3: a faint tint at rest, a stronger one for the open form, a sent macro flashes. M2 rows stay flat (dividers).
    final background = switch ((sent, expanded, m3)) {
      (true, _, _) => colorScheme.primary.withValues(alpha: 0.12),
      (false, true, true) => colorScheme.surfaceContainerHigh,
      (false, true, false) => colorScheme.primary.withValues(alpha: 0.05),
      (false, false, true) => colorScheme.onSurface.withValues(alpha: 0.04),
      (false, false, false) => colorScheme.surface.withValues(alpha: 0),
    };

    return ClipRRect(
      // Same shape as SelectionBottomSheet's M3 rows: rounded on the left, flush with the right edge
      borderRadius: m3 ? const BorderRadius.horizontal(left: Radius.circular(44)) : BorderRadius.zero,
      child: AnimatedContainer(
        duration: kThemeAnimationDuration,
        color: background,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedSize(
            duration: kThemeAnimationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: enabled ? onTap : null,
                  // Same as on the card: long press skips the params/confirmation
                  onLongPress: enabled
                      ? () {
                          HapticFeedback.vibrate();
                          run(const {});
                        }
                      : null,
                  child: Padding(
                    padding: m3 ? const EdgeInsets.fromLTRB(20, 12, 24, 12) : const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(macro.codeName, style: macroNameStyle(themeData.textTheme.titleMedium)),
                              if (description != null)
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        SentFeedbackIcon(
                          sent: sent,
                          color: colorScheme.primary,
                          // Hints that the row opens a form instead of running right away
                          idle: needsInput
                              ? AnimatedRotation(
                                  turns: expanded ? 0.5 : 0,
                                  duration: kThemeAnimationDuration,
                                  curve: Curves.easeInOutCubicEmphasized,
                                  child: Icon(
                                    Icons.expand_more,
                                    color: enabled ? colorScheme.onSurfaceVariant : themeData.disabledColor,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (expanded)
                  Padding(
                    padding: m3 ? const EdgeInsets.fromLTRB(20, 0, 24, 16) : const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FormBuilder(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final MapEntry(key: name, value: param) in config.params.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FormBuilderTextField(
                                name: name,
                                initialValue: param.defaultValue,
                                keyboardType: switch (param.type) {
                                  'int' => const TextInputType.numberWithOptions(signed: true),
                                  'float' ||
                                  'double' => const TextInputType.numberWithOptions(signed: true, decimal: true),
                                  _ => TextInputType.text,
                                },
                                decoration: m3
                                    ? InputDecoration(
                                        labelText: name.toUpperCase(),
                                        filled: true,
                                        fillColor: colorScheme.surfaceContainerHighest,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                      )
                                    : InputDecoration(labelText: name.toUpperCase()),
                              ),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            onPressed: enabled
                                ? () {
                                    final form = formKey.currentState!..save();
                                    run(form.value.map((k, v) => MapEntry(k, v?.toString())));
                                  }
                                : null,
                            child: Text(tr('bottom_sheets.macros.run', args: [macro.codeName])),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
