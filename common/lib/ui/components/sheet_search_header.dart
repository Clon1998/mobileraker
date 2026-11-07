/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Header of the list sheets (macros, spools, services, …): compact title tile with an optional subtitle (e.g. a count),
/// an optional outlined search field, an optional row of filter chips and a divider. Same structure as
/// [SelectionBottomSheet]'s header.
class SheetSearchHeader extends StatelessWidget {
  const SheetSearchHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.search,
    this.searchAction,
    this.chips = const [],
  });

  final String title;
  final String? subtitle;

  /// E.g. a back button for sheets pushed on top of another one.
  final Widget? leading;

  /// E.g. actions on the whole list.
  final Widget? trailing;

  /// The search field is only shown with a controller.
  final TextEditingController? search;

  /// Shown at the end of the search field while it is empty, replaced by the clear button once there is text.
  /// Without it the clear button is always shown.
  final Widget? searchAction;

  /// Filter chips, shown in a horizontally scrolling row below the search field if not empty.
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final search = this.search;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            visualDensity: VisualDensity.compact,
            // Icon buttons bring 12dp of padding: trim the tile's 16dp so their icons line up at 16dp like the titles
            // of the other sheets (and like an AppBar's back button)
            contentPadding: EdgeInsetsDirectional.only(start: leading == null ? 16 : 4, end: trailing == null ? 16 : 4),
            horizontalTitleGap: leading == null ? null : 8,
            leading: leading,
            trailing: trailing,
            titleAlignment: ListTileTitleAlignment.center,
            title: Text(title, style: themeData.textTheme.headlineSmall),
            subtitle: subtitle == null ? null : Text(subtitle!, style: themeData.textTheme.bodySmall),
          ),
          if (search != null) _searchField(context, search),
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
          // Like SelectionBottomSheet: the divider follows the title right away, only a search field or chips get a gap
          if (search != null || chips.isNotEmpty) const SizedBox(height: 8),
          const Divider(height: 0),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context, TextEditingController search) {
    final clear = IconButton(
      tooltip: tr('pages.files.search.clear_search'),
      icon: const Icon(Icons.clear),
      onPressed: search.clear,
    );
    return Padding(
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
    );
  }
}
