
/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class RangeSelector extends StatelessWidget {
  final Function(int)? onSelected;
  final Iterable<String> values;
  final int selectedIndex;

  const RangeSelector(
      {super.key,
      this.onSelected,
      required this.values,
      this.selectedIndex = 0})
      : assert(selectedIndex >= 0, 'SelectedIndex must be > 0'),
        assert(selectedIndex <= (values.length - 1),
            'selectedIndex is out of bound of provided values');

  _onSelectionChanged(int newIndex) {
    if (newIndex == selectedIndex) return;
    onSelected!(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    List<bool> selectedMap = List.filled(values.length, false);
    if (selectedMap.isNotEmpty) selectedMap[selectedIndex] = true;

    if (values.isEmpty) {
      return const Text('No Steps configured!');
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: ToggleButtons(
            isSelected: selectedMap,
            onPressed: onSelected != null ? _onSelectionChanged : null,
            children: values.map((e) => Text(e.toString())).toList()),
      );
    }
  }
}
