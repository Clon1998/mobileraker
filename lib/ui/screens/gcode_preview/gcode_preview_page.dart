/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/settings_bottom_sheet.dart';
import 'package:mobileraker_pro/gcode_preview/data/model/gcode_structure.dart';
import 'package:mobileraker_pro/gcode_preview/data/model/gcode_visualizer_settings_key.dart';
import 'package:mobileraker_pro/gcode_preview/gcode_layer_renderer.dart';
import 'package:mobileraker_pro/gcode_preview/providers.dart';
import 'package:mobileraker_pro/gcode_preview/ui/gcode_layer_visualizer.dart';

class GCodePreviewPage extends HookConsumerWidget {
  const GCodePreviewPage({super.key, required this.machineUUID, required this.file, this.live = false});

  final String machineUUID;
  final GCodeFile file;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(file.name)),
      body: SafeArea(
        child: _Body(machineUUID: machineUUID, file: file, live: live),
      ),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID, required this.file, required this.live});

  final String machineUUID;
  final GCodeFile file;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSup = ref.watch(isSupporterProvider);
    if (!isSup) {
      return Center(
        child: SupporterOnlyFeature(text: const Text('components.supporter_only_feature.gcode_preview').tr()),
      );
    }

    final configFileAsync = ref.watch(printerProvider(machineUUID).selectAs((value) => value.configFile));

    return configFileAsync.when(
      data: (configFile) => Center(
        child: _GCodeStructureLoader(
          machineUUID: machineUUID,
          file: file,
          resultBuilder: (structure) => live
              ? _LivePreview(machineUUID: machineUUID, configFile: configFile, structure: structure)
              : _StaticPreview(configFile: configFile, structure: structure),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: SimpleErrorWidget(
          title: const Text('components.gcode_preview.error.config.title', textAlign: TextAlign.center).tr(),
          body: const Text('components.gcode_preview.error.config.body').tr(),
        ),
      ),
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
    );
  }
}

// progress == null  → decoding from cache (indeterminate)
// progress 0.0–0.5  → downloading
// progress 0.5–1.0  → parsing
String _progressLabel(double? progress) {
  if (progress == null) return 'components.gcode_preview.loading.cache';
  return progress < 0.5 ? 'components.gcode_preview.downloading.progress' : 'components.gcode_preview.parsing.progress';
}

double _displayValue(double progress) => progress < 0.5 ? progress * 2 : (progress - 0.5) * 2;

/// Watches [gcodeStructureProvider] and shows a combined download+parse
/// progress bar while loading, then calls [resultBuilder] on completion.
class _GCodeStructureLoader extends ConsumerWidget {
  const _GCodeStructureLoader({
    required this.machineUUID,
    required this.file,
    required this.resultBuilder,
  });

  final String machineUUID;
  final GCodeFile file;
  final Widget Function(GCodeStructure) resultBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gcodeStructureProvider(machineUUID, file));
    final themeData = Theme.of(context);
    final percFormat = context.percentNumFormat();

    return switch (async) {
      AsyncData(:final value) => resultBuilder(value),
      AsyncError(:final error) => SimpleErrorWidget(
          title: const Text('components.gcode_preview.error.parsing.title').tr(),
          body: Text(error.toString()),
        ),
      AsyncLoading(:final progress) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // progress is num? internally — cast to double? for our helpers.
              Text(
                _progressLabel(progress?.toDouble()),
                style: themeData.textTheme.bodySmall,
              ).tr(args: progress != null ? [percFormat.format(_displayValue(progress.toDouble()))] : []),
              const SizedBox(height: 8),
              // null → indeterminate (decoding cache); non-null → determinate bar
              LinearProgressIndicator(value: progress != null ? _displayValue(progress.toDouble()) : null),
            ],
          ),
        ),
    };
  }
}

class _StaticPreview extends HookWidget {
  const _StaticPreview({super.key, required this.configFile, required this.structure});

  final ConfigFile configFile;
  final GCodeStructure structure;

