import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintView extends StatelessWidget {
  const ImprintView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Legal Content'),
        ),
        body: WebView(
          initialUrl:
              'https://www.iubenda.com/privacy-policy/19183925/full-legal',
          javascriptMode: JavascriptMode.unrestricted,
        ),
      );
}
