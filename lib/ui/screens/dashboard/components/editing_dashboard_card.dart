/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class EditingDashboardCard extends HookWidget {
  const EditingDashboardCard({
    super.key,
    required this.child,
    this.onRemovedTap,
    this.onEditTap,
  });

  final Widget child;

  final void Function()? onRemovedTap;
  final void Function()? onEditTap;

  @override
  Widget build(BuildContext context) {
    var tapped = useState(false);
    var animationController = useAnimationController(duration: kThemeAnimationDuration);
    // animationController.forward();

    final ignoreActions = useListenableSelector(animationController, () => animationController.isAnimating);

    return GestureDetector(
      onTap: () async {
        if (ignoreActions) return;
        if (tapped.value) {
          await animationController.reverse();
        } else {
          animationController.forward();
        }
        tapped.value = !tapped.value;
      },
      child: Stack(
        children: [
          child,
          if (tapped.value)
            Positioned.fill(
              child: FadeTransition(
                opacity: animationController.drive(CurveTween(curve: Curves.linear)),
                child: Card(
                  color: Colors.black.withOpacity(0.75),
                  // margin: EdgeInsets.all(4.0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        //TODO: Add ability to edit indepth details/Card specific settings or something like "Show while printing"...
                        // IconButton(
                        //   onPressed: onEditTap,
                        //   icon: const Icon(Icons.edit),
                        //   iconSize: 45,
                        //   color: Colors.white,
                        // ),
                        // const SizedBox(width: 24.0),
                        IconButton(
                          onPressed: onRemovedTap,
                          icon: const Icon(Icons.delete),
                          iconSize: 45,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
