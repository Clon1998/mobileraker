/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_list_tile.dart';

import '../../../routing/app_router.dart';

class FileManagerSearchPage extends HookWidget {
  const FileManagerSearchPage({super.key, required this.machineUUID, required this.path});

  final String machineUUID;
  final String path;

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();

    final themeData = Theme.of(context);
    final onBackground = themeData.appBarTheme.foregroundColor ??
        (themeData.colorScheme.brightness == Brightness.dark
            ? themeData.colorScheme.onSurface
            : themeData.colorScheme.onPrimary);

    return Scaffold(
      appBar: AppBar(
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: context.pop,
        // ),
        actions: [
          ValueListenableBuilder(
            valueListenable: textController,
            builder: (context, value, child) => AnimatedSwitcher(
              duration: kThemeAnimationDuration,
              child: value.text.isNotEmpty
                  ? IconButton(
                      tooltip: tr('pages.files.search.clear_search'),
                      icon: const Icon(Icons.search_off),
                      onPressed: textController.clear,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
        title: TextField(
          controller: textController,
          autofocus: true,
          cursorColor: onBackground,
          style: themeData.textTheme.titleLarge?.copyWith(color: onBackground),
          decoration: InputDecoration(
            hintText: tr('@:pages.files.search_files…'),
            hintStyle: themeData.textTheme.titleLarge?.copyWith(color: onBackground.withOpacity(0.4)),
            border: InputBorder.none,
          ),
        ),
      ),
      body: _Body(machineUUID: machineUUID, path: path, query: textController),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID, required this.path, required this.query});

  final String machineUUID;
  final String path;
  final ValueNotifier<TextEditingValue> query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(jrpcClientStateProvider(machineUUID), (prev, next) {
      if (next.valueOrNull == ClientState.error || next.valueOrNull == ClientState.disconnected) {
        if (context.canPop()) context.pop();
        logger.i('Closing search screen due to client state change');
      }
    });

    final textEditingValue = useValueListenable(query);
    final debouncedSearchTerm = useDebounced(textEditingValue.text, const Duration(milliseconds: 350)) ?? '';

    if (debouncedSearchTerm.isEmpty) {
      final themeData = Theme.of(context);

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FractionallySizedBox(
                heightFactor: 0.3,
                child: SvgPicture.asset('assets/vector/undraw_select_option_re_u4qn.svg'),
              ),
            ),
            const SizedBox(height: 16),
            Text('pages.files.search.waiting', style: themeData.textTheme.titleMedium).tr(),
          ],
        ),
      );
    }

    return _SearchResults(machineUUID: machineUUID, path: path, searchTerm: debouncedSearchTerm);
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({super.key, required this.machineUUID, required this.path, required this.searchTerm});

  final String machineUUID;
  final String path;
  final String searchTerm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiData = ref.watch(fileApiResponseProvider(machineUUID, path));
    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));

    return AsyncValueWidget(
      value: apiData,
      data: (data) {
        final combined = _searchFiles(data, searchTerm);

        if (combined.isEmpty) {
          final themeData = Theme.of(context);

          return Center(
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
                Text('pages.files.search.no_results.title', style: themeData.textTheme.titleMedium).tr(),
                Text('pages.files.search.no_results.subtitle', style: themeData.textTheme.bodySmall).tr(),
              ],
            ),
          );
        }

        return Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: combined.length,
                itemBuilder: (context, index) {
                  final file = combined[index];

                  return RemoteFileListTile(
                    machineUUID: machineUUID,
                    file: file,
                    onTap: () => _onTap(context, file),
                    useHero: false,
                    subtitle: Text(
                            '@:pages.files.sort_by.last_modified: ${file.modifiedDate?.let(dateFormat.format) ?? '--'}')
                        .tr(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<RemoteFile> _searchFiles(FolderContentWrapper apiResponse, String searchTerm) {
    // Normalize search term
    searchTerm = searchTerm.toLowerCase();
    var searchTokens = searchTerm.split(RegExp(r'\W+'));

    //ToDo: This could be improved to limit the number of files to search through!
    return apiResponse.files
        .map(
          (file) => (
            file,
            _calculateScore(file.name.toLowerCase(), searchTerm, searchTokens),
          ),
        )
        .where((element) => element.$2 > 50)
        .sorted((a, b) => b.$2.compareTo(a.$2))
        .map((e) => e.$1)
        .toList();
  }

  double _calculateScore(String fileName, String searchTerm, List<String> searchTokens) {
    // Exact match
    if (fileName == searchTerm) return 1000; // Highest possible score

    double score = 0;

    // Full token match
    if (searchTokens.length > 1 && searchTokens.every((token) => fileName.toLowerCase().contains(token))) {
      score += 500; // High score, but less than exact match
    }

    // Prefix match
    if (fileName.startsWith(searchTerm)) score += 200;

    // Token matching
    var fileTokens = fileName.split(RegExp(r'\s+'));
    for (var searchToken in searchTokens) {
      if (fileTokens.any((fileToken) => fileToken == searchToken)) score += 100;
      if (fileTokens.any((fileToken) => fileToken.startsWith(searchToken))) score += 50;
    }

    // Jaro-Winkler similarity
    score += fileName.jaroWinkler(searchTerm) * 100;

    // Trigram similarity for longer search terms
    if (searchTerm.length > 3) {
      score += fileName.trigramSimilarity(searchTerm) * 50;
    }

    return score;
  }

  void _onTap(BuildContext context, RemoteFile file) {
    switch (file) {
      case GCodeFile():
        context.pushNamed(AppRoute.fileManager_exlorer_gcodeDetail.name, pathParameters: {'path': path}, extra: file);
        break;
      case Folder():
        context.pushNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': file.absolutPath});
        break;
      case RemoteFile(isVideo: true):
        context.pushNamed(AppRoute.fileManager_exlorer_videoPlayer.name, pathParameters: {'path': path}, extra: file);
        break;
      case RemoteFile(isImage: true):
        context.pushNamed(AppRoute.fileManager_exlorer_imageViewer.name, pathParameters: {'path': path}, extra: file);
        break;
      default:
        context.pushNamed(AppRoute.fileManager_exlorer_editor.name, pathParameters: {'path': path}, extra: file);
    }
  }
}

//
// @riverpod
// class FileManagerSearchController extends _$FileManagerSearchController {
//   GoRouter get _goRouter => ref.read(goRouterProvider);
//
//   FileService get _fileService => ref.read(fileServiceProvider(machineUUID));
//
//   @override
//   FutureOr<FileManagerSearchModel> build(String machineUUID, String path) async {
//     ref.keepAliveFor();
//
//     logger.i('[FileManagerSearchController] initializing for $path');
//     final apiResp = await ref.watch(moonrakerFolderContentProvider(machineUUID, path).future);
//
//     return FileManagerSearchModel(
//       files: [...apiResp.folders, ...apiResp.files],
//     );
//   }
//
//   void onSearch(String searchTerm) {
//     state = state.whenData((data) {
//       final combined = _searchFiles(data.files, searchTerm);
//       return data.copyWith(searchResults: combined, searchTerm: searchTerm);
//     });
//   }
//
//   List<RemoteFile> _searchFiles(List<RemoteFile> files, String searchTerm) {
//     searchTerm = searchTerm.toLowerCase();
//     var searchTokens = searchTerm.split(RegExp(r'\W+'));
//
//     return files
//         .map(
//           (file) => (
//       file,
//       _calculateScore(file.name.toLowerCase(), searchTerm, searchTokens),
//       ),
//     )
//         .where((element) => element.$2 > 50)
//         .sorted((a, b) => b.$2.compareTo(a.$2))
//         .map((e) => e.$1)
//         .toList();
//   }
//
//   double _calculateScore(String fileName, String searchTerm, List<String> searchTokens) {
//     if (fileName == searchTerm) return 1000;
//
//     double score = 0;
//
//     if (searchTokens.length > 1 && searchTokens.every((token) => fileName.toLowerCase().contains(token))) {
//       score += 500;
//     }
//
//     if (fileName.startsWith(searchTerm)) score += 200;
//
//     var fileTokens = fileName.split(RegExp(r'\s+'));
//     for (var searchToken in searchTokens) {
//       if (fileTokens.any((fileToken) => fileToken == searchToken)) score += 100;
//       if (fileTokens.any((fileToken) => fileToken.startsWith(searchToken))) score += 50;
//     }
//
//     score += fileName.jaroWinkler(searchTerm) * 100;
//
//     if (searchTerm.length > 3) {
//       score += fileName.trigramSimilarity(searchTerm) * 50;
//     }
//
//     return score;
//   }
// }
//
// @freezed
// class FileManagerSearchModel with _$FileManagerSearchModel {
//   const factory FileManagerSearchModel({
//     @Default([]) List<RemoteFile> files,
//     @Default([]) List<RemoteFile> searchResults,
//     @Default('') String searchTerm,
//   }) = _FileManagerSearchModel;
// }
