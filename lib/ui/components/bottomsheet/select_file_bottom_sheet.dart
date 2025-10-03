/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/exceptions/file_fetch_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/time_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/files/components/shimmer_file_list.dart';
import 'package:persistent_header_adaptive/persistent_header_adaptive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../screens/files/components/remote_file_list_tile.dart';
import '../../screens/files/components/sorted_file_list_header.dart';

part 'select_file_bottom_sheet.freezed.dart';
part 'select_file_bottom_sheet.g.dart';

class SelectFileBottomSheet extends HookConsumerWidget {
  const SelectFileBottomSheet({super.key, required this.args});

  final SelectFileBottomSheetArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var split = args.path.split('/');
    final isRoot = split.length <= 1;
    final folderName = split.lastOrNull ?? 'Unknown';

    return SheetContentScaffold(
      topBar: ListTile(
        visualDensity: VisualDensity.compact,
        titleAlignment: ListTileTitleAlignment.center,
        leading: IconButton(onPressed: context.pop, icon: Icon(isRoot ? Icons.close : Icons.arrow_back)),
        // leading: arguments.leading,
        horizontalTitleGap: 8,
        title: Text(isRoot ? tr('bottom_sheets.select_file.title') : folderName),
        subtitle: Text(split.join(' > ')),
        minLeadingWidth: 42,
      ),
      body: _Body(args: args),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.args});

  final SelectFileBottomSheetArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_selectFileBottomSheetControllerProvider(args.machineUUID, args.path));
    final controller = ref.watch(_selectFileBottomSheetControllerProvider(args.machineUUID, args.path).notifier);

    final widget = switch (model) {
      AsyncValue(hasValue: true, value: _Model(:final sortConfig, :final folderContent) && final content) =>
        _FileListData(
          key: Key('${args.path}-list'),
          machineUUID: args.machineUUID,
          onSortMode: controller.onSortMode,
          sortConfig: sortConfig,
          folderContent: folderContent,
        ),
      AsyncError(:final error, :final stackTrace) => _FileListError(
        key: Key('${args.path}-list-error'),
        machineUUID: args.machineUUID,
        filePath: args.path,
        error: error,
        stack: stackTrace,
      ),
      _ => ShimmerFileList(showSortingHeaderAction: false),
    };

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeInOutSine,
      switchOutCurve: Curves.easeInOutSine.flipped,
      child: widget,
    );
  }
}

class _FileListData extends ConsumerWidget {
  const _FileListData({
    super.key,
    required this.machineUUID,
    required this.onSortMode,
    required this.sortConfig,
    required this.folderContent,
  });

  final String machineUUID;
  final Future<void> Function() onSortMode;
  final FolderContentWrapper folderContent;
  final SortConfiguration sortConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));
    final themeData = Theme.of(context);
    return CustomScrollView(
      slivers: [
        AdaptiveHeightSliverPersistentHeader(
          floating: true,
          initialHeight: 48,
          needRepaint: true,
          child: SortedFileListHeader(activeSortConfig: sortConfig, onTapSortMode: onSortMode),
        ),
        if (folderContent.isEmpty)
          SliverFillRemaining(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: 0.3,
                    child: SvgPicture.asset('assets/vector/undraw_void_-3-ggu.svg'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('pages.files.empty_folder.title', style: themeData.textTheme.titleMedium).tr(),
                Text('pages.files.empty_folder.subtitle', style: themeData.textTheme.bodySmall).tr(),
              ],
            ),
          ),
        if (folderContent.isNotEmpty)
        SliverPadding(
          padding: MediaQuery.viewPaddingOf(context),
          sliver: SliverList.separated(
            separatorBuilder: (_, _) => const Divider(height: 0, indent: 18, endIndent: 18),
            itemCount: folderContent.totalItems,
            itemBuilder: (context, index) {
              final file = folderContent.unwrapped[index];
              final sortMode = sortConfig.mode;

              return _FileItem(machineUUID: machineUUID, file: file, dateFormat: dateFormat, sortMode: sortMode);
            },
          ),
        ),
      ],
    );
  }
}

