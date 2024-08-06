/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/number_format_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../../service/ui/dialog_service_impl.dart';
import '../../components/bottomsheet/sort_mode_bottom_sheet.dart';
import '../../components/dialog/text_input/text_input_dialog.dart';

part 'file_manager_move_page.freezed.dart';
part 'file_manager_move_page.g.dart';

class FileManagerMovePage extends HookWidget {
  const FileManagerMovePage({super.key, required this.machineUUID, required this.filePath});

  final String machineUUID;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: context.pop,
        // ),
        title: Text('Move file: $filePath'),
      ),
      body: SafeArea(child: _Body(machineUUID: machineUUID, root: filePath)),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID, required this.root});

  final String machineUUID;
  final String root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(jrpcClientStateProvider(machineUUID), (prev, next) {
      if (next.valueOrNull == ClientState.error || next.valueOrNull == ClientState) {
        context.pop();
        logger.i('Closing search screen due to client state change');
      }
    });

    return Column(
      children: [
        Expanded(child: _FolderList(machineUUID: machineUUID, root: root)),
        const _Footer(),
      ],
    );
  }
}

class _FolderList extends ConsumerWidget {
  const _FolderList({super.key, required this.machineUUID, required this.root});

  final String machineUUID;
  final String root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_fileManagerMovePageControllerProvider(machineUUID, root));
    final controller = ref.read(_fileManagerMovePageControllerProvider(machineUUID, root).notifier);
    final numberFormat =
        NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));

    return AsyncValueWidget(
      value: model,
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: (data) {
        final folders = data.folderContent.folders;

        if (folders.isEmpty) {
          //TODO: Proper with Svg
          return const Center(child: Text('No folders found'));
        }

        final themeData = Theme.of(context);

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
            SliverList.separated(
              itemCount: folders.length,
              separatorBuilder: (context, index) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final folder = folders[index];

                Widget subtitle = switch (data.sortConfig.mode) {
                  SortMode.size => Text(numberFormat.formatFileSize(folder.size)),
                  SortMode.lastModified => Text(folder.modifiedDate?.let(dateFormat.format) ?? '--'),
                  _ => Text('@:pages.files.last_mod: ${folder.modifiedDate?.let(dateFormat.format) ?? '--'}').tr(),
                };

                return RemoteFileListTile(
                  key: ValueKey(folder),
                  machineUUID: machineUUID,
                  subtitle: subtitle,
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
  const _Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: () => context.pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        const Gap(16),
        TextButton(onPressed: () => null, child: const Text('Move here')),
        const Gap(16),
      ],
    );
  }
}

@riverpod
class _FileManagerMovePageController extends _$FileManagerMovePageController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  FileService get _fileService => ref.read(fileServiceProvider(machineUUID));

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  @override
  FutureOr<_Model> build(String machineUUID, String root) async {
    final sortConfiguration = state.whenOrNull(
          data: (data) => data.sortConfig,
        ) ??
        const SortConfiguration(SortMode.name, SortKind.ascending);
    final apiResp = await ref.watch(moonrakerFolderContentProvider(machineUUID, root, sortConfiguration).future);

    return _Model(folderContent: apiResp, sortConfig: sortConfiguration);
  }

  Future<void> onSortMode() async {
    logger.i('[ModernFileManagerController] sort mode');
    final model = state.requireValue;
    final args = SortModeSheetArgs(
      toShow: [SortMode.name, SortMode.lastModified, SortMode.size],
      active: model.sortConfig,
    );

    final res = await _bottomSheetService.show(BottomSheetConfig(type: SheetType.sortMode, data: args));

    if (res.confirmed == true) {
      logger.i('SortModeSheet confirmed: ${res.data}');

      // This is required to already show the new sort mode before the data is updated
      state = state.whenData((data) => data.copyWith(sortConfig: res.data));
      ref.invalidateSelf();
    }
  }

  void onCreateFolder() async {
    logger.i('[ModernFileManagerController] creating folder');

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

      try {
        final res = await _fileService.createDir('$root/$newName');
        final folder = Folder.fromFileItem(res.item);
        _insertFolder(folder);
      } on JRpcError {
        // _snackBarService.showCustomSnackBar(
        //     variant: SnackbarType.error,
        //     duration: const Duration(seconds: 5),
        //     title: 'Error',
        //     message: 'Could not create folder!\n${e.message}');
      }
    }
  }

  void _insertFolder(Folder folder) {
    state = state.whenData((data) {
      final updatedFolders = [...data.folderContent.folders, folder].sorted(data.sortConfig.comparator);

      return data.copyWith(folderContent: data.folderContent.copyWith(folders: updatedFolders));
    });
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required FolderContentWrapper folderContent,
    required SortConfiguration sortConfig,
  }) = __Model;
}
