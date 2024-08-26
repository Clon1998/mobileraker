/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_list_tile.dart';
import 'package:mobileraker/ui/screens/files/components/sorted_file_list_header.dart';
import 'package:persistent_header_adaptive/persistent_header_adaptive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

import '../../../routing/app_router.dart';
import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../../service/ui/dialog_service_impl.dart';
import '../../components/bottomsheet/sort_mode_bottom_sheet.dart';
import '../../components/dialog/text_input/text_input_dialog.dart';

part 'move_file_destination_page.freezed.dart';
part 'move_file_destination_page.g.dart';

class MoveFileDestinationPage extends HookWidget {
  const MoveFileDestinationPage({super.key, required this.machineUUID, required this.path, required this.submitLabel});

  final String machineUUID;
  final String path;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: context.pop,
        // ),
        title: Text(path.split('/').last.capitalize()),
      ),
      body: SafeArea(child: _Body(machineUUID: machineUUID, root: path, submitLabel: submitLabel)),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID, required this.root, required this.submitLabel});

  final String machineUUID;
  final String root;
  final String submitLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(jrpcClientStateProvider(machineUUID), (prev, next) {
      if (next.valueOrNull == ClientState.error || next.valueOrNull == ClientState.disconnected) {
        if (context.canPop()) context.pop();
        logger.i('Closing search screen due to client state change');
      }
    });

    final controller = ref.watch(_fileManagerMovePageControllerProvider(machineUUID, root, submitLabel).notifier);

    return Center(
      child: ResponsiveLimit(
        child: Column(
          children: [
            Expanded(child: _FolderList(machineUUID: machineUUID, root: root, submitLabel: submitLabel)),
            _Footer(onMoveHere: controller.onMoveHere, submitLabel: submitLabel),
          ],
        ),
      ),
    );
  }
}

class _FolderList extends ConsumerWidget {
  const _FolderList({super.key, required this.machineUUID, required this.root, required this.submitLabel});

