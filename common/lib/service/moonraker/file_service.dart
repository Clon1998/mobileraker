/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/dto/files/moonraker/file_roots.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/exceptions/file_fetch_exception.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/dio_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/path_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/files/moonraker/file_item.dart';
import '../../network/http_client_factory.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';

part 'file_service.freezed.dart';
part 'file_service.g.dart';

typedef FileListChangedListener = Function(Map<String, dynamic> item, Map<String, dynamic>? srcItem);

@freezed
class FolderContentWrapper with _$FolderContentWrapper {
  const FolderContentWrapper._();

  const factory FolderContentWrapper(
    String folderPath, [
    @Default([]) List<Folder> folders,
    @Default([]) List<RemoteFile> files,
  ]) = _FolderContentWrapper;

  /// Returns if the folder has no content
  bool get isEmpty => folders.isEmpty && files.isEmpty;

  /// Returns if the folder has any content
  bool get isNotEmpty => !isEmpty;

  /// Returns if the folder has any content
  bool get hasContent => folders.isNotEmpty || files.isNotEmpty;

  /// Returns the total amount of items in the folder
  int get totalItems => folders.length + files.length;

  /// Returns a list of all files and folders in the folder
  List<RemoteFile> get unwrapped => [...folders, ...files];

  /// Returns a list of all file names in the folder. Including folders and files
  List<String> get folderFileNames => unwrapped.map((e) => e.name).toList();
}

@riverpod
CacheManager httpCacheManager(HttpCacheManagerRef ref, String machineUUID) {
  final clientType = ref.watch(jrpcClientTypeProvider(machineUUID));
  final baseOptions = ref.watch(baseOptionsProvider(machineUUID, clientType));
  final httpClientFactory = ref.watch(httpClientFactoryProvider);

  final HttpClient httpClient = httpClientFactory.fromBaseOptions(baseOptions);
  ref.onDispose(httpClient.close);

  return CacheManager(
    Config(
      '${DefaultCacheManager.key}-http',
      fileService: HttpFileService(
        httpClient: IOClient(httpClient),
      ),
    ),
  );
}

@riverpod
Uri? previewImageUri(PreviewImageUriRef ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;

  if (machine == null) return null;

  var dio = ref.watch(dioClientProvider(machine.uuid));

  return Uri.tryParse(dio.options.baseUrl);
}

@riverpod
Map<String, String> previewImageHttpHeader(PreviewImageHttpHeaderRef ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;
  if (machine == null) return {};

  var dio = ref.watch(dioClientProvider(machine.uuid));
  return dio.options.headers.cast<String, String>();
}

@riverpod
FileService fileService(FileServiceRef ref, String machineUUID) {
  var dio = ref.watch(dioClientProvider(machineUUID));
  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  return FileService(ref, machineUUID, jsonRpcClient, dio);
}

@riverpod
Stream<FileActionResponse> fileNotifications(FileNotificationsRef ref, String machineUUID) {
  return ref.watch(fileServiceProvider(machineUUID)).fileNotificationStream;
}

