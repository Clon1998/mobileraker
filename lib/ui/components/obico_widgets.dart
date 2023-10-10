/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ObicoIndicator extends StatelessWidget {
  const ObicoIndicator({
    Key? key,
    this.size,
  }) : super(key: key);

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
