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

class SelectionBottomSheet extends HookConsumerWidget {
  const SelectionBottomSheet({super.key, required this.arguments});

  final SelectionBottomSheetArgs arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final node = useFocusNode();
    final textCtl = useTextEditingController();
    final textEditingValue = useValueListenable(textCtl);
    final debouncedTextEditingValue = useDebounced(textEditingValue, const Duration(milliseconds: 400));

    // useListenable(listenable)

    // useEffect(() {
    //   if (debouncedTextEditingValue == null) return;
    //   final term = debouncedTextEditingValue.text;
    //   logger.i('debouncedTerm: $term. Will update search results!');
    //
    //
    // }, [debouncedTextEditingValue]);

    return AdaptiveDraggableScrollableSheet(
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (ctx, scrollController) {
        return Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                const Divider(),
              ],
              Flexible(
                child: _FilteredResults(
                  scrollController: scrollController,
                  options: arguments.options,
                  searchTerm: debouncedTextEditingValue?.text,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilteredResults extends StatelessWidget {
  const _FilteredResults({super.key, required this.scrollController, required this.options, this.searchTerm});

  final ScrollController scrollController;
  final List<SelectionOption> options;
  final String? searchTerm;

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
    return ListView(
      shrinkWrap: true,
      // physics: const ClampingScrollPhysics(),
      controller: scrollController,
      children: [for (final opt in result) _Entry(option: opt)],
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

class _Entry extends StatelessWidget {
  const _Entry({super.key, required this.option});

  final SelectionOption option;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: themeData.useMaterial3 ? const EdgeInsets.only(left: 8.0) : EdgeInsets.zero,
      child: ListTile(
        enabled: option.enabled,
        visualDensity: VisualDensity.compact,
        // leading: Icon(option.icon),
        leading: option.leading,
        horizontalTitleGap: 0,
        //TODO: make this configurable?
        // horizontalTitleGap: 8,
        title: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        minLeadingWidth: 42,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(44)))
            .only(themeData.useMaterial3),
        onTap: () {
          Navigator.of(context).pop(BottomSheetResult.confirmed(option.value));
        },
      ),
    );
  }
}

@immutable
class SelectionBottomSheetArgs<T> {
  const SelectionBottomSheetArgs({this.title, required this.options});

  final Widget? title;
  final List<SelectionOption<T>> options;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionBottomSheetArgs &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(other.options, options) &&
          title == other.title;

  @override
  int get hashCode => Object.hash(
        const DeepCollectionEquality().hash(options),
        title,
      );
}

@immutable
class SelectionOption<T> {
  const SelectionOption({required this.value, required this.label, this.leading, this.enabled = true});

  final T value;
  final String label;
  final Widget? leading;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectionOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          leading == other.leading &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(label, leading, enabled);
}
