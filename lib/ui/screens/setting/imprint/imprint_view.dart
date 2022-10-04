import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintPage extends StatelessWidget {
  const ImprintPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Legal Content'),
        ),
        body: const WebView(
          initialUrl:
              'https://www.iubenda.com/privacy-policy/19183925/full-legal',
          javascriptMode: JavascriptMode.unrestricted,
        ),
      );
}
