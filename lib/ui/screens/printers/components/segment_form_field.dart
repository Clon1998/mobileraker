/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SegmentFormField extends HookWidget {
  const SegmentFormField({
    super.key,
    required this.name,
    this.initialValue,
    this.maxOptions = 5,
    this.decoration = const InputDecoration(),
    this.validator,
    this.keyboardType = TextInputType.number,
    this.onChanged,
  });

  final String name;

  final List<num>? initialValue;

  final ValueChanged<List<num>?>? onChanged;

  final int maxOptions;

  final InputDecoration decoration;

  final FormFieldValidator<String>? validator;

  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final editing = useState(false);

    return FormBuilderField<List<num>>(
      name: name,
      onChanged: onChanged,
      initialValue: initialValue,
      builder: (field) {
        final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
        final options = field.value ?? [];

        return AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          child: editing.value
              ? _AddValue(
                  key: Key('add_value'),
                  decoration: decoration,
                  onAdded: (v) {
                    talker.error('Value added: }');

                    field.didChange(List.unmodifiable([...options, v]..sort()));
                    editing.value = false;
                  },
                  onAbort: () => editing.value = false,
                  keyboardType: keyboardType,
                  validator: (x) {
                    final res = validator?.call(x);
                    if (res != null) return res;
                    if (options.contains(x?.let(num.tryParse))) {
                      return tr('components.segment_form_field.duplicate_error');
                    }
                    return null;
                  },
                )
              : _NonEditing(
                  key: Key('non_editing'),
                  decoration: decoration,
                  options: options,
                  onRemove: ((v) => field.didChange(List.unmodifiable([...options]..remove(v)))).only(enabled),
                  onAdd: (() => editing.value = true).only(options.length < maxOptions && enabled),
                ),
        );
      },
    );
  }
}

class _AddValue extends HookWidget {
  const _AddValue({
    super.key,
    required this.onAdded,
    this.onAbort,
    required this.decoration,
    required this.validator,
    required this.keyboardType,
  });

  final Function(num) onAdded;
  final VoidCallback? onAbort;
  final InputDecoration decoration;
  final FormFieldValidator<String> validator;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final error = useState<String?>(null);
    final textController = useTextEditingController();
    final node = useFocusNode();
    useEffect(() {
      node.requestFocus();
    }, [node]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onAbort?.call();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              focusNode: node,
              controller: textController,
              onEditingComplete: () => onAdded(num.parse(textController.text) as num),
              onChanged: (val) => error.value = validator(val),
              decoration: decoration.copyWith(errorText: error.value),
              keyboardType: keyboardType,
            ),
          ),
          HookBuilder(
            builder: (BuildContext context) {
              final showDone = useListenableSelector(textController, () => textController.text.isNotEmpty);

              return IconButton(
                color: Theme.of(context).colorScheme.primary,
                icon: AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1).animate(anim),
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: showDone
                      ? const Icon(Icons.done, key: ValueKey('done'))
                      : const Icon(Icons.close, key: ValueKey('close')),
                ),
                onPressed: showDone
                    ? (() => onAdded(num.parse(textController.text))).only(error.value == null)
                    : onAbort,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NonEditing<T extends num> extends StatelessWidget {
  const _NonEditing({super.key, required this.options, required this.decoration, this.onRemove, this.onAdd});

  final List<T> options;
  final InputDecoration decoration;

  final Function(T)? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final numberFormat = NumberFormat.decimalPattern(context.locale.toStringWithSeparator());

    return InputDecorator(
      decoration: decoration,
      child: Wrap(
        children: [
          for (final option in options)
            ActionChip(
              label: Text(numberFormat.format(option)),

              onPressed: onRemove != null ? () => onRemove!(option) : null,
            ),
          if (options.isEmpty) Chip(label: const Text('pages.printer_edit.no_values_found').tr()),
          if (onAdd != null)
            ActionChip(
              backgroundColor: themeData.colorScheme.primary,
              label: Text('+', style: TextStyle(color: themeData.colorScheme.onPrimary)),
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}
