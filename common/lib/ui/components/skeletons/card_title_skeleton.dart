/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class CardTitleSkeleton extends StatelessWidget {
  factory CardTitleSkeleton.trailingIcon({Widget? leading}) => CardTitleSkeleton(
        leading: leading,
        trailing: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: 24,
            height: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

  factory CardTitleSkeleton.trailingText({Widget? leading}) => CardTitleSkeleton(
        leading: leading,
        trailing: const SizedBox(
          width: 75,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
          ),
        ),
      );

  const CardTitleSkeleton({super.key, this.leading, this.trailing});

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading ??
          const SizedBox(
            width: 24,
            height: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
            ),
          ),
      title: const FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.5,
        child: SizedBox(
          width: double.infinity,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
          ),
        ),
      ),
      trailing: trailing,
    );
  }
}
