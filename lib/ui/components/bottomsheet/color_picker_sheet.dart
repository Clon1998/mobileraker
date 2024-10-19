/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/mobileraker_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class ColorPickerSheet extends HookConsumerWidget {
  const ColorPickerSheet({super.key, this.initialColor});

  final String? initialColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ValueNotifier<Color> hex = useValueNotifier(initialColor?.toColor() ?? Colors.orange);
    // 104ac5F

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: IntrinsicHeight(
          child: HueRingPicker(
            pickerColor: initialColor?.toColor() ?? Colors.orange,
            onColorChanged: (color) => hex.value = color,
            // colorPickerWidth: 300,
            enableAlpha: false,
            displayThumbColor: true,
          ),
        ),
      ),
    );

    final themeData = Theme.of(context);
    final bottom = StickyBottomBarVisibility(
      child: Theme(
        data: themeData.copyWith(useMaterial3: false),
        child: BottomAppBar(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor: themeData.colorScheme.primary, backgroundColor: themeData.colorScheme.surface),
                  onPressed: () {
                    Navigator.pop(context, BottomSheetResult.confirmed(null));
                  },
                  icon: const Icon(Icons.search_off),
                  tooltip: 'general.clear'.tr(),
                  // child: Text('general.clear').tr(),
                ),
                const Gap(8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, BottomSheetResult.confirmed(colorToHex(hex.value, enableAlpha: false)));
                    },
                    child: Text('general.select').tr(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return MobilerakerSheet(
      padding: EdgeInsets.zero,
      hasScrollable: true,
      child: SheetContentScaffold(
        resizeBehavior: const ResizeScaffoldBehavior.avoidBottomInset(maintainBottomBar: true),
        body: body,
        bottomBar: bottom,
      ),
    );

    // return MobilerakerSheet(
    //   child: SheetContentScaffold(
    //     appBar: AppBar(
    //       backgroundColor: Theme
    //           .of(context)
    //           .colorScheme
    //           .secondaryContainer,
    //       leading: IconButton(
    //         icon: const Icon(Icons.close),
    //         onPressed: () => Navigator.of(context).pop(),
    //       ),
    //     ),
    //     body:,
    //     bottomBar: StickyBottomBarVisibility(
    //       child: BottomAppBar(
    //         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
    //         child: ElevatedButton(
    //           onPressed: () {
    //             Navigator.pop(context, BottomSheetResult.confirmed(colorToHex(hex.value, enableAlpha: false)));
    //           },
    //           child: Text(MaterialLocalizations
    //               .of(context)
    //               .keyboardKeySelect),
    //         ),
    //       ),
    //     ),
    //   ),
    // );
  }
}

class _MySheet extends StatelessWidget {
  const _MySheet();

  @override
  Widget build(BuildContext context) {
    // Create a content whatever you want.
    // ScrollableSheet works with any scrollable widget such as
    // ListView, GridView, CustomScrollView, etc.
    final content = ListView.builder(
      itemCount: 50,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text('Item $index'),
        );
      },
    );

    // Just wrap the content in a ScrollableSheet!
    final sheet = ScrollableSheet(
      maxPosition: SheetAnchor.proportional(0.8),
      initialPosition: SheetAnchor.proportional(0.5),
      minPosition: SheetAnchor.proportional(0.2),

      // initialPosition: SheetAnchor.proportional(0.4),
      child: buildSheetBackground(context, content),
      // Optional: Comment out the following lines to add multiple stop positions.
      //
      // minPosition: const SheetAnchor.proportional(0.2),
      // physics: BouncingSheetPhysics(
      //   parent: SnappingSheetPhysics(
      //     snappingBehavior: SnapToNearest(
      //       snapTo: [
      //         const SheetAnchor.proportional(0.2),
      //         const SheetAnchor.proportional(0.5),
      //         const SheetAnchor.proportional(1),
      //       ],
      //     ),
      //   ),
      // ),
    );

    return SafeArea(bottom: false, child: sheet);
  }

  Widget buildSheetBackground(BuildContext context, Widget content) {
    // Add background color, circular corners and material shadow to the sheet.
    // This is just an example, you can customize it however you want.
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