class _FileListError extends ConsumerWidget {
  const _FileListError({
    super.key,
    required this.machineUUID,
    required this.filePath,
    required this.error,
    required this.stack,
  });

  final String machineUUID;
  final String filePath;
  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (error is FileFetchException) {
      FileFetchException ffe = error as FileFetchException;
      String message = ffe.message;
      if (ffe.parent != null) {
        message += '\n${ffe.parent}';
      }

      var themeData = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SimpleErrorWidget(
            title: Text('Unable to fetch files!', style: themeData.textTheme.titleMedium),
            body: Text(message, textAlign: TextAlign.center, style: themeData.textTheme.bodySmall),
            action: TextButton.icon(
              onPressed: () => ref.invalidate(_selectFileBottomSheetControllerProvider(machineUUID, filePath)),
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('general.retry').tr(),
            ),
          ),
        ),
      );
    }

    return ErrorCard(
      title: const Text('Unable to fetch files!'),
      body: Column(
        children: [
          Text('The following error occued while trying to fetch files:n$error'),
          TextButton(
            // onPressed: model.showPrinterFetchingErrorDialog,
            onPressed: () => ref
                .read(dialogServiceProvider)
                .show(
                  DialogRequest(
                    type: CommonDialogs.stacktrace,
                    title: error.runtimeType.toString(),
                    body: 'Exception:\n$error\n\n$stack',
                  ),
                ),
            child: const Text('Show Full Error'),
          ),
        ],
      ),
    );
  }
}

class _FileItem extends ConsumerWidget {
  const _FileItem({
    super.key,
    required this.machineUUID,
    required this.file,
    required this.dateFormat,
    required this.sortMode,
  });

  final String machineUUID;
  final RemoteFile file;
  final DateFormat dateFormat;
  final SortMode sortMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_selectFileBottomSheetControllerProvider(machineUUID, file.parentPath).notifier);

    var numberFormat = NumberFormat.decimalPatternDigits(
      locale: context.locale.toStringWithSeparator(),
      decimalDigits: 1,
    );

    Widget subtitle = switch (sortMode) {
      SortMode.size => Text(numberFormat.formatFileSize(file.size)),
      SortMode.estimatedPrintTime when file is GCodeFile => Text(
        (file as GCodeFile).estimatedTime?.let(secondsToDurationText) ?? '--',
      ),
      SortMode.lastPrinted when file is GCodeFile => Text(
        (file as GCodeFile).lastPrintDate?.let(dateFormat.format) ?? '--',
      ),
      SortMode.lastPrinted => const Text('--'),
      SortMode.lastModified => Text(file.modifiedDate?.let(dateFormat.format) ?? '--'),
      _ => Text('@:pages.files.sort_by.last_modified: ${file.modifiedDate?.let(dateFormat.format) ?? '--'}').tr(),
    };

    return RemoteFileListTile(
      machineUUID: machineUUID,
      file: file,
      subtitle: subtitle,
      showPrintedIndicator: true,
      onTap: () => controller.onSelectFile(file),
    );
  }
}

