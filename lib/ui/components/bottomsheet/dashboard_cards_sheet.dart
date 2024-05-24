/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';

class DashboardCardsBottomSheet extends HookWidget {
  const DashboardCardsBottomSheet({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.maybeSizeOf(context)?.width ?? 100;

    var availableCards = DashboardComponentType.values;

    return ProviderScope(
      child: DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.8,
        minChildSize: 0.35,
        builder: (ctx, scrollController) {
          var themeData = Theme.of(ctx);

          var cssGrid = AlignedGridView.count(
            controller: scrollController,
            crossAxisCount: 2,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            itemCount: availableCards.length,
            itemBuilder: (ictx, index) {
              var e = availableCards[index];

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelect(ctx, e),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FittedBox(
                    child: SizedBox(
                      width: width,
                      child: AbsorbPointer(
                        child: DasboardCard.preview(
                          type: e,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min, // To make the card compact
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'bottom_sheets.dashboard_cards.title',
                                style: themeData.textTheme.headlineSmall,
                              ).tr(),
                              Text(
                                'bottom_sheets.dashboard_cards.subtitle',
                                textAlign: TextAlign.center,
                                style: themeData.textTheme.bodySmall,
                              ).tr(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Material(
                            type: MaterialType.transparency,
                            child: cssGrid,
                            // child: gridView,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void onSelect(BuildContext context, DashboardComponentType type) {
    logger.i('Selected $type');
    Navigator.of(context).pop(BottomSheetResult.confirmed(type));
  }
}
