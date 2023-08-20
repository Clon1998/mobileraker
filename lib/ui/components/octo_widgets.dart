/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class OctoEveryWhereBtn extends StatelessWidget {
  const OctoEveryWhereBtn({Key? key, this.onPressed, required this.title})
      : super(key: key);

  final VoidCallback? onPressed;
  final String title;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff7399ff),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Image(
              height: 30,
              width: 30,
              image: AssetImage('assets/images/octo_everywhere.png'),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      );
}

class OctoIndicator extends StatelessWidget {
  const OctoIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'components.octo_indicator.tooltip'.tr(),
      child: const Image(
        height: 20,
        width: 20,
        image: AssetImage('assets/images/octo_everywhere.png'),
      ),
    );
  }
}