@riverpod
FileService fileServiceSelected(FileServiceSelectedRef ref) {
  return ref.watch(fileServiceProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

@riverpod
Stream<FileActionResponse> fileNotificationsSelected(FileNotificationsSelectedRef ref) async* {
  ref.keepAliveFor();
  try {
    var machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;
    yield* ref.watchAsSubject(fileNotificationsProvider(machine.uuid));
  } on StateError catch (_) {
// Just catch it. It is expected that the future/where might not complete!
  }
}

@riverpod
Future<FolderContentWrapper> fileApiResponse(FileApiResponseRef ref, String machineUUID, String path) {
  ref.keepAliveFor();

  ref.listen(
      fileNotificationsProvider(machineUUID),
      (prev, next) => next.whenData((notification) {
            FileItem item = notification.item;
            var itemWithInLevel = isWithin(path, item.fullPath);

            FileItem? srcItem = notification.sourceItem;
            var srcItemWithInLevel = isWithin(path, srcItem?.fullPath ?? '');

            // This needs to be reevaluated. Because if we move files this might be faulty
            if (itemWithInLevel != 0 && srcItemWithInLevel != 0) {
              return;
            }

            logger.i('[FileApiResponse ($machineUUID, $path)] Will refresh due to notification: $notification');

            ref.invalidateSelf();
          }));

  return ref.watch(fileServiceProvider(machineUUID)).fetchDirectoryInfo(path, true);
}

@riverpod
Future<FolderContentWrapper> moonrakerFolderContent(
    MoonrakerFolderContentRef ref, String machineUUID, String path, SortConfiguration sortConfig) async {
  ref.keepAliveFor(Duration(seconds: 5));
  // await Future.delayed(const Duration(milliseconds: 5000));
  final apiResponse = await ref.watch(fileApiResponseProvider(machineUUID, path).future);

  List<Folder> folders = apiResponse.folders.toList();
  List<RemoteFile> files = apiResponse.files.toList();

  final comp = sortConfig.comparator;

  files.sort(comp);
  folders.sort(comp);
  return FolderContentWrapper(apiResponse.folderPath, folders, files);
}

/// The FileService handles all file changes of the different roots of moonraker
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#file-operations
/// 2. https://moonraker.readthedocs.io/en/latest/web_api/#file-list-changed
class FileService {
  FileService(AutoDisposeRef ref, this._machineUUID, this._jRpcClient, this._dio)
      : _downloadReceiverPortName = 'downloadFilePort-${_machineUUID.hashCode}',
        _apiRequestTimeout =
            _jRpcClient.timeout > const Duration(seconds: 30) ? _jRpcClient.timeout : const Duration(seconds: 30) {
    ref.onDispose(dispose);
    ref.listen(jrpcMethodEventProvider(_machineUUID, 'notify_filelist_changed'), _onFileListChanged);
  }

  final String _machineUUID;
  final String _downloadReceiverPortName;

  final StreamController<FileActionResponse> _fileActionStreamCtrler = StreamController();

  Stream<FileActionResponse> get fileNotificationStream => _fileActionStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  final Dio _dio;

  final Duration _apiRequestTimeout;

  Future<List<FileRoot>> fetchRoots() async {
    logger.i('Fetching roots');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod('server.files.roots', timeout: _apiRequestTimeout);

      List<dynamic> rootsResponse = blockingResp.result as List;
      return List.generate(rootsResponse.length, (index) {
        var element = rootsResponse[index];
        return FileRoot.fromJson(element);
      });
    } on JRpcError catch (e) {
      logger.w('Error while fetching roots', e);
      throw FileFetchException('Jrpc error while trying to fetch roots.', parent: e);
    }
  }

  Future<FolderContentWrapper> fetchDirectoryInfo(String path, [bool extended = false]) async {
    logger.i('Fetching for `$path` [extended:$extended]');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod(
        'server.files.get_directory',
        params: {'path': path, 'extended': extended},
        timeout: _apiRequestTimeout,
      );

      Set<String>? allowedFileType;

      if (path.startsWith('gcodes')) {
        allowedFileType = {
          '.gcode',
          '.g',
          '.gc',
          '.gco',
        };
      } else if (path.startsWith('config')) {
        allowedFileType = {'.conf', '.cfg', '.md', '.bak', '.txt', '.jpeg', '.jpg', '.png'};
      } else if (path.startsWith('timelapse')) {
        allowedFileType = {'.mp4'};
      }

      return _parseDirectory(blockingResp, path, allowedFileType);
    } on JRpcError catch (e) {
      throw FileFetchException('Jrpc error while trying to fetch directory.', reqPath: path, parent: e);
    }
  }

  Future<GCodeFile> getGCodeMetadata(String filename) async {
    logger.i('Getting meta for file: `$filename`');

    final parentPathParts = filename.split('/')
      ..removeLast()
      ..insert(0, 'gcodes'); // we need to add the gcodes here since the getMetaInfo omits gcodes path.
    final parentPath = parentPathParts.join('/');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod('server.files.metadata',
          params: {'filename': filename}, timeout: _apiRequestTimeout);

      return GCodeFile.fromJson(blockingResp.result, parentPath);
    } on JRpcError catch (e) {
      if (e.message.contains('Metadata not available for')) {
        logger.w('Metadata not available for $filename');
        return GCodeFile(name: filename, parentPath: parentPath, modified: -1, size: -1);
      }

      throw FileFetchException('Jrpc error while trying to get metadata.', reqPath: filename, parent: e);
    }
  }

  Future<FileActionResponse> createDir(String filePath) async {
    logger.i('Creating Folder "$filePath"');

    try {
      final rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.post_directory',
          params: {'path': filePath}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to create directory.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> deleteFile(String filePath) async {
    logger.i('Deleting File "$filePath"');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.delete_file',
          params: {'path': filePath}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to delete file.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> deleteDirForced(String filePath) async {
    logger.i('Deleting Folder-Forced "$filePath"');
    try {
      RpcResponse rpcResponse =
          await _jRpcClient.sendJRpcMethod('server.files.delete_directory', params: {'path': filePath, 'force': true});
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to force-delete directory.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> moveFile(String origin, String destination) async {
    logger.i('Moving file from $origin to $destination');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.move',
          params: {'source': origin, 'dest': destination}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to move file.', reqPath: origin, parent: e);
    }
  }

  Stream<FileDownload> downloadFile({required String filePath, bool overWriteLocal = false}) async* {
    final tmpDir = await getTemporaryDirectory();
    final File file = File('${tmpDir.path}/$_machineUUID/$filePath');
    final ReceivePort receiverPort = ReceivePort();
    final String isolateSafePortName = '$_downloadReceiverPortName-${filePath.hashCode}';
    final BaseOptions isolateSafeBaseOptions = _dio.options.copyWith();
    IsolateNameServer.registerPortWithName(receiverPort.sendPort, isolateSafePortName);
    try {
      // logger.i('Will try to download $filePath to file $file');
      //
      // var download = workerManager.execute<FileDownload>(() async {
      //   await setupIsolateLogger();
      //   logger.i('Hello from worker ${file.path} - my port will be: $isolateSafePortName');
      //   var port = IsolateNameServer.lookupPortByName(isolateSafePortName)!;
      //
      //   return await isolateDownloadFile(
      //       dioBaseOptions: isolateSafeBaseOptions,
      //       urlPath: '/server/files/$filePath',
      //       savePath: file.path,
      //       port: port,
      //       overWriteLocal: true);
      // });
      //
      //
      // yield* receiverPort.takeUntil(download.asStream()).cast<FileDownload>();
      // logger.i('blub');
      // yield await download;

      // This code is not using a seperate isolate. Lets see how it goes lol

      StreamController<FileDownload> ctrler = StreamController();
      _dio.download(
        '/server/files/$filePath',
        file.path,
        // options: Options(receiveTimeout: Duration(seconds: 300)), // This is requried because of a bug in dio
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          logger.i('Progress for $filePath: ${received / total * 100}');
          ctrler.add(FileDownloadProgress(received / total));
        },
      ).then((response) {
        ctrler.add(FileDownloadComplete(file));
      }).catchError((e, s) {
        logger.e('Error while downloading file cought in catchError', e);
        ctrler.addError(e, s);
      }).then((value) => ctrler.close());

      yield* ctrler.stream;
      logger.i('File download completed');
    } catch (e) {
      // This is only required for the isolate version, the non isolate version should handle the error in the catchError
      logger.e('Error while downloading file', e);
      rethrow;
    } finally {
      IsolateNameServer.removePortNameMapping(isolateSafePortName);
      receiverPort.close();
      logger.i('Removed port mapping and closed the port for $isolateSafePortName');
    }
  }

  Future<FileActionResponse> uploadAsFile(String filePath, String content) async {
    assert(!filePath.startsWith('(gcodes|config)'), 'filePath needs to contain root folder config or gcodes!');
    List<String> fileSplit = filePath.split('/');
    String root = fileSplit.removeAt(0);

    logger.i('Trying upload of $filePath');

    var data = FormData.fromMap({
      'root': root,
      'file': MultipartFile.fromString(content, filename: fileSplit.join('/')),
    });

    var response = await _dio.post(
      '/server/files/upload',
      data: data,
      options: Options(validateStatus: (status) => status == 201),
    );

    return FileActionResponse.fromJson(response.data);
  }

  _onFileListChanged(AsyncValue<Map<String, dynamic>>? previous, AsyncValue<Map<String, dynamic>> next) {
    if (next.isLoading) return;
    if (next.hasError) {
      _fileActionStreamCtrler.addError(next.error!, next.stackTrace);
      return;
    }
    var rawMessage = next.requireValue;
    Map<String, dynamic> params = rawMessage['params'][0];
    FileAction? fileAction = FileAction.tryFromJson(params['action']);

    if (fileAction != null) {
      _fileActionStreamCtrler.add(FileActionResponse.fromJson(params));
    }
  }

  FolderContentWrapper _parseDirectory(RpcResponse blockingResponse, String forPath, [Set<String>? allowedFileType]) {
    Map<String, dynamic> response = blockingResponse.result;
    List<dynamic> filesResponse = response['files'] ?? []; // Just add an type
    List<dynamic> directoriesResponse = response['dirs'] ?? []; // Just add an type

    directoriesResponse.removeWhere((element) {
      String name = element['dirname'];
      return name.startsWith('.');
    });

    List<Folder> listOfFolder = List.generate(directoriesResponse.length, (index) {
      var element = directoriesResponse[index];
      return Folder.fromJson(element, forPath);
    });

    if (allowedFileType != null) {
      filesResponse.removeWhere((element) {
        String name = element['filename'];
        var regExp = RegExp('^.*(${allowedFileType.join('|')})\$', multiLine: true, caseSensitive: false);
        return !regExp.hasMatch(name);
      });
    }

    List<RemoteFile> listOfFiles = List.generate(filesResponse.length, (index) {
      var element = filesResponse[index];
      String name = element['filename'];
      if (RegExp(r'^.*\.(gcode|g|gc|gco)$', caseSensitive: false).hasMatch(name)) {
        return GCodeFile.fromJson(element, forPath);
      } else {
        return GenericFile.fromJson(element, forPath);
      }
    });

    return FolderContentWrapper(forPath, listOfFolder, listOfFiles);
  }

  dispose() {
    _fileActionStreamCtrler.close();
  }
}

Future<FileDownload> isolateDownloadFile({
  required BaseOptions dioBaseOptions,
  required String urlPath,
  required String savePath,
  required SendPort port,
  bool overWriteLocal = false,
}) async {
  var dio = Dio(dioBaseOptions);
  logger.i(
      'Created new dio instance for download with options: ${dioBaseOptions.connectTimeout}, ${dioBaseOptions.receiveTimeout}, ${dioBaseOptions.sendTimeout}');
  try {
    var file = File(savePath);
    if (!overWriteLocal && await file.exists()) {
      logger.i('File already exists, skipping download');
      return FileDownloadComplete(file);
    }
    logger.i('Starting download of $urlPath to $savePath');
    var progress = FileDownloadProgress(0);
    port.send(progress);
    await file.create(recursive: true);

    var response = await dio.download(
      urlPath,
      savePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        port.send(FileDownloadProgress(received / total));
      },
    );

    logger.i('Download complete');
    return FileDownloadComplete(file);
  } on DioException {
    rethrow;
  } catch (e) {
    logger.e('Error inside of isolate', e);
    throw MobilerakerException('Error while downloading file', parentException: e);
  } finally {
    logger.i('Closing dio instance');
    dio.close();
  }
}

sealed class FileDownload {}

class FileDownloadProgress extends FileDownload {
  FileDownloadProgress(this.progress);

  final double progress;

  @override
  String toString() {
    return 'FileDownloadProgress{progress: $progress}';
  }
}

class FileDownloadComplete extends FileDownload {
  FileDownloadComplete(this.file);

  final File file;

  @override
  String toString() {
    return 'FileDownloadComplete{file: $file}';
  }
}
