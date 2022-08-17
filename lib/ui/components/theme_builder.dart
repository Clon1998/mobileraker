import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/theme_service.dart';

class ThemeBuilder extends ConsumerWidget {
  const ThemeBuilder({Key? key, required this.builder}) : super(key: key);
  final Widget Function(BuildContext, ThemeData?, ThemeData?, ThemeMode?)
      builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var asyncTheme = ref.watch(activeThemeProvider);

    return asyncTheme.when(
        data: (data) => builder(context, data.themePack.lightTheme,
            data.themePack.darkTheme, data.themeMode),
        error: (e, s) => const Text('Unable to load theme Data'),
        loading: () => const CircularProgressIndicator());
  }
}
