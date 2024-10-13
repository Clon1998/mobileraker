/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/adaptive_draggable_scrollable_sheet.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SelectionBottomSheet<T> extends HookConsumerWidget {
  const SelectionBottomSheet({super.key, required this.arguments});

  final SelectionBottomSheetArgs<T> arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final node = useFocusNode();
    final textCtl = useTextEditingController();
    final textEditingValue = useValueListenable(textCtl);
    final debouncedTextEditingValue = useDebounced(textEditingValue, const Duration(milliseconds: 400));
    final selected = useValueNotifier(arguments.options.where((e) => e.selected).map((e) => e.value).toList());

    return AdaptiveDraggableScrollableSheet(
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (ctx, scrollController) {
        return SafeArea(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(10),
                // _Header(title: arguments.title, subtitle: arguments.subtitle, leading: arguments.leading),
                // Divider(),
                if (arguments.title != null) ...[
                  ListTile(
                    visualDensity: VisualDensity.compact,
                    titleAlignment: ListTileTitleAlignment.center,
                    iconColor: themeData.colorScheme.primary,
                    // leading: arguments.leading,
                    horizontalTitleGap: 8,
                    title: arguments.title,
                  ),
                  if (arguments.showSearch)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: TextField(
                        focusNode: node,
                        controller: textCtl,
                        decoration: InputDecoration(
                          hintText: '${MaterialLocalizations.of(context).searchFieldLabel}…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: tr('pages.files.search.clear_search'),
                            icon: const Icon(Icons.clear),
                            onPressed: textCtl.clear,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  Gap(8),
                  const Divider(height: 0),
                ],
                Flexible(
                  child: _FilteredResults(
                    scrollController: scrollController,
                    options: arguments.options,
                    searchTerm: debouncedTextEditingValue?.text,
                    selectedNotifier: arguments.multiSelect ? selected : null,
                  ),
                ),
                if (arguments.multiSelect)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(BottomSheetResult.confirmed(selected!.value));
                      },
                      child: Text(MaterialLocalizations.of(context).continueButtonLabel),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilteredResults<T> extends StatelessWidget {
  const _FilteredResults({
    super.key,
    required this.scrollController,
    required this.options,
    this.searchTerm,
    this.selectedNotifier,
  });

  final ScrollController scrollController;
  final List<SelectionOption<T>> options;
  final String? searchTerm;
  final ValueNotifier<List<T>>? selectedNotifier;

  @override
  Widget build(BuildContext context) {
    final result = _filterOptions(options, searchTerm);
    final themeData = Theme.of(context);

    if (result.isEmpty) {
      return Column(
        key: const Key('no_results'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FractionallySizedBox(
              heightFactor: 0.3,
              child: SvgPicture.asset('assets/vector/undraw_void_-3-ggu.svg'),
            ),
          ),
          const SizedBox(height: 16),
          Text('bottom_sheets.selections.no_selections.title', style: themeData.textTheme.titleMedium).tr(),
          Text('bottom_sheets.selections.no_selections.subtitle', style: themeData.textTheme.bodySmall).tr(),
        ],
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.only(top: 4),
        shrinkWrap: true,
        // physics: const ClampingScrollPhysics(),
        controller: scrollController,
        children: [for (final opt in result) _Entry(option: opt, selectedNotifier: selectedNotifier)],
      ),
    );
  }

  List<SelectionOption> _filterOptions(List<SelectionOption> options, String? term) {
    if (term == null || term.isEmpty) return options;

    final searchTokens = term.split(RegExp(r'[\W,]+'));

    return options
        .map((e) =>
            (e, e.label.searchScore(term, searchTokens)).also((it) => logger.w('Score: ${it.$2} for ${it.$1.label}')))
        .where((e) => e.$2 > 150)
        .sortedBy<num>((e) => e.$2)
        .map((e) => e.$1)
        .toList();
  }
}

class _Entry<T> extends HookWidget {
  const _Entry({super.key, required this.option, this.selectedNotifier});

  final SelectionOption<T> option;
  final ValueNotifier<List<T>>? selectedNotifier;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    final isSelected = useListenableSelector(
        selectedNotifier, () => selectedNotifier?.value.contains(option.value) ?? option.selected);

    return Padding(
      padding: themeData.useMaterial3 ? const EdgeInsets.only(left: 8.0) : EdgeInsets.zero,
      child: ListTile(
        enabled: option.enabled,
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        // leading: Icon(option.icon),
        leading: option.leading,
        trailing: option.trailing,
        horizontalTitleGap: option.horizontalTitleGap,
        title: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
        minLeadingWidth: 42,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(44)))
            .only(themeData.useMaterial3),
        onTap: () {
          if (selectedNotifier != null) {
            if (isSelected) {
              selectedNotifier!.value = [...?selectedNotifier?.value.whereNot((e) => e == option.value)];
            } else {
              selectedNotifier!.value = [...?selectedNotifier?.value, option.value];
            }
          } else {
            Navigator.of(context).pop(BottomSheetResult.confirmed(option.value));
          }
        },
        // selectedColor: themeData.colorScheme.primary,
        selectedTileColor: themeData.colorScheme.primary.withOpacity(0.1),
      ),
    );
  }
}

@immutable
class SelectionBottomSheetArgs<T> {
  const SelectionBottomSheetArgs({this.title, required this.options, this.showSearch = true, this.multiSelect = false});

  final Widget? title;
  final List<SelectionOption<T>> options;
  final bool showSearch;
  final bool multiSelect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionBottomSheetArgs &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(other.options, options) &&
          showSearch == other.showSearch &&
          multiSelect == other.multiSelect &&
          title == other.title;

  @override
  int get hashCode => Object.hash(
        const DeepCollectionEquality().hash(options),
        title,
        showSearch,
        multiSelect,
      );
}

@immutable
class SelectionOption<T> {
  const SelectionOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.selected = false,
    this.horizontalTitleGap = 0,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final bool selected;
  final double horizontalTitleGap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionOption &&
          runtimeType == other.runtimeType &&
          (identical(value, other.value) || value == other.value) &&
          (identical(label, other.label) || label == other.label) &&
          (identical(leading, other.leading) || leading == other.leading) &&
          (identical(trailing, other.trailing) || trailing == other.trailing) &&
          (identical(enabled, other.enabled) || enabled == other.enabled) &&
          (identical(horizontalTitleGap, other.horizontalTitleGap) || horizontalTitleGap == other.horizontalTitleGap) &&
          (identical(selected, other.selected) || selected == other.selected);

  @override
  int get hashCode => Object.hash(value, label, subtitle, leading, trailing, enabled, selected, horizontalTitleGap);
}
