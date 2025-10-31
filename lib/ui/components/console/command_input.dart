/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CommandInput extends HookConsumerWidget {
  const CommandInput({super.key, required this.machineUUID, required this.consoleTextEditor, this.emptyInputSuffix});

  final String machineUUID;
  final TextEditingController consoleTextEditor;
  final Widget? emptyInputSuffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerService = ref.watch(printerServiceProvider(machineUUID));
    final enabled = ref.watch(klipperProvider(machineUUID).selectAs((d) => d.klippyCanReceiveCommands)).value == true;

    final hasInput = useListenableSelector(consoleTextEditor, () => consoleTextEditor.text.isNotEmpty);

    submit() {
      final command = consoleTextEditor.text;
      if (command.isEmpty) return;
      printerService.gCode(command).ignore();
      consoleTextEditor.clear();
    }

    return TextField(
      onSubmitted: (_) => enabled ? submit() : null,
      enableSuggestions: false,
      autocorrect: false,
      controller: consoleTextEditor,
      enabled: enabled,
      decoration: InputDecoration(
        suffixIcon: AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic.flipped,
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween(begin: 0.5, end:  1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child:
              emptyInputSuffix.unless(hasInput) ??
              IconButton(key: Key('submit'), icon: const Icon(Icons.send), onPressed: submit.only(enabled)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        hintText: enabled ? tr('pages.console.command_input.hint') : tr('pages.console.fetching_console'),
      ),
    );
  }
}
