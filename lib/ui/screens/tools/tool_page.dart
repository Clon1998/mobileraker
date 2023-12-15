/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/ui/components/drawer/nav_drawer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/info_card.dart';

import '../../../routing/app_router.dart';

class ToolPage extends HookConsumerWidget {
  ToolPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
      ),
      drawer: const NavigationDrawerWidget(),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ListView(
          children: [
            const InfoCard(
              leading: Icon(Icons.info_outline),
              title: Text('Work in progress'),
              body: Text(
                'This page is still work in progress. More tools and links will be added in the future.',
                // textAlign: TextAlign.center,
              ),
            ),
            // Text(
            //   'A collection of tools, links and information to help you with your 3D printing journey.',
            //   style: Theme.of(context).textTheme.labelLarge!,
            //   textAlign: TextAlign.center,
            // ),
            //
            // const Divider(),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  _ToolCard(
                    icon: const Icon(FlutterIcons.md_construct_ion),
                    label: const Text('Belt Tuner'),
                    onTap: () {
                      ref.read(goRouterProvider).goNamed(AppRoute.beltTuner.name);
                    },
                  ),
                  const _ToolCard(
                    icon: Icon(FlutterIcons.question_ant),
                    label: Text('Work In Progress', textAlign: TextAlign.center),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final Widget icon;
  final Widget label;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 132,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox.expand(
                        child: FittedBox(
                          child: icon,
                        ),
                      ),
                    ),
                  ),
                  label,
                ],
              ),
            ),
          ),
        ));
  }
}
