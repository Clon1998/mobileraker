import 'package:flutter/material.dart';
import 'package:mobileraker/service/ui/theme_service.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';
import 'package:provider/provider.dart';


/// A widget that rebuilds itself with a new theme
class ThemeBuilder extends StatefulWidget {
  final Widget Function(BuildContext, ThemeData?, ThemeData?, ThemeMode?)
      builder;
  final List<ThemePack> themePacks;
  // final ThemeData? lightTheme;
  // final ThemeData? darkTheme;
  // final ThemeMode defaultThemeMode;

  ThemeBuilder({
    Key? key,
    required this.builder,
    required this.themePacks,
    // this.lightTheme,
    // this.darkTheme,
    // this.defaultThemeMode = ThemeMode.system,
  }) : super(key: key);

  @override
  _ThemeBuilderState createState() => _ThemeBuilderState(
        ThemeService(
          themePacks: themePacks,
        ),
      );
}

class _ThemeBuilderState extends State<ThemeBuilder>
    with WidgetsBindingObserver {
  final ThemeService themeService;

  _ThemeBuilderState(this.themeService);

  @override
  Widget build(BuildContext context) {
    return Provider<ThemeService>.value(
      value: themeService,
      builder: (context, child) => StreamProvider<ThemeModel>(
        lazy: false,
        initialData: themeService.initalTheme,
        create: (context) => themeService.themesStream,
        builder: (context, child) => Consumer<ThemeModel>(
          child: child,
          builder: (context, themeModel, child) => widget.builder(
            context,
            themeModel.themePack.lightTheme,
            themeModel.themePack.darkTheme,
            themeModel.themeMode,
          ),
        ),
      ),
    );
  }

  // Get all services
  // final themeService = locator<ThemeService>();
  // @override
  // Widget build(BuildContext context) {
  //   return widget.child;
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed:
        adjustSystemThemeIfNecessary();
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  // Should update theme whenever platform brighteness changes.
  // This makes sure that theme changes even if the brighteness changes from notification bar.
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    adjustSystemThemeIfNecessary();
  }

  //NOTE: re-apply the appropriate theme when the application gets back into the foreground
  void adjustSystemThemeIfNecessary() {
    switch (themeService.selectedMode) {
      // When app becomes inactive the overlay colors might change.
      // Therefore when the app is resumed we also need to update
      // overlay colors back to their original state. In case
      // selected theme mode is system the overlay colors will be
      // automatically updated.
      // case ThemeMode.light:
      // case ThemeMode.dark:
      //   final selectedTheme = themeManager.getSelectedTheme().selectedTheme;
      //   themeManager.updateOverlayColors(selectedTheme);
      //   break;
      // //reapply theme
      // case ThemeMode.system:
      //   themeManager.setThemeMode(ThemeMode.system);
      //   break;
      default:
    }
  }
}
