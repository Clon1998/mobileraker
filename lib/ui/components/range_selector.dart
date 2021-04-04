import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

class RangeSelector extends StatefulWidget {
  final Function onSelected;
  final List<String> values;
  final int defaultIndex;

  @override
  _RangeSelectorState createState() => _RangeSelectorState();

  const RangeSelector({@required this.onSelected, @required this.values, this.defaultIndex = 0});
}

class _RangeSelectorState extends State<RangeSelector> {
  List<bool> selectedMap;
  int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
        isSelected: selectedMap,
        onPressed: _onSelectionChanged,
        children: widget.values.map((e) => Text(e.toString())).toList());
  }

  void _onSelectionChanged(int newIndex) {
    setState(() {
      widget.onSelected(newIndex);
      selectedMap[newIndex] = true;
      selectedMap[selectedIndex] = false;
      selectedIndex = newIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.defaultIndex;
    List<bool> tmp = List.filled(widget.values.length, false);
    for (int i = 0; i < widget.values.length; i++) {
      tmp[i] = i == selectedIndex;
    }
    selectedMap = tmp;
  }
}
