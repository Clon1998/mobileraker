/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';

import 'package:common/common.dart';
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
import 'package:common/network/dio_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/path_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/files/moonraker/file_item.dart';
import '../../data/model/file_operation.dart';
import '../../network/http_client_factory.dart';
import '../../network/jrpc_client_provider.dart';
import '../selected_machine_service.dart';

part 'file_service.freezed.dart';
part 'file_service.g.dart';

typedef FileListChangedListener = Function(Map<String, dynamic> item, Map<String, dynamic>? srcItem);

const bakupFileExtensions = {'bak', 'backup'};

const gcodeFileExtensions = {'gcode', 'g', 'gc', 'gco'};

const configFileExtensions = {'conf', 'cfg'};

const textFileExtensions = {'md', 'txt', 'log', 'json', 'xml', 'yaml', 'yml'};

const imageFileExtensions = {'jpeg', 'jpg', 'png'};

const videoFileExtensions = {'mp4'};

const archiveFileExtensions = {'zip', 'tar', 'gz', '7z'};

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
CacheManager httpCacheManager(Ref ref, String machineUUID) {
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
Uri? previewImageUri(Ref ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;

  if (machine == null) return null;

  var dio = ref.watch(dioClientProvider(machine.uuid));

  return Uri.tryParse(dio.options.baseUrl);
}

@riverpod
Map<String, String> previewImageHttpHeader(Ref ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;
  if (machine == null) return {};

  var dio = ref.watch(dioClientProvider(machine.uuid));
  return dio.options.headers.cast<String, String>();
}

@riverpod
FileService fileService(Ref ref, String machineUUID) {
  var dio = ref.watch(dioClientProvider(machineUUID));
  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  return FileService(ref, machineUUID, jsonRpcClient, dio);
}

@riverpod
Stream<FileActionResponse> _rawFileNotifications(Ref ref, String machineUUID) {
  return ref.watch(fileServiceProvider(machineUUID)).fileNotificationStream;
}

@riverpod
Stream<FileActionResponse> fileNotifications(Ref ref, String machineUUID, [String? path]) {
  StreamController<FileActionResponse> streamController = StreamController();
  ref.onDispose(streamController.close);

  if (path != null) {
    // This code checks if the notification is related to the provided path
    // This means:
    // 1. If the path is the same as the notification path
    // 2. If an item in the path is a child of the notification path

    ref.listen(
        _rawFileNotificationsProvider(machineUUID),
        (prev, next) => next.whenData((notification) {
              // Original File (Src)
              FileItem? srcItem = notification.sourceItem;
              var srcItemWithInLevel = isWithin(path, srcItem?.fullPath ?? '');
              // Destination File (Dest)
              FileItem destItem = notification.item;
              var itemWithInLevel = isWithin(path, destItem.fullPath);

              // Check if src or dest are in current path (Items moved in/out of current folder)
              // if the src is the same as the current path (Current folder was modified)
              if (itemWithInLevel != 0 &&
                  srcItemWithInLevel != 0 &&
                  srcItem?.fullPath != path &&
                  destItem.fullPath != path) {
                return;
              }
              if (!streamController.isClosed) {
                streamController.add(notification);
              }
            }));
  }

  return streamController.stream;
}

@riverpod
FileService fileServiceSelected(Ref ref) {
  return ref.watch(fileServiceProvider(ref.watch(selectedMachineProvider).requireValue!.uuid));
}

@riverpod
Stream<FileActionResponse> fileNotificationsSelected(Ref ref) async* {
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
Future<FolderContentWrapper> directoryInfoApiResponse(Ref ref, String machineUUID, String path) async {
  ref.keepAliveFor();
  // Invalidation of the cache is done by the fileNotificationsProvider
  ref.listen(fileNotificationsProvider(machineUUID, path), (prev, next) => next.whenData((d) => ref.invalidateSelf()));

  final fetchDirectoryInfo = await ref.watch(fileServiceProvider(machineUUID)).fetchDirectoryInfo(path, true);
  return fetchDirectoryInfo;
}

@riverpod
Future<FolderContentWrapper> moonrakerFolderContent(
    Ref ref, String machineUUID, String path, SortConfiguration sortConfig) async {
  ref.keepAliveFor();
  ref.listen(fileNotificationsProvider(machineUUID, path), (prev, next) => next.whenData((d) => ref.invalidateSelf()));
  // await Future.delayed(const Duration(milliseconds: 5000));
  final apiResponse = await ref.watch(directoryInfoApiResponseProvider(machineUUID, path).future);

  List<Folder> folders = apiResponse.folders.toList();
  List<RemoteFile> files = apiResponse.files.toList();

  final comp = sortConfig.comparator;

  files.sort(comp);
  folders.sort(comp);
  return FolderContentWrapper(apiResponse.folderPath, folders, files);
}

@riverpod
Future<RemoteFile> remoteFile(Ref ref, String machineUUID, String path) async {
  ref.keepAliveFor();
  // Note: It is expected that all requested paths point to a FILE and not to a DIR
  // There is no good way to check this!!! So be careful
  final parts = path.split('/');
  final parent = parts.sublist(0, parts.length - 1).join('/');

  // Get the parent data (By default this should already be present in the cache as the primary user is the file manager)
  final parentData = await ref.watch(directoryInfoApiResponseProvider(machineUUID, parent).future);
  // Find the file in the parent data
  var firstWhere = parentData.unwrapped.firstWhere((element) => element.absolutPath == path);
  return firstWhere;
}

/// The FileService handles all file changes of the different roots of moonraker
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#file-operations
/// 2. https://moonraker.readthedocs.io/en/latest/web_api/#file-list-changed
class FileService {
  FileService(Ref ref, this._machineUUID, this._jRpcClient, this._dio)
      : _apiRequestTimeout =
            _jRpcClient.timeout > const Duration(seconds: 30) ? _jRpcClient.timeout : const Duration(seconds: 30) {
    ref.onDispose(dispose);
    ref.listen(jrpcMethodEventProvider(_machineUUID, 'notify_filelist_changed'), _onFileListChanged);
  }

  final String _machineUUID;

  final StreamController<FileActionResponse> _fileActionStreamCtrler = StreamController();

  Stream<FileActionResponse> get fileNotificationStream => _fileActionStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  final Dio _dio;

  final Duration _apiRequestTimeout;

  Future<List<FileRoot>> fetchRoots() async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Fetching roots');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod('server.files.roots', timeout: _apiRequestTimeout);

      List<dynamic> rootsResponse = blockingResp.result as List;
      return List.generate(rootsResponse.length, (index) {
        var element = rootsResponse[index];
        return FileRoot.fromJson(element);
      });
    } on JRpcError catch (e) {
      talker.warning('[FileService($_machineUUID, ${_jRpcClient.uri})] Error while fetching roots', e);
      throw FileFetchException('Jrpc error while trying to fetch roots.', parent: e);
    }
  }

  Future<FolderContentWrapper> fetchDirectoryInfo(String path, [bool extended = false]) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Fetching for `$path` [extended:$extended]');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod(
        'server.files.get_directory',
        params: {'path': path, 'extended': extended},
        timeout: _apiRequestTimeout,
      );

      Set<String>? allowedFileType;

      if (path.startsWith('gcodes')) {
        allowedFileType = {...gcodeFileExtensions, ...bakupFileExtensions, ...archiveFileExtensions};
      } else if (path.startsWith('config')) {
        allowedFileType = {
          ...configFileExtensions,
          ...textFileExtensions,
          ...bakupFileExtensions,
          ...imageFileExtensions,
          ...archiveFileExtensions,
        };
      } else if (path.startsWith('timelapse')) {
        allowedFileType = videoFileExtensions;
      }

      return _parseDirectory(blockingResp, path, allowedFileType);
    } on JRpcError catch (e) {
      throw FileFetchException('Jrpc error while trying to fetch directory.', reqPath: path, parent: e);
    }
  }

  /// The FilePath is relativ to the `gcodes` root
  Future<GCodeFile> getGCodeMetadata(String filePath) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Getting meta for file: `$filePath`');

    final parentPathParts = filePath.split('/')
      ..insert(0, 'gcodes'); // we need to add the gcodes here since the getMetaInfo omits gcodes path.
    final fileName = parentPathParts.removeLast();
    final parentPath = parentPathParts.join('/');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod('server.files.metadata',
          params: {'filename': filePath}, timeout: _apiRequestTimeout);

      return GCodeFile.fromMetaData(fileName, parentPath, blockingResp.result);
    } on JRpcError catch (e) {
      if (e.message.contains('Metadata not available for')) {
        talker.warning('[FileService($_machineUUID, ${_jRpcClient.uri})] Metadata not available for $filePath');
        return GCodeFile(name: fileName, parentPath: parentPath, modified: -1, size: -1);
      }

      throw FileFetchException('Jrpc error while trying to get metadata.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> createDir(String filePath) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Creating Folder "$filePath"');

    try {
      final rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.post_directory',
          params: {'path': filePath}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to create directory.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> deleteFile(String filePath) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Deleting File "$filePath"');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.delete_file',
          params: {'path': filePath}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to delete file.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> deleteDirForced(String filePath) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Deleting Folder-Forced "$filePath"');
    try {
      RpcResponse rpcResponse =
          await _jRpcClient.sendJRpcMethod('server.files.delete_directory', params: {'path': filePath, 'force': true});
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to force-delete directory.', reqPath: filePath, parent: e);
    }
  }

  Future<FileActionResponse> moveFile(String origin, String destination) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Moving file from $origin to $destination');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.move',
          params: {'source': origin, 'dest': destination}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to move file.', reqPath: origin, parent: e);
    }
  }

  Future<FileActionResponse> copyFile(String origin, String destination) async {
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Copying file from $origin to $destination');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.copy',
          params: {'source': origin, 'dest': destination}, timeout: _apiRequestTimeout);
      return FileActionResponse.fromJson(rpcResponse.result);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to copy file.', reqPath: origin, parent: e);
    }
  }

  Future<FileItem> zipFiles(String? destination, List<String> origins, [bool compress = true]) async {
    assert(origins.isNotEmpty, 'At least one origin needs to be provided');
    assert(destination == null || destination.endsWith('.zip'), 'Destination needs to end with .zip if provided');

    talker.info(
        '[FileService($_machineUUID, ${_jRpcClient.uri})] Creating zip(compression=$compress) file at $destination from $origins');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.files.zip',
        params: {'dest': destination, 'items': origins, 'store_only': !compress},
        timeout: _apiRequestTimeout,
      );
      return FileItem.fromJson(rpcResponse.result['destination']);
    } on JRpcError catch (e) {
      throw FileActionException('Jrpc error while trying to zip files.', reqPath: destination, parent: e);
    }
  }

  Stream<FileOperation> downloadFile(
      {required String filePath, int? expectedFileSize, bool overWriteLocal = false, CancelToken? cancelToken}) async* {
    final tmpDir = await getTemporaryDirectory();
    final File file = File('${tmpDir.path}/$_machineUUID/$filePath');

    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Starting download of $filePath to ${file.path}');
    if (!overWriteLocal &&
        await file.exists() &&
        DateTime.now().difference(await file.lastModified()) < const Duration(minutes: 60)) {
      talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] File already exists, skipping download');
      yield FileDownloadComplete(file);
      return;
    }

    final StreamController<FileOperation> updateProgress = StreamController();

    Completer<bool>? debounceKeepAlive;
    // I can not await this because I need to use the callbacks to fill my streamController
    _dio.download(
      '/server/files/$filePath',
      file.path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total <= 0 && expectedFileSize != null) {
          total = expectedFileSize;
        }
        if (total <= 0) {
          // talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Download is alive... no total, ${debounceKeepAlive?.isCompleted}');
          // Debounce the keep alive to not spam the stream
          if (debounceKeepAlive == null || debounceKeepAlive?.isCompleted == true) {
            debounceKeepAlive = Completer();
            Future.delayed(const Duration(seconds: 1), () {
              debounceKeepAlive?.complete(true);
            });
            updateProgress.add(FileOperationKeepAlive(bytes: received));
          }
          return;
        }
        // talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Progress for $filePath: ${received / total * 100}');
        updateProgress.add(FileOperationProgress((received / total).clamp(0.0, 1.0)));
      },
    ).then((response) {
      talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Download of "$filePath" completed');
      updateProgress.add(FileDownloadComplete(file));
    }).catchError((e, s) {
      if (e case DioException(type: DioExceptionType.cancel)) {
        talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Download of "$filePath" was canceled');
        updateProgress.add(FileOperationCanceled());
      } else {
        talker.error(
            '[FileService($_machineUUID, ${_jRpcClient.uri})] Error while downloading file "$filePath" caught in catchError',
            e);
        updateProgress.addError(e, s);
      }
    }).whenComplete(updateProgress.close);

    yield* updateProgress.stream;
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] File download completed');
  }

  Stream<FileOperation> uploadFile(String filePath, MultipartFile uploadContent, [CancelToken? cancelToken]) async* {
    assert(!filePath.startsWith(r'(gcodes|config)'), 'filePath needs to contain root folder config or gcodes!');
    List<String> fileSplit = filePath.split('/');
    String root = fileSplit.removeAt(0);
    final data = FormData.fromMap({'root': root, 'file': uploadContent});

    final StreamController<FileOperation> updateStream = StreamController();

    talker.info(
        '[FileService($_machineUUID, ${_jRpcClient.uri})] Starting upload of ${uploadContent.filename ?? 'unknown'} to $filePath');

    Completer<bool>? debounceKeepAlive;

    _dio.post(
      '/server/files/upload',
      data: data,
      options: Options(validateStatus: (status) => status == 201, receiveTimeout: _apiRequestTimeout)
        ..disableRetry = true,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total <= 0) {
          // talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Download is alive... no total, ${debounceKeepAlive?.isCompleted}');
          // Debounce the keep alive to not spam the stream
          if (debounceKeepAlive == null || debounceKeepAlive?.isCompleted == true) {
            debounceKeepAlive = Completer();
            Future.delayed(const Duration(seconds: 1), () {
              debounceKeepAlive?.complete(true);
            });
            updateStream.add(FileOperationKeepAlive(bytes: sent));
          }
          return;
        }
        // talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Progress for $filePath: ${received / total * 100}');
        updateStream.add(FileOperationProgress(sent / total));
      },
    ).then((response) {
      final res = FileActionResponse.fromJson(response.data);
      talker.info(
          '[FileService($_machineUUID, ${_jRpcClient.uri})] Upload of ${uploadContent.filename ?? 'unknown'} to $filePath completed');
      talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Response: $res');

      updateStream.add(FileUploadComplete(res.item.fullPath));
    }).catchError((e, s) {
      if (e case DioException(type: DioExceptionType.cancel)) {
        talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Upload of "$filePath" was canceled');
        updateStream.add(FileOperationCanceled());
      } else {
        talker.error(
            '[FileService($_machineUUID, ${_jRpcClient.uri})] Error while uploading file "$filePath" caught in catchError',
            e);
        updateStream.addError(e, s);
      }
    }).whenComplete(updateStream.close);

    yield* updateStream.stream;
    talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] File upload completed');
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
        final String name = element['filename'];
        final regExp = RegExp('^.*\.(${allowedFileType.join('|')})\$', multiLine: true, caseSensitive: false);
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
//
// Future<FileDownload> isolateDownloadFile({
//   required BaseOptions dioBaseOptions,
//   required String urlPath,
//   required String savePath,
//   required SendPort port,
//   bool overWriteLocal = false,
// }) async {
//   var dio = Dio(dioBaseOptions);
//   talker.info(
//       'Created new dio instance for download with options: ${dioBaseOptions.connectTimeout}, ${dioBaseOptions.receiveTimeout}, ${dioBaseOptions.sendTimeout}');
//   try {
//     var file = File(savePath);
//     if (!overWriteLocal && await file.exists()) {
//       talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] File already exists, skipping download');
//       return FileDownloadComplete(file, token: );
//     }
//     talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Starting download of $urlPath to $savePath');
//     var progress = FileDownloadProgress(0);
//     port.send(progress);
//     await file.create(recursive: true);
//
//     var response = await dio.download(
//       urlPath,
//       savePath,
//       onReceiveProgress: (received, total) {
//         if (total <= 0) return;
//         port.send(FileDownloadProgress(received / total));
//       },
//     );
//
//     talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Download complete');
//     return FileDownloadComplete(file);
//   } on DioException {
//     rethrow;
//   } catch (e) {
//     talker.error('[FileService($_machineUUID, ${_jRpcClient.uri})] Error inside of isolate', e);
//     throw MobilerakerException('Error while downloading file', parentException: e);
//   } finally {
//     talker.info('[FileService($_machineUUID, ${_jRpcClient.uri})] Closing dio instance');
//     dio.close();
//   }
// }
