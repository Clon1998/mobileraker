/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/date_format_service.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/files/components/remote_file_list_tile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shimmer/shimmer.dart';

import '../../../routing/app_router.dart';

part 'file_manager_search_page.freezed.dart';
part 'file_manager_search_page.g.dart';

class FileManagerSearchPage extends HookConsumerWidget {
  const FileManagerSearchPage({super.key, required this.machineUUID, required this.path});

  final String machineUUID;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController();
    final searchQuery = useValueListenable(textController);
    final controller = ref.watch(_fileManagerSearchControllerProvider(machineUUID, path).notifier);

    useEffect(() {
      logger.i('[FileManagerSearchPage] useEffect - Search term changed');
      controller.onSearchTermChanged(textController.text);
    }, [searchQuery]);

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
      body: Center(child: ResponsiveLimit(child: _SearchResults(machineUUID: machineUUID, path: path))),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({super.key, required this.machineUUID, required this.path});

  final String machineUUID;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final apiData = ref.watch(fileApiResponseProvider(machineUUID, path));

    final model = ref.watch(_fileManagerSearchControllerProvider(machineUUID, path));
    final controller = ref.watch(_fileManagerSearchControllerProvider(machineUUID, path).notifier);

    final dateFormat = ref.watch(dateFormatServiceProvider).add_Hm(DateFormat.yMd(context.deviceLocale.languageCode));
    final themeData = Theme.of(context);

    Widget? widget;

    if (model.searchTerm?.isNotEmpty != true) {
      widget = Column(
        key: const Key('empty_search'),
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
      );
    } else if (model.searchResults.isEmpty && !model.isLoading) {
      widget = Column(
        key: const Key('no_results'),
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
      );
    } else {
      widget = Column(
        key: ValueKey(model.searchResults.length),
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverList.builder(
                  itemCount: model.searchResults.length,
                  itemBuilder: (context, index) {
                    final file = model.searchResults[index];
                    return RemoteFileListTile(
                      machineUUID: machineUUID,
                      file: file,
                      onTap: () => controller.onTapFile(file),
                      useHero: false,
                      showPrintedIndicator: true,
                      subtitle: Text('/${file.parentPath}'),
                    );
                  },
                ),
                if (model.isLoading)
                  SliverToBoxAdapter(
                    child: Shimmer.fromColors(
                      baseColor: Colors.grey,
                      highlightColor: themeData.colorScheme.background,
                      child: const ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        horizontalTitleGap: 8,
                        leading: SizedBox(
                          width: 42,
                          height: 42,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.red),
                          ),
                        ),
                        title: FractionallySizedBox(
                          alignment: Alignment.bottomLeft,
                          widthFactor: 0.7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                            child: Text(' '),
                          ),
                        ),
                        dense: true,
                        subtitle: FractionallySizedBox(
                          alignment: Alignment.bottomLeft,
                          widthFactor: 0.42,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white),
                            child: Text(' '),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeInOutCirc,
      switchOutCurve: Curves.easeInOutCirc.flipped,
      child: widget,
    );
  }
}

