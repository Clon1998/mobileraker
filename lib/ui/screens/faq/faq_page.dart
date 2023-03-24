import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'faq_page.g.dart';

final faqRoot = Uri.parse(
    'https://raw.githubusercontent.com/Clon1998/mobileraker/master/docs/faq.md');

final faqRootHuman = Uri.parse(
    'https://github.com/Clon1998/mobileraker/blob/master/docs/faq.md');

@riverpod
Future<String> _markdownData(_MarkdownDataRef ref) async {
  http.Response res = await http.get(faqRoot);

  if (res.statusCode != 200) {
    throw HttpException(res.body);
  }

  return res.body;
}

class FaqPage extends StatelessWidget {
  const FaqPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('pages.faq.title').tr()),
      drawer: const NavigationDrawerWidget(),
      body: const _FAQBody(),
    );
  }
}

class _FAQBody extends ConsumerWidget {
  const _FAQBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(_markdownDataProvider).when(
          data: (data) => _MakrdownViewer(data: data),
          error: (e, _) => _ErrorWidget(
                error: e,
              ),
          loading: () => const _LoadingMarkdownWidget());
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({Key? key, this.error}) : super(key: key);

  final Object? error;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          boxShadow: [
            if (theme.brightness == Brightness.light)
              BoxShadow(
                color: theme.colorScheme.shadow,
                offset: const Offset(0.0, 4.0), //(x,y)
                blurRadius: 1.0,
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_outlined,
                size: 50, color: theme.colorScheme.error),
            const SizedBox(
              height: 20,
            ),
            Text('${tr('pages.faq.error')}:'),
            Text(error?.toString() ?? 'Unknown cause'),
            TextButton.icon(
                onPressed: () => launchUrl(faqRootHuman,
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('pages.faq.open_in_browser').tr())
          ],
        ),
      ),
    );
  }
}

class _LoadingMarkdownWidget extends StatelessWidget {
  const _LoadingMarkdownWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SpinKitFoldingCube(
          color: Theme.of(context).colorScheme.secondary,
        ),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: FadingText('${tr('general.loading')} ...'))
      ],
    );
  }
}

class _MakrdownViewer extends StatelessWidget {
  const _MakrdownViewer({Key? key, required this.data}) : super(key: key);

  final String data;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    var base = MarkdownStyleSheet(
        blockquote: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        blockquoteDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.8),
            border: Border(
                left: BorderSide(
                    width: 3.0, color: theme.colorScheme.secondary))));

    return Markdown(
      styleSheet: MarkdownStyleSheet.fromTheme(theme).merge(base),
      data: data,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrlString(href, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
