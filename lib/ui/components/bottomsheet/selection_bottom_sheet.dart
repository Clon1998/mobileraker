/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class SelectionBottomSheet<T> extends HookConsumerWidget {
  const SelectionBottomSheet({super.key, required this.arguments});

  final SelectionBottomSheetArgs<T> arguments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    FutureOr<List<SelectionOption<T>>> options = arguments.options;
    final textCtl = useTextEditingController();
    final ValueNotifier<List<T>>? selected = arguments.multiSelect
        ? useValueNotifier(
            arguments.hasSyncOptions ? arguments.syncOptions.where((e) => e.selected).map((e) => e.value).toList() : [],
          )
        : null;
    final optionsSnapshot = arguments.hasSyncOptions
        ? AsyncSnapshot.withData(ConnectionState.done, arguments.syncOptions)
        : useFuture(arguments.asyncOptions);

    // For async options we need to update the valueNotifier when the options are loaded
    useEffect(
      () {
        if (selected == null) return;
        if (optionsSnapshot.connectionState == ConnectionState.done) {
          selected.value = optionsSnapshot.data!.where((e) => e.selected).map((e) => e.value).toList();
        }
      },
      [optionsSnapshot.connectionState],
    );

    talker.warning('SelectionBottomSheet: ${optionsSnapshot}');

    return SheetContentScaffold(
      resizeBehavior: const ResizeScaffoldBehavior.avoidBottomInset(
        maintainBottomBar: true,
      ),
      appBar: _Title(arguments: arguments, textEditingController: textCtl),
      body: _bodyFromSnapshot(optionsSnapshot, textCtl, selected),
      bottomBar: StickyBottomBarVisibility(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                context.pop(BottomSheetResult.confirmed(selected!.value));
              },
              child: Text(MaterialLocalizations.of(context).keyboardKeySelect),
            ),
          ),
        ),
      ).only(arguments.multiSelect),
    );
  }

  Widget _bodyFromSnapshot(
    AsyncSnapshot<List<SelectionOption<T>>> snapshot,
    TextEditingController textEditingController,
    ValueNotifier<List<T>>? selected,
  ) {
    final Widget widget;
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.hasError) {
        widget = FractionallySizedBox(
          heightFactor: 0.5,
          child: Center(child: Text(snapshot.error.toString())),
        );
      } else {
        widget = _DataBottomSheet(
          arguments: arguments,
          options: snapshot.data!,
          textEditingController: textEditingController,
          selected: selected,
        );
      }
    } else {
      widget = const FractionallySizedBox(
        heightFactor: 0.2,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedSizeAndFade(
      alignment: Alignment.topCenter,
      child: widget,
    );
  }
}

class _Title<T> extends HookWidget implements PreferredSizeWidget {
  const _Title({super.key, required this.arguments, required this.textEditingController});

  final SelectionBottomSheetArgs<T> arguments;
  final TextEditingController textEditingController;

  @override
  Widget build(BuildContext context) {
    final node = useFocusNode();

    return Column(
      // mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ListTile(
          visualDensity: VisualDensity.compact,
          titleAlignment: ListTileTitleAlignment.center,
          // leading: arguments.leading,
          // horizontalTitleGap: 8,
          title: arguments.title,
        ),
        if (arguments.showSearch) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              focusNode: node,
              controller: textEditingController,
              decoration: InputDecoration(
                hintText: '${MaterialLocalizations.of(context).searchFieldLabel}…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: tr('pages.files.search.clear_search'),
                  icon: const Icon(Icons.clear),
                  onPressed: textEditingController.clear,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const Gap(8),
        ],
        const Divider(height: 0),
      ],
    );
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(kToolbarHeight + (arguments.showSearch ? 62 : 0));
  }
}

class _DataBottomSheet<T> extends HookConsumerWidget {
  const _DataBottomSheet({
    super.key,
    required this.arguments,
    required this.options,
    required this.textEditingController,
    required this.selected,
  });

  final SelectionBottomSheetArgs<T> arguments;
  final List<SelectionOption<T>> options;
  final TextEditingController textEditingController;
  final ValueNotifier<List<T>>? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textEditingValue = useValueListenable(textEditingController);
    final debouncedTextEditingValue = useDebounced(textEditingValue, const Duration(milliseconds: 400));

    final body = _FilteredResults(
      options: options,
      searchTerm: debouncedTextEditingValue?.text,
      selectedNotifier: arguments.multiSelect ? selected : null,
    );

    return body;
  }
}

class _FilteredResults<T> extends StatelessWidget {
  const _FilteredResults({
    super.key,
    required this.options,
    this.searchTerm,
    this.selectedNotifier,
  });

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
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      shrinkWrap: true,
      // physics: const ClampingScrollPhysics(),
      children: [for (final opt in result) _Entry(option: opt, selectedNotifier: selectedNotifier)],
    );
  }

  List<SelectionOption> _filterOptions(List<SelectionOption> options, String? term) {
    if (term == null || term.isEmpty) return options;

    final searchTokens = term.split(RegExp(r'[\W,]+'));

    return options
        .map((e) => (e, e.label.searchScore(term, searchTokens))
            .also((it) => talker.warning('Score: ${it.$2} for ${it.$1.label}')))
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
      selectedNotifier,
      () => selectedNotifier?.value.contains(option.value) ?? option.selected,
    );

    return Padding(
      padding: themeData.useMaterial3 ? const EdgeInsets.only(left: 12.0) : EdgeInsets.zero,
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
            context.pop(BottomSheetResult.confirmed(option.value));
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
  final FutureOr<List<SelectionOption<T>>> options;
  final bool showSearch;
  final bool multiSelect;

  bool get hasSyncOptions {
    if (options case Future<List<SelectionOption<T>>>()) return false;
    return true;
  }

  Future<List<SelectionOption<T>>> get asyncOptions {
    if (options case Future<List<SelectionOption<T>>>() && final future) return future;
    throw StateError('Options are sync! No need to await it.');
  }

  List<SelectionOption<T>> get syncOptions {
    if (options case List<SelectionOption<T>>() && final list) return list;
    throw StateError('Options are async! Use asyncOptions instead and await it.');
  }

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
