import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintPage extends HookWidget {
  const ImprintPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var imprint =
        Uri.parse('https://www.iubenda.com/privacy-policy/19183925/full-legal');

    var webViewController = useState(WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(imprint));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Content'),
        actions: [
          IconButton(
              tooltip: 'Open in Browser',
              onPressed: () async {
                if (await canLaunchUrl(imprint)) {
                  await launchUrl(imprint,
                      mode: LaunchMode.externalApplication);
                } else {
                  throw 'Could not launch $imprint';
                }
              },
              icon: const Icon(Icons.open_in_browser))
        ],
      ),
      body: WebViewWidget(
        controller: webViewController.value,
      ),
    );
  }
}
