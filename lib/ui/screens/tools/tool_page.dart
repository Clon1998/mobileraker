/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/ui/components/info_card.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../routing/app_router.dart';

class ToolPage extends HookConsumerWidget {
  const ToolPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = Padding(
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
                    icon: const Icon(Icons.graphic_eq),
                    label: const Text('pages.beltTuner.title').tr(),
                    onTap: () {
                      ref.read(goRouterProvider).goNamed(AppRoute.beltTuner.name);
                    },
                  ),
                  const _UrlToolCard(
                    icon: Icon(FlutterIcons.speedometer_slow_mco),
                    label: Text('Shake & Tune'),
                    url: 'https://github.com/Frix-x/klippain-shaketune',
                  ),
                  // const _ToolCard(
                  //   icon: Icon(FlutterIcons.question_ant),
                  //   label: Text('Work In Progress', textAlign: TextAlign.center),
                  // ),
                ],
              ),
            ),
          ],
        ),
    );

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('pages.tool.title').tr()),
      drawer: const NavigationDrawerWidget(),
      body: body,
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
                    child: SizedBox.expand(child: FittedBox(child: icon)),
                  ),
                ),
                label,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UrlToolCard extends HookWidget {
  const _UrlToolCard({
    super.key,
    required this.icon,
    required this.label,
    required this.url,
  });

  final Widget icon;
  final Widget label;
  final String url;

  @override
  Widget build(BuildContext context) {
    var launching = useState(false);

    launch() async {
      if (await canLaunchUrlString(url)) {
        launching.value = true;
        launchUrlString(url, mode: LaunchMode.externalApplication).whenComplete(() => launching.value = false);
      } else {
        throw 'Could not launch $url';
      }
    }

    return _ToolCard(
      icon: icon,
      label: label,
      onTap: launching.value ? null : launch,
    );
  }
}