  final String machineUUID;
  final String root;
  final String submitLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_fileManagerMovePageControllerProvider(machineUUID, root, submitLabel));
    final controller = ref.read(_fileManagerMovePageControllerProvider(machineUUID, root, submitLabel).notifier);
    final numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));

    return AsyncValueWidget(
      value: model,
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (data) {
        final folders = data.folderContent.folders;

        final themeData = Theme.of(context);

        if (folders.isEmpty) {
          return Column(
            children: [
              SortedFileListHeader(
                activeSortConfig: null,
                trailing: IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // 12 is basis vom icon button + 4 weil list tile hat 14 padding + 1 wegen size 22
                  onPressed: controller.onCreateFolder.only(!model.isLoading),
                  icon: Icon(Icons.create_new_folder, size: 22, color: themeData.textTheme.bodySmall?.color),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
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
              ),
            ],
          );
        }

        return CustomScrollView(
          slivers: [
            AdaptiveHeightSliverPersistentHeader(
              floating: true,
              initialHeight: 48,
              needRepaint: true,
              child: SortedFileListHeader(
                activeSortConfig: data.sortConfig,
                onTapSortMode: controller.onSortMode,
                trailing: IconButton(
                  padding: const EdgeInsets.only(right: 12),
                  // 12 is basis vom icon button + 4 weil list tile hat 14 padding + 1 wegen size 22
                  onPressed: controller.onCreateFolder,
                  icon: Icon(Icons.create_new_folder, size: 22, color: themeData.textTheme.bodySmall?.color),
                ),
              ),
            ),
            AdaptiveHeightSliverPersistentHeader(
              key: ValueKey(model.isReloading),
              initialHeight: 4,
              pinned: true,
              child: LinearProgressIndicator(value: model.isReloading ? null : 0, backgroundColor: Colors.transparent),
            ),
            SliverList.separated(
              itemCount: folders.length,
              separatorBuilder: (context, index) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final folder = folders[index];

                Widget subtitle = switch (data.sortConfig.mode) {
                  SortMode.size => Text(numberFormat.formatFileSize(folder.size)),
                  SortMode.lastModified => Text(folder.modifiedDate?.let(dateFormat.format) ?? '--'),
                  _ =>
                    Text('@:pages.files.sort_by.last_modified: ${folder.modifiedDate?.let(dateFormat.format) ?? '--'}')
                        .tr(),
                };

                return RemoteFileListTile(
                  key: ValueKey(folder),
                  machineUUID: machineUUID,
                  subtitle: subtitle,
                  onTap: () => controller.onTapFolder(folder),
                  file: folder,
                  useHero: false,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({super.key, required this.onMoveHere, required this.submitLabel});

  final VoidCallback? onMoveHere;

  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: () => context.pop(), child: const Text('general.cancel').tr()),
        const Gap(16),
        TextButton(onPressed: onMoveHere, child: Text(submitLabel)),
        const Gap(16),
      ],
    );
  }
}

@riverpod
class _FileManagerMovePageController extends _$FileManagerMovePageController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  FileService get _fileService => ref.read(fileServiceProvider(machineUUID));

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  @override
  FutureOr<_Model> build(String machineUUID, String filePath, String submitLabel) async {
    ref.listen(fileNotificationsProvider(machineUUID, filePath),
        (prev, next) => next.whenData((notification) => _onFileNotification(notification)));

    final sortConfiguration = state.whenOrNull(
          data: (data) => data.sortConfig,
        ) ??
        const SortConfiguration(SortMode.name, SortKind.ascending);
    final apiResp = await ref.watch(moonrakerFolderContentProvider(machineUUID, filePath, sortConfiguration).future);

    return _Model(folderContent: apiResp, sortConfig: sortConfiguration);
  }

  Future<void> onSortMode() async {
    logger.i('[_FileManagerMovePageController($machineUUID, $filePath)] sort mode');
    final model = state.requireValue;
    final args = SortModeSheetArgs(
      toShow: [SortMode.name, SortMode.lastModified, SortMode.size],
      active: model.sortConfig,
    );

    final res = await _bottomSheetService.show(BottomSheetConfig(type: SheetType.sortMode, data: args));

    if (res.confirmed == true) {
      logger.i('[_FileManagerMovePageController($machineUUID, $filePath)] SortModeSheet confirmed: ${res.data}');

      // This is required to already show the new sort mode before the data is updated
      state = state.whenData((data) => data.copyWith(sortConfig: res.data));
      ref.invalidateSelf();
    }
  }

  Future<void> onTapFolder(Folder folder) async {
    final res = await _goRouter.pushNamed(
      AppRoute.fileManager_exlorer_move.name,
      pathParameters: {'path': folder.absolutPath},
      queryParameters: {'machineUUID': machineUUID, 'submitLabel': submitLabel},
    );

    //TODO: Add an result. Because we can not handle the path + cancel + back button...
    if (res == null) return;
    _goRouter.pop(res);
  }

  void onCreateFolder() async {
    logger.i('[_FileManagerMovePageController($machineUUID, $filePath)] creating folder');

    final usedNames = state.requireValue.folderContent.folderFileNames;

    var dialogResponse = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        title: tr('dialogs.create_folder.title'),
        actionLabel: tr('general.create'),
        data: TextInputDialogArguments(
          initialValue: '',
          labelText: tr('dialogs.create_folder.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.match(
              '^[\\w.\\-]+\$',
              errorText: tr('pages.files.no_matches_file_pattern'),
            ),
            notContains(
              usedNames,
              errorText: tr('pages.files.file_name_in_use'),
            ),
          ]),
        ),
      ),
    );

    if (dialogResponse?.confirmed == true) {
      String newName = dialogResponse!.data;
      state = state.toLoading(false);
      _fileService.createDir('$filePath/$newName').ignore();
    }
  }

  void onMoveHere() {
    _goRouter.pop(filePath);
  }

  void _onFileNotification(FileActionResponse notification) {
    logger.i('[_FileManagerMovePageController($machineUUID, $filePath)] Got a file notification: $notification');

    // Check if the notifications are only related to the current folder

    switch (notification.action) {
      case FileAction.delete_dir when notification.item.fullPath == filePath:
        logger.i('[ModernFileManagerController($machineUUID, $filePath)] Folder was deleted, will move to parent');
        _goRouter.pop();
        ref.invalidateSelf();
        break;
      case FileAction.move_dir when notification.sourceItem?.fullPath == filePath:
        logger.i('[ModernFileManagerController($machineUUID, $filePath)] Folder was moved, will move to new location');
        _goRouter.pop();
        ref.invalidateSelf();
      default:
        // Do Nothing!
        break;
    }
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required FolderContentWrapper folderContent,
    required SortConfiguration sortConfig,
  }) = __Model;
}
