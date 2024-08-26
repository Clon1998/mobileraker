/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dialog/manual_offset/manual_offset_controller.dart';
import 'package:mobileraker/ui/components/single_value_selector.dart';

class ManualOffsetDialog extends HookConsumerWidget {
  static final List<double> offsetSteps = [0.001, 0.01, 0.05, 0.1, 1];

  final DialogRequest request;
  final DialogCompleter completer;

  const ManualOffsetDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var selectedStep = useState((offsetSteps.length - 1) ~/ 2);

    var controller = manualOffsetDialogControllerProvider(completer);

    var numberFormat = NumberFormat('0.0##', context.locale.toStringWithSeparator());

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        var pop = await ref.read(controller.notifier).onPopTriggered();
        var naviator = Navigator.of(context);
        if (pop && naviator.canPop()) {
          naviator.pop();
        }
      },
      child: MobilerakerDialog(
        footer: _Footer(dialogCompleter: completer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                request.title ?? tr('dialogs.manual_offset.title'),
                style: themeData.textTheme.headlineSmall,
              ),
            ),
            AnimatedSizeAndFade(
              fadeDuration: kThemeAnimationDuration,
              sizeDuration: kThemeAnimationDuration,
              child: ref.watch(controller).when(
                    data: (manualProbe) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    onPressed: () => ref.read(controller.notifier).onOffsetMinusPressed(
                                          offsetSteps[selectedStep.value],
                                        ),
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Expanded(
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        isDense: true,
                                        floatingLabelAlignment: FloatingLabelAlignment.center,
                                        floatingLabelBehavior: FloatingLabelBehavior.always,
                                        label: Text(
                                          '${tr('general.offset')} [mm]',
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      child: Text(
                                        '${manualProbe.zPositionLower?.let(numberFormat.format)} >> ${manualProbe.zPosition?.let(numberFormat.format)} << ${manualProbe.zPositionUpper?.let(numberFormat.format)}',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => ref.read(controller.notifier).onOffsetPlusPressed(
                                          offsetSteps[selectedStep.value],
                                        ),
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                              IntrinsicWidth(
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.only(top: 16),
                                    floatingLabelAlignment: FloatingLabelAlignment.center,
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                    label: Text(
                                      '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  child: SingleValueSelector(
                                    onSelected: (idx) => selectedStep.value = idx,
                                    values: offsetSteps.map((e) => numberFormat.format(e)),
                                    selectedIndex: selectedStep.value,
                                  ),
                                ),
                              ),
                              // Text(
                              //   'Adjust offset until the nozzle creates friction on the paper.',
                              //   style: themeData.textTheme.bodySmall,
                              // ),
                            ],
                          ),
                        ),
                        const Divider(thickness: 1),
                      ],
                    ),
                    error: (e, s) => ErrorCard(
                      title: const Text('Error loading Bed Screw'),
                      body: Text(e.toString()),
                    ),
                    loading: () => SpinKitWave(
                      size: 33,
                      color: themeData.colorScheme.primary,
                    ),
                    skipLoadingOnReload: true,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({super.key, required this.dialogCompleter});

  final DialogCompleter dialogCompleter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = manualOffsetDialogControllerProvider(dialogCompleter);
    var manualProbe = ref.watch(controller).valueOrNull;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: manualProbe != null
              ? ref.read(controller.notifier).onAbortPressed
              : () => dialogCompleter(DialogResponse.aborted()),
          child: const Text('general.abort').tr(),
        ),
        if (manualProbe != null) ...[
          IconButton(
            tooltip: tr('dialogs.manual_offset.hint_tooltip'),
            color: Theme.of(context).textTheme.bodySmall?.color,
            onPressed: ref.read(controller.notifier).onHelpPressed,
            icon: const Icon(Icons.quiz_outlined, size: 20),
          ),
          TextButton(
            onPressed: ref.read(controller.notifier).onAcceptPressed,
            child: const Text('general.accept').tr(),
          ),
        ],
      ],
    );
  }
}
