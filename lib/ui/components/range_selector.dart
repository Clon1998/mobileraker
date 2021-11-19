import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RangeSelector extends StatefulWidget {
  final Function onSelected;
  final List<String> values;
  final int selectedIndex;

  @override
  _RangeSelectorState createState() => _RangeSelectorState();

  const RangeSelector(
      {required this.onSelected, required this.values, this.selectedIndex = 0});
}

class _RangeSelectorState extends State<RangeSelector> {
  late List<bool> selectedMap;
  late int selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty)
      return Text('No Steps configured!');
    else
      return ToggleButtons(
          isSelected: selectedMap,
          onPressed: _onSelectionChanged,
          children: widget.values.map((e) => Text(e.toString())).toList());
  }

  _onSelectionChanged(int newIndex) {
    if (newIndex == selectedIndex) return;
    setState(() {
      widget.onSelected(newIndex);
      selectedMap[newIndex] = true;
      selectedMap[selectedIndex] = false;
      selectedIndex = newIndex;
    });
  }

  @override
  initState() {
    super.initState();
    selectedIndex = max(min(widget.selectedIndex, widget.values.length - 1), 0);
    List<bool> tmp = List.filled(widget.values.length, false);
    if (tmp.isNotEmpty) tmp[selectedIndex] = true;
    selectedMap = tmp;
  }
}
