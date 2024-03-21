/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ObicoIndicator extends StatelessWidget {
  const ObicoIndicator({super.key, this.size});

  final Size? size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('components.obico_indicator.tooltip'),
      child: SvgPicture.asset(
        'assets/vector/obico_logo.svg',
        width: size?.width ?? 20,
        height: size?.height ?? 20,
      ),
    );
  }
}

class ObicoButton extends StatelessWidget {
  const ObicoButton({super.key, this.onPressed, required this.title});

  final VoidCallback? onPressed;
  final String title;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff01a299),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/vector/obico_logo.svg',
              width: 30,
              height: 30,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
}