@riverpod
class _SelectFileBottomSheetController extends _$SelectFileBottomSheetController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  CompositeKey get _sortModeKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'mode:gcodes');

  CompositeKey get _sortKindKey => CompositeKey.keyWithString(UtilityKeys.fileExplorerSortCfg, 'kind:gcodes');

  @override
  FutureOr<_Model> build(String machineUUID, String filePath) async {
    ref.listen(
      fileNotificationsProvider(machineUUID, filePath),
      (prev, next) => next.whenData((notification) => _onFileNotification(notification)),
    );

    ref.listen(jrpcClientStateProvider(machineUUID), (prev, next) {
      if (next.valueOrNull == ClientState.error || next.valueOrNull == ClientState.disconnected) {
        if (_goRouter.canPop()) _goRouter.pop(BottomSheetResult.dismissed());
        talker.info(
          '[_SelectFileBottomSheetController($machineUUID, $filePath)] JRPC Client is in error state, will pop files bottom sheet',
        );
      }
    });

    final supportedModes = SortMode.availableForGCodes();
    final sortModeIdx = ref.watch(intSettingProvider(_sortModeKey)).clamp(0, supportedModes.length - 1);
    final sortKindIdx = ref.watch(intSettingProvider(_sortKindKey)).clamp(0, SortKind.values.length - 1);

    final sortConfiguration = SortConfiguration(supportedModes[sortModeIdx], SortKind.values[sortKindIdx]);

    final apiResp = await ref.watch(moonrakerFolderContentProvider(machineUUID, filePath, sortConfiguration).future);

    return _Model(folderContent: apiResp, sortConfig: sortConfiguration);
  }

  Future<void> onSortMode() async {
    talker.info('[_SelectFileBottomSheetController($machineUUID, $filePath)] sort mode');
    final model = state.requireValue;
    final args = SortModeSheetArgs(toShow: SortMode.availableForGCodes(), active: model.sortConfig);

    final res = await _bottomSheetService.show(BottomSheetConfig(type: SheetType.sortMode, data: args));

    if (res.confirmed != true) return;
    final selected = res.data as SortConfiguration;

    ref.read(settingServiceProvider)
      ..writeInt(_sortModeKey, selected.mode.index)
      ..writeInt(_sortKindKey, selected.kind.index);

    ref.invalidateSelf();
  }

	Future<void> onSelectFile(RemoteFile file) async {
		talker.info('[_SelectFileBottomSheetController($machineUUID, $filePath)] Selected file: $file');

		if (file is Folder) {
			final result = await _bottomSheetService.show(
				BottomSheetConfig(
					type: SheetType.selectPrintJob,
					data: SelectFileBottomSheetArgs(machineUUID, file.absolutPath),
				),
			);
			if (result.confirmed == true && result.data != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_goRouter.canPop()) {
            _goRouter.pop(BottomSheetResult.confirmed(result.data));
          }
        });
			}
			// If dismissed or no selection, do nothing (stay in current sheet)

		} else if (file is GCodeFile) {
			_goRouter.pop(BottomSheetResult.confirmed(file));
		} else {
			talker.warning('[_SelectFileBottomSheetController($machineUUID, $filePath)] Unsupported file type: $file');
		}
	}

  void _onFileNotification(FileActionResponse notification) {
    talker.info('[_SelectFileBottomSheetController($machineUUID, $filePath)] Got a file notification: $notification');

    // Check if the notifications are only related to the current folder
    switch (notification.action) {
      case FileAction.delete_dir when notification.item.fullPath == filePath:
        talker.info('[ModernFileManagerController($machineUUID, $filePath)] Folder was deleted, will move to parent');
        _goRouter.pop(BottomSheetResult.dismissed());
        ref.invalidateSelf();
        break;
      case FileAction.move_dir when notification.sourceItem?.fullPath == filePath:
        talker.info(
          '[ModernFileManagerController($machineUUID, $filePath)] Folder was moved, will move to new location',
        );
        _goRouter.pop(BottomSheetResult.dismissed());
        ref.invalidateSelf();
      default:
        // Do Nothing!
        break;
    }
  }
}

@freezed
class SelectFileBottomSheetArgs with _$SelectFileBottomSheetArgs {
  const factory SelectFileBottomSheetArgs(String machineUUID, [@Default('gcodes') String path]) =
      __SelectFileBottomSheetArgs;
}

@freezed
class _Model with _$Model {
  const factory _Model({required FolderContentWrapper folderContent, required SortConfiguration sortConfig}) = __Model;
}
