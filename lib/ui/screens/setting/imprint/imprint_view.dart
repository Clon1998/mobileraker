import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintPage extends HookWidget {
  const ImprintPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var webViewController = useState(WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(
          'https://www.iubenda.com/privacy-policy/19183925/full-legal')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Content'),
      ),
      body: WebViewWidget(
        controller: webViewController.value,
      ),
    );
  }
}
