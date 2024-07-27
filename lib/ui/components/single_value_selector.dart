/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class SingleValueSelector extends StatelessWidget {
  final Function(int)? onSelected;
  final Iterable<String> values;
  final int selectedIndex;

  const SingleValueSelector({
    super.key,
    this.onSelected,
    required this.values,
    this.selectedIndex = 0,
  })  : assert(selectedIndex >= 0, 'SelectedIndex must be > 0'),
        assert(selectedIndex <= (values.length - 1), 'selectedIndex is out of bound of provided values');

  _onSelectionChanged(int newIndex) {
    if (newIndex == selectedIndex) return;
    onSelected!(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    List<bool> selectedMap = List.filled(values.length, false);
    if (selectedMap.isNotEmpty) selectedMap[selectedIndex] = true;

    final theme = Theme.of(context);

    if (values.isEmpty) {
      return Text('No Steps configured!', style: theme.textTheme.bodySmall);
    }

    var buttons = theme.useMaterial3
        ? SegmentedButton(
            showSelectedIcon: false,
            selected: {values.elementAt(selectedIndex)},
            segments: [
              for (var value in values) ButtonSegment<String>(value: value, label: Text(value)),
            ],
            onSelectionChanged: (value) {
              if (value.isEmpty || value.length > 1) return;
              // ignore: avoid-unsafe-collection-methods
              final newIndex = values.toList().indexOf(value.first);
              _onSelectionChanged(newIndex);
            },
          )
        : ToggleButtons(
            isSelected: selectedMap,
            onPressed: onSelected != null ? _onSelectionChanged : null,
            children: [for (var value in values) Text(value)],
          );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: buttons,
    );
  }
}
