/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/animation/SizeAndFadeTransition.dart';
import 'package:mobileraker/ui/components/dialog/manual_offset/manual_offset_controller.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/components/range_selector.dart';

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

    return WillPopScope(
      onWillPop: ref.read(controller.notifier).onPopTriggered,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
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
              AnimatedSwitcher(
                switchInCurve: Curves.easeInCirc,
                switchOutCurve: Curves.easeOutExpo,
                transitionBuilder: (child, anim) => SizeAndFadeTransition(
                  sizeAndFadeFactor: anim,
                  child: child,
                ),
                duration: kThemeAnimationDuration,
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
                                      onPressed: () => ref
                                          .read(controller.notifier)
                                          .onOffsetMinusPressed(
                                            offsetSteps[selectedStep.value],
                                          ),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    // IconButton(
                                    //     style: IconButton.styleFrom(
                                    //         minimumSize: Size.square(100),
                                    //         foregroundColor: Colors.green,
                                    //         backgroundColor: Colors.pink),
                                    //     onPressed: () => null,
                                    //     icon: const Icon(Icons.save)),
                                    IntrinsicWidth(
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
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => ref
                                          .read(controller.notifier)
                                          .onOffsetPlusPressed(
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
                                      floatingLabelBehavior: FloatingLabelBehavior.always,
                                      label: Text(
                                        '${'pages.dashboard.general.move_card.step_size'.tr()} [mm]',
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    child: RangeSelector(
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
              _Footer(dialogCompleter: completer),
            ],
          ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Row(
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
      ),
    );
  }
}
