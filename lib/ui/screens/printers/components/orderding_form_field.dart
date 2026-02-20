/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OrderdingFormField extends StatelessWidget {
  const OrderdingFormField({super.key, required this.name, required this.initialValue, this.onChanged});

  final String name;
  final List<ReordableElement> initialValue;
  final ValueChanged<List<ReordableElement>?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField(
      name: name,
      initialValue: initialValue,
      onChanged: onChanged,
      builder: (field) => _OrderingFormField(field: field),
    );
  }
}

class _OrderingFormField extends HookConsumerWidget {
  const _OrderingFormField({super.key, required this.field});

  final FormFieldState<List<ReordableElement>> field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
    final elements = field.value ?? [];

    return ReorderableListView(
      buildDefaultDragHandles: true,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      onReorder: onReorder,
      onReorderStart: (i) {
        FocusScope.of(context).unfocus();
      },
      proxyDecorator: (child, _, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext ctx, Widget? c) {
            final double animValue = Curves.easeInOut.transform(animation.value);
            final double elevation = lerpDouble(0, 6, animValue)!;
            return Material(type: MaterialType.transparency, elevation: elevation, child: c);
          },
          child: child,
        );
      },
      children: [
        for (var i = 0; i < elements.length; i++)
          elements[i].let(
            (element) => _Element(key: ValueKey(element.uuid), index: i, element: element, enabled: enabled),
          ),
      ],
    );
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final out = [...?field.value];
    var tmp = out.removeAt(oldIndex);
    out.insert(newIndex, tmp);
    field.didChange(out);
  }
}

class _Element extends StatelessWidget {
  const _Element({super.key, required this.index, required this.element, this.enabled = true});

  final int index;
  final ReordableElement element;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).disabledColor;
    return Card(
      key: ValueKey(element.uuid),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Icon(Icons.drag_handle, color: color.unless(enabled)),
          enabled: enabled,
        ),
        title: Text(element.beautifiedName, style: TextStyle(color: color).unless(enabled)),
      ),
    );
  }
}
