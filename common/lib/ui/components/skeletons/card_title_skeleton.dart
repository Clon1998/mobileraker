/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

class CardTitleSkeleton extends StatelessWidget {
  factory CardTitleSkeleton.trailingIcon({Widget? leading}) => CardTitleSkeleton(
        leading: leading,
        trailing: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          width: 24,
          height: 24,
          color: Colors.white,
        ),
      );

  factory CardTitleSkeleton.trailingText({Widget? leading}) => CardTitleSkeleton(
        leading: leading,
        trailing: Container(
          width: 75,
          height: 20,
          color: Colors.white,
        ),
      );

  const CardTitleSkeleton({super.key, this.leading, this.trailing});

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading ??
          Container(
            width: 24,
            height: 24,
            color: Colors.white,
          ),
      title: Container(
        width: double.infinity,
        height: 20,
        color: Colors.white,
      ),
      trailing: trailing,
    );
  }
}
