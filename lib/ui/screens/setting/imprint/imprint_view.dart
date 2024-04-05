/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintPage extends HookWidget {
  const ImprintPage({super.key});

  @override
  Widget build(BuildContext context) {
    var imprint =
        Uri.parse('https://www.iubenda.com/privacy-policy/19183925/full-legal');

    var imprintLoaded = useState(false);

    WebViewController webViewController = useMemoized<WebViewController>(() {
      var webVC = WebViewController();
      webVC.clearCache().then((value) async {
        await webVC.setJavaScriptMode(JavaScriptMode.unrestricted);
        await webVC.loadRequest(imprint);
        imprintLoaded.value = true;
      });
      return webVC;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Content'),
        actions: [
          IconButton(
            tooltip: 'Open in Browser',
            onPressed: imprintLoaded.value
                ? () async {
                    if (await canLaunchUrl(imprint)) {
                      await launchUrl(
                        imprint,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      throw 'Could not launch $imprint';
                    }
                  }
                : null,
            icon: const Icon(Icons.open_in_browser),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: child,
        ),
        duration: kThemeAnimationDuration,
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: (imprintLoaded.value)
            ? WebViewWidget(controller: webViewController)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitFoldingCube(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: FadingText('${tr('general.loading')} ...'),
                  ),
                ],
              ),
      ),
    );
  }
}
