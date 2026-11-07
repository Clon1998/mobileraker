/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Header of the searchable sheets (macros, spools): compact title tile with an optional count, an outlined search
/// field, an optional row of filter chips and a divider. Same structure as [SelectionBottomSheet]'s header.
class SheetSearchHeader extends StatelessWidget {
  const SheetSearchHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.search,
    this.searchAction,
    this.chips = const [],
  });

  final String title;
  final String? subtitle;
  final TextEditingController search;

  /// Shown at the end of the search field while it is empty, replaced by the clear button once there is text.
  /// Without it the clear button is always shown.
  final Widget? searchAction;

  /// Filter chips, shown in a horizontally scrolling row below the search field if not empty.
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final clear = IconButton(
      tooltip: tr('pages.files.search.clear_search'),
      icon: const Icon(Icons.clear),
      onPressed: search.clear,
    );

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            titleAlignment: ListTileTitleAlignment.center,
            title: Text(title, style: themeData.textTheme.headlineSmall),
            subtitle: subtitle == null ? null : Text(subtitle!, style: themeData.textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '${MaterialLocalizations.of(context).searchFieldLabel}…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchAction == null
                    ? clear
                    : ValueListenableBuilder(
                        valueListenable: search,
                        builder: (context, value, _) => AnimatedSwitcher(
                          duration: kThemeAnimationDuration,
                          child: value.text.isEmpty ? KeyedSubtree(key: const ValueKey('action'), child: searchAction!) : clear,
                        ),
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (chips.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                children: [
                  for (final chip in chips) Padding(padding: const EdgeInsets.only(right: 8), child: chip),
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