  @override
  Widget build(BuildContext context) {
    final renderSupplier = useMemoized(() => GCodeLayerRenderer(structure), [structure]);
    final currentLayer = useState(0);
    final currentMove = useState<int?>(null);
    useEffect(() {
      currentMove.value = null;
      return null;
    }, [currentLayer.value]);

    final handleLayerChange = useCallback((double value) {
      currentLayer.value = value.toInt();
    }, []);

    final handleMoveChange = useCallback((double value) {
      currentMove.value = value.toInt();
    }, []);

    final currentLayerData = useMemoized(
      () => renderSupplier.createRenderDataForLayer(layerIndex: currentLayer.value, stopAtMove: currentMove.value),
      [currentLayer.value, currentMove.value],
    );
    final maxLayers = structure.layers.length;
    final themeData = Theme.of(context);
    final maxScale = sqrt(configFile.sizeX * configFile.sizeX + configFile.sizeY * configFile.sizeY) / 42;
    final numFormat = context.numFormat();
    return Stack(
      children: [
        InteractiveViewer(
          maxScale: maxScale,
          child: Center(
            child: GCodeLayerVisualizer(printerConfig: configFile, currentLayer: currentLayerData),
          ),
        ),
        Consumer(
          builder: (context, ref, child) {
            return Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                onPressed: () {
                  ref
                      .read(bottomSheetServiceProvider)
                      .show(gCodeVisualizerSettingsSheetConfig());
                },
                icon: const Icon(Icons.settings),
              ),
            );
          },
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Text.rich(
            TextSpan(
              style: themeData.textTheme.bodySmall,
              children: [
                TextSpan(text: tr('components.gcode_preview.layer.one')),
                const TextSpan(text: ': '),
                TextSpan(
                  text: '${numFormat.format((currentLayer.value) + 1)}/${numFormat.format(maxLayers)}',
                  style: themeData.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '\n'),
                TextSpan(text: tr('components.gcode_preview.move.one')),
                const TextSpan(text: ': '),
                TextSpan(
                  text:
                      '${numFormat.format((currentMove.value ?? currentLayerData.metaData.moveEnd) - currentLayerData.metaData.moveStart)}/'
                      '${numFormat.format(currentLayerData.metaData.moveEnd - currentLayerData.metaData.moveStart)}',
                  style: themeData.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        if (maxLayers > 1)
          Positioned(
            top: 25,
            bottom: 40,
            right: 0,
            child: RotatedBox(
              quarterTurns: -1,
              child: Slider(
                value: currentLayer.value.toDouble(),
                onChanged: handleLayerChange,
                max: (maxLayers - 1).toDouble(),
              ),
            ),
          ),
        Positioned(
          bottom: 0,
          left: 25,
          right: 40,
          child: Slider(
            value: (currentMove.value ?? currentLayerData.metaData.moveEnd).toDouble(),
            onChanged: handleMoveChange,
            min: currentLayerData.metaData.moveStart.toDouble(),
            max: currentLayerData.metaData.moveEnd.toDouble(),
          ),
        ),
      ],
    );
  }
}

class _LivePreview extends HookConsumerWidget {
  const _LivePreview({super.key, required this.machineUUID, required this.configFile, required this.structure});

  final String machineUUID;
  final ConfigFile configFile;
  final GCodeStructure structure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderSupplier = useMemoized(() => GCodeLayerRenderer(structure), [structure]);

    final filePos = ref.watch(
      printerProvider(machineUUID).selectRequireValue((d) => d.virtualSdCard?.filePosition ?? 0),
    );

    final currentLayerData = useMemoized(() => renderSupplier.createRenderDataForFilePosition(filePos), [filePos]);

    final currentLayer = currentLayerData.metaData.layer;
    final maxMove = currentLayerData.metaData.moveEnd - currentLayerData.metaData.moveStart;
    final currentMove = currentLayerData.metaData.currentMove - currentLayerData.metaData.moveStart;
    final int maxLayers = structure.maxLayer;

    final themeData = Theme.of(context);
    final numFormat = context.numFormat();
    final maxScale = sqrt(configFile.sizeX * configFile.sizeX + configFile.sizeY * configFile.sizeY) / 42;

    final layerText = '${numFormat.format(currentLayer + 1)}/${numFormat.format(maxLayers)}';
    final moveText = '${numFormat.format(currentMove)}/${numFormat.format(maxMove)}';

    return Stack(
      children: [
        InteractiveViewer(
          maxScale: maxScale,
          child: Center(
            child: GCodeLayerVisualizer(printerConfig: configFile, currentLayer: currentLayerData),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Text.rich(
            TextSpan(
              style: themeData.textTheme.bodySmall,
              children: [
                TextSpan(text: tr('components.gcode_preview.layer.one')),
                const TextSpan(text: ': '),
                TextSpan(
                  text: layerText,
                  style: themeData.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '\n'),
                TextSpan(text: tr('components.gcode_preview.move.one')),
                const TextSpan(text: ': '),
                TextSpan(
                  text: moveText,
                  style: themeData.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const Positioned(top: 8, right: 8, child: Chip(label: Text('Live'))),
        Consumer(
          builder: (context, ref, child) {
            return Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                onPressed: () {
                  ref
                      .read(bottomSheetServiceProvider)
                      .show(gCodeVisualizerSettingsSheetConfig());
                },
                icon: const Icon(Icons.settings),
              ),
            );
          },
        ),
      ],
    );
  }
}

BottomSheetConfig gCodeVisualizerSettingsSheetConfig() {
  return BottomSheetConfig(
    type: SheetType.changeSettings,
    data: SettingsBottomSheetArgs(title: tr('components.gcode_preview_settings_sheet.title'), settings: [
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showGrid, title: tr('components.gcode_preview_settings_sheet.show_grid.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_travel.subtitle')),
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showAxes, title: tr('components.gcode_preview_settings_sheet.show_axes.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_axes.subtitle')),
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showNextLayer, title: tr('components.gcode_preview_settings_sheet.show_next_layer.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_next_layer.subtitle')),
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showPreviousLayer, title: tr('components.gcode_preview_settings_sheet.show_previous_layer.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_previous_layer.subtitle')),
      DividerSettingItem(),
      NumSettingItem(settingKey: GCodeVisualizerSettingsKey.extrusionWidthMultiplier, title: tr('components.gcode_preview_settings_sheet.extrusion_width_multiplier.prefix')),
      DividerSettingItem(),
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showExtrusion, title: tr('components.gcode_preview_settings_sheet.show_extrusion.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_extrusion.subtitle')),
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showRetraction, title: tr('components.gcode_preview_settings_sheet.show_retraction.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_retraction.subtitle')),
      SwitchSettingItem(settingKey: GCodeVisualizerSettingsKey.showTravel, title: tr('components.gcode_preview_settings_sheet.show_travel.title'), subtitle: tr('components.gcode_preview_settings_sheet.show_travel.subtitle')),

    ]),
  );
}
