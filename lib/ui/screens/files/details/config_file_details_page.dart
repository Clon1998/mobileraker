/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:code_text_field/code_text_field.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:highlight/languages/properties.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/files/details/config_file_details_controller.dart';
import 'package:progress_indicators/progress_indicators.dart';

class ConfigFileDetailPage extends ConsumerWidget {
  const ConfigFileDetailPage({super.key, required this.file});

  final GenericFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        configFileProvider.overrideWithValue(file),
        configFileDetailsControllerProvider,
      ],
      child: const _ConfigFileDetail(),
    );
  }
}

class _ConfigFileDetail extends HookConsumerWidget {
  const _ConfigFileDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var codeController = useValueNotifier(CodeController(language: properties));
    var file = ref.watch(configFileProvider);
    ref.listen(
      configFileDetailsControllerProvider.select((value) => value.config),
      (previous, AsyncValue<String> next) {
        next.whenData((value) => codeController.value.text = value);
      },
    );

    return Scaffold(
      backgroundColor: atomOneDarkTheme['root']!.backgroundColor,
      appBar: AppBar(
        title: Text(file.name, overflow: TextOverflow.fade),
        actions: [
          // IconButton(onPressed: null, icon: Icon(Icons.live_help_outlined)),
          // IconButton(onPressed: null, icon: Icon(Icons.search))
          Consumer(
            builder: (ctx, ref, _) {
              final controller = ref.watch(configFileDetailsControllerProvider.notifier);
              final canShare = ref.watch(configFileDetailsControllerProvider
                  .select((s) => !s.isSharing && !s.isUploading && s.config.hasValue));

              return IconButton(
                onPressed: canShare ? () => controller.share(ctx) : null,
                icon: const Icon(Icons.share),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [Expanded(child: _Editor(codeController: codeController))],
      ),
      floatingActionButton: (ref.watch(configFileDetailsControllerProvider.select((value) => value.config)).hasValue)
          ? _Fab(codeController: codeController)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

class _Editor extends ConsumerWidget {
  const _Editor({super.key, required this.codeController});

  final ValueNotifier<CodeController> codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData themeData = Theme.of(context);
    var textStyleOnError = TextStyle(color: themeData.colorScheme.onErrorContainer);
    return ref
        .watch(
          configFileDetailsControllerProvider.select((value) => value.config),
        )
        .when(
          error: (e, _) => ErrorCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    FlutterIcons.issue_opened_oct,
                    color: themeData.colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    'Error while loading file!',
                    style: textStyleOnError,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(e.toString(), style: textStyleOnError),
                ),
              ],
            ),
          ),
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpinKitRipple(
                  color: themeData.colorScheme.secondary,
                  size: 100,
                ),
                const SizedBox(height: 30),
                FadingText(
                  'Downloading file ${ref.watch(configFileProvider).name}',
                ),
                // Text('Fetching printer ...')
              ],
            ),
          ),
          data: (file) => _FileReadyBody(
            codeController: codeController.value,
          ),
        );
  }
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key, required this.codeController});

  final ValueNotifier<CodeController> codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    var uploading = ref.watch(configFileDetailsControllerProvider).isUploading;
    return SpeedDial(
      icon: FlutterIcons.save_mdi,
      activeIcon: Icons.close,
      children: uploading
          ? []
          : [
              SpeedDialChild(
                child: const Icon(Icons.save),
                backgroundColor: themeData.colorScheme.primaryContainer,
                foregroundColor: themeData.colorScheme.onPrimaryContainer,
                label: 'Save',
                onTap: () =>
                    ref.read(configFileDetailsControllerProvider.notifier).onSaveTapped(codeController.value.text),
              ),
              if (!{PrintState.paused, PrintState.printing}.contains(ref.watch(
                printerSelectedProvider.select((value) => value.valueOrFullNull?.print.state),
              )))
                SpeedDialChild(
                  child: const Icon(Icons.restart_alt),
                  backgroundColor: themeData.colorScheme.primary,
                  foregroundColor: themeData.colorScheme.onPrimary,
                  label: 'Save & Restart',
                  onTap: () => ref
                      .read(configFileDetailsControllerProvider.notifier)
                      .onSaveAndRestartTapped(codeController.value.text),
                ),
            ],
      spacing: 5,
      overlayOpacity: 0.5,
      backgroundColor: uploading ? themeData.disabledColor : null,
      child: uploading ? const CircularProgressIndicator.adaptive() : null,
    );
  }
}

class _FileReadyBody extends ConsumerWidget {
  const _FileReadyBody({super.key, required this.codeController});

  final CodeController codeController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        children: [
          CodeTheme(
            data: const CodeThemeData(styles: atomOneDarkTheme),
            child: CodeField(
              controller: codeController,
              enabled: !ref.watch(configFileDetailsControllerProvider).isUploading,
              // expands: true,
              // wrap: true,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
