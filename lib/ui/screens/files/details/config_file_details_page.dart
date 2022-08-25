import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/properties.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/screens/files/details/config_file_details_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:progress_indicators/progress_indicators.dart';

class ConfigFileDetailPage extends ConsumerWidget {
  const ConfigFileDetailPage({Key? key, required this.file}) : super(key: key);
  final RemoteFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(overrides: [
      configFileProvider.overrideWithValue(file),
      configFileDetailsControllerProvider
    ], child: const _ConfigFileDetail());
  }
}

class _ConfigFileDetail extends HookConsumerWidget {
  const _ConfigFileDetail({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var codeController =
    useValueNotifier(CodeController(language: properties, theme: atomOneDarkTheme));
    var file = ref.watch(configFileProvider);
    ref.listen(configFileDetailsControllerProvider.select((value) => value.config),
        (previous, AsyncValue<String> next) {
      next.whenData((value) => codeController.value.text = value);
    });

    return Scaffold(
      backgroundColor: codeController.value.theme?['root']?.backgroundColor,
      appBar: AppBar(
        title: Text(
          file.name,
          overflow: TextOverflow.fade,
        ),
        actions: [
          // IconButton(onPressed: null, icon: Icon(Icons.live_help_outlined)),
          // IconButton(onPressed: null, icon: Icon(Icons.search))
        ],
      ),
      body: Column(
        children: [
          Expanded(
              child: _Editor(
            codeController: codeController,
          )),
        ],
      ),
      floatingActionButton: (ref
              .watch(configFileDetailsControllerProvider
                  .select((value) => value.config))
              .hasValue)
          ? _Fab(codeController: codeController)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor({Key? key, required this.codeController}) : super(key: key);

  final ValueNotifier<CodeController> codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData themeData = Theme.of(context);

    return ref
        .watch(
            configFileDetailsControllerProvider.select((value) => value.config))
        .maybeWhen(
            orElse: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitRipple(
                        color: themeData.colorScheme.secondary,
                        size: 100,
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      FadingText(
                          'Downloading file ${ref.watch(configFileProvider).name}'),
                      // Text('Fetching printer ...')
                    ],
                  ),
                ),
            data: (file) => _FileReadyBody(
                  codeController: codeController.value,
                ));
  }
}

class _Fab extends ConsumerWidget {
  const _Fab({
    Key? key,
    required this.codeController,
  }) : super(key: key);

  final ValueNotifier<CodeController> codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    if (ref.watch(configFileDetailsControllerProvider).isUploading) {
      return FloatingActionButton(
        backgroundColor: themeData.disabledColor,
        onPressed: null,
        child: const CircularProgressIndicator(),
      );
    }

    return SpeedDial(
      icon: FlutterIcons.save_mdi,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.save),
          backgroundColor: themeData.colorScheme.primaryContainer,
          label: 'Save',
          onTap: () => ref
              .read(configFileDetailsControllerProvider.notifier)
              .onSaveTapped(codeController.value.text),
        ),
        if (!{PrintState.paused, PrintState.printing}.contains(ref.watch(
            printerSelectedProvider
                .select((value) => value.valueOrFullNull?.print.state))))
          SpeedDialChild(
            child: const Icon(Icons.restart_alt),
            backgroundColor: themeData.colorScheme.primary,
            label: 'Save & Restart',
            onTap: () => ref
                .read(configFileDetailsControllerProvider.notifier)
                .onSaveAndRestartTapped(codeController.value.text),
          ),
      ],
      spacing: 5,
      overlayOpacity: 0.5,
    );
  }
}

class _FileReadyBody extends ConsumerWidget {
  const _FileReadyBody({Key? key, required this.codeController})
      : super(key: key);

  final CodeController codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        children: [
          CodeField(
            controller: codeController,
            enabled:
                !ref.watch(configFileDetailsControllerProvider).isUploading,
            // expands: true,
            // wrap: true,
          ),
          const SizedBox(
            height: 30,
          )
        ],
      ),
    );
  }
}