@riverpod
class _FileManagerSearchController extends _$FileManagerSearchController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  Timer? _debouncer;

  @override
  _Model build(String machineUUID, String path) {
    logger.i('[FileManagerSearchController] initializing for $path');
    ref.listen(jrpcClientStateProvider(machineUUID), (prev, next) {
      if (next.valueOrNull == ClientState.error || next.valueOrNull == ClientState.disconnected) {
        if (_goRouter.canPop()) _goRouter.pop();
        logger.i('[FileManagerSearchController] Client disconnected. Popping search page');
      }
    });

    ref.listenSelf((previous, next) {
      if (previous?.searchTerm != next.searchTerm) {
        logger.i('[FileManagerSearchController] Search term changed, refreshing results');
        _refreshResults();
      }
    });
    // Start fetching files from the root directory
    _fetchFiles(path).whenComplete(() {
      state = state.copyWith(isLoading: false);
      logger.i('[FileManagerSearchController] finished fetching files');
    });

    return const _Model(searchResults: [], isLoading: true);
  }

  void onTapFile(RemoteFile file) {
    logger.i('[FileManagerSearchController] Tapped file: ${file.name}');
    switch (file) {
      case GCodeFile():
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_gcodeDetail.name, pathParameters: {'path': path}, extra: file);
        break;
      case Folder():
        _goRouter.pushNamed(AppRoute.fileManager_explorer.name, pathParameters: {'path': file.absolutPath});
        break;
      case RemoteFile(isVideo: true):
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_videoPlayer.name, pathParameters: {'path': path}, extra: file);
        break;
      case RemoteFile(isImage: true):
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_imageViewer.name, pathParameters: {'path': path}, extra: file);
        break;
      default:
        _goRouter.pushNamed(AppRoute.fileManager_exlorer_editor.name, pathParameters: {'path': path}, extra: file);
    }
  }

  void onSearchTermChanged(String searchTerm) {
    logger.i('[FileManagerSearchController] Search term changed: $searchTerm');
    _debouncer?.cancel();
    _debouncer = Timer(const Duration(milliseconds: 400), () {
      logger.i('[FileManagerSearchController] Debounced search term: $searchTerm');
      state = state.copyWith(searchTerm: searchTerm.trim());
    });
  }

  /// Fetch all files from the given path and all subfolders
  Future<void> _fetchFiles(String path, [bool isRetry = false]) async {
    logger.i('[FileManagerSearchController] Fetching files from $path');
    try {
      final provider = fileApiResponseProvider(machineUUID, path).future;
      //TODO: Should I really watch or read?
      final response = await (isRetry ? ref.refresh(provider) : ref.read(provider));

      // Add the response to the list of responses
      state = state.copyWith(apiResponses: [...state.apiResponses, response]);
      _refreshResults(response.files);

      List<Future> futures = [];
      // Now look into all folders
      for (var file in response.folders) {
        futures.add(_fetchFiles(file.absolutPath));
      }

      await Future.wait(futures);
    } catch (e, s) {
      if (!isRetry) {
        logger.e('Error while fetching files. Retrying in 400ms...', e, s);
        await Future.delayed(const Duration(milliseconds: 400));
        _fetchFiles(path, true);
      } else {
        logger.e('Error while fetching files', e, s);
      }
    }
  }

  void _refreshResults([List<RemoteFile>? files]) {
    final searchTerm = state.searchTerm?.toLowerCase();
    if (searchTerm?.isNotEmpty != true) return;
    final toFilter = files ?? state.apiResponses.expand((element) => element.files);
    final searchTokens = searchTerm!.split(RegExp(r'\W+'));
    logger.i('[FileManagerSearchController] Refreshing search results for $searchTerm, tokens: $searchTokens');
    final newSearchResults = toFilter
        .map(
          (file) => (
            file,
            _calculateScore(file.name.toLowerCase(), searchTerm, searchTokens),
          ),
        )
        .where((element) => element.$2 > 150)
        .sorted((a, b) => b.$2.compareTo(a.$2))
        .map((e) => e.$1)
        .toList();
    logger.i(
        '[FileManagerSearchController] Found ${newSearchResults.length}/${toFilter.length} results for ${state.searchTerm}');

    state =
        state.copyWith(searchResults: files == null ? newSearchResults : [...state.searchResults, ...newSearchResults]);
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
    var fileTokens = fileName.split(RegExp(r'[.\s_-]+'));
    for (var searchToken in searchTokens) {
      if (fileTokens.any((fileToken) => fileToken == searchToken)) score += 150;
      if (fileTokens.any((fileToken) => fileToken.startsWith(searchToken))) score += 130;
      if (fileTokens.any((fileToken) => fileToken.endsWith(searchToken))) score += 110;
    }

    // Jaro-Winkler similarity
    score += fileName.jaroWinkler(searchTerm) * 100;

    // Trigram similarity for longer search terms
    if (searchTerm.length > 3) {
      score += fileName.trigramSimilarity(searchTerm) * 50;
    }

    return score;
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    @Default([]) List<FolderContentWrapper> apiResponses,
    @Default([]) List<RemoteFile> searchResults,
    String? searchTerm,
    @Default(false) bool isLoading,
  }) = __Model;
}
