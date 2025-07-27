/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerFileList extends StatelessWidget {
  const ShimmerFileList({super.key, this.showSortingHeaderAction = true});

  final bool showSortingHeaderAction;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: Colors.grey,
      highlightColor: themeData.colorScheme.background,
      child: CustomScrollView(
        physics: const RangeMaintainingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 20,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                    ),
                    Spacer(),
                    if (showSortingHeaderAction)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverList.separated(
            separatorBuilder: (context, index) => const Divider(height: 0, indent: 18, endIndent: 18),
            itemCount: 20,
            itemBuilder: (context, index) {
              return const ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
                horizontalTitleGap: 8,
                leading: SizedBox(
                  width: 42,
                  height: 42,
                  child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                ),
                trailing: Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: DecoratedBox(decoration: BoxDecoration(color: Colors.white)),
                  ),
                ),
                title: FractionallySizedBox(
                  alignment: Alignment.bottomLeft,
                  widthFactor: 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                    child: Text(' '),
                  ),
                ),
                dense: true,
                subtitle: FractionallySizedBox(
                  alignment: Alignment.bottomLeft,
                  widthFactor: 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white),
                    child: Text(' '),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
