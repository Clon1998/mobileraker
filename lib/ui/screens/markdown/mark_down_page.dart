/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:progress_indicators/progress_indicators.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'mark_down_page.g.dart';

@riverpod
Future<String> _markdownData(_MarkdownDataRef _, Uri mdRoot) async {
  http.Response res = await http.get(mdRoot);

  if (res.statusCode != 200) {
    throw HttpException(res.body);
  }

  return res.body;
}

class MarkDownPage extends StatelessWidget {
  const MarkDownPage({
    super.key,
    required this.title,
    required this.mdRoot,
    required this.mdHuman,
    this.topWidget,
  });

  final String title;
  final Uri mdRoot;
  final Uri mdHuman;

  /// Widget placed at the top of the markdown page
  final Widget? topWidget;

  @override
  Widget build(BuildContext context) {
    Widget body = Center(
      child: ResponsiveLimit(
        child: Column(
          children: [
            if (topWidget != null)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: topWidget!,
              ),
            Expanded(
              child: _MarkDownBody(
                mdHuman: mdHuman,
                mdRoot: mdRoot,
                title: title,
              ),
            ),
          ],
        ),
      ),
    );
    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: tr('pages.markdown.open_in_browser', args: [title]),
            onPressed: () => launchUrl(mdHuman, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_browser),
          ),
        ],
      ),
      drawer: const NavigationDrawerWidget(),
      body: body,
    );
  }
}

class _MarkDownBody extends ConsumerWidget {
  const _MarkDownBody({
    super.key,
    required this.mdRoot,
    required this.mdHuman,
    required this.title,
  });
  final Uri mdRoot;
  final Uri mdHuman;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(_markdownDataProvider(mdRoot)).when(
        data: (data) => _MakrdownViewer(data: data),
        error: (e, _) => _ErrorWidget(
          error: e,
          mdHuman: mdHuman,
          title: title,
        ),
        loading: () => const _LoadingMarkdownWidget(),
      );
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({
    super.key,
    this.error,
    required this.mdHuman,
    required this.title,
  });

  final Object? error;
  final Uri mdHuman;
  final String title;

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
            Icon(
              Icons.warning_amber_outlined,
              size: 50,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 20),
            const Text('pages.markdown.error').tr(args: [title]),
            Text(error?.toString() ?? 'Unknown cause'),
            TextButton.icon(
              onPressed: () => launchUrl(mdHuman, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('pages.markdown.open_in_browser').tr(args: [title]),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMarkdownWidget extends StatelessWidget {
  const _LoadingMarkdownWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SpinKitFoldingCube(color: Theme.of(context).colorScheme.secondary),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: FadingText('${tr('general.loading')} ...'),
        ),
      ],
    );
  }
}

class _MakrdownViewer extends StatelessWidget {
  const _MakrdownViewer({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    var base = MarkdownStyleSheet(
      blockquote: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.8),
        border: Border(
          left: BorderSide(
            width: 3.0,
            color: theme.colorScheme.secondary,
          ),
        ),
      ),
    );

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
