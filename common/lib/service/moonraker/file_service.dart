/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
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
import 'package:common/exceptions/file_fetch_exception.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:worker_manager/worker_manager.dart';

import '../../network/jrpc_client_provider.dart';
import '../machine_service.dart';
import '../selected_machine_service.dart';

part 'file_service.freezed.dart';
part 'file_service.g.dart';

typedef FileListChangedListener = Function(Map<String, dynamic> item, Map<String, dynamic>? srcItem);

@freezed
class FolderContentWrapper with _$FolderContentWrapper {
  const factory FolderContentWrapper(
    String folderPath, [
    @Default([]) List<Folder> folders,
    @Default([]) List<RemoteFile> files,
  ]) = _FolderContentWrapper;
}

@riverpod
Uri? previewImageUri(PreviewImageUriRef ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;
  var clientType = (machine != null) ? ref.watch(jrpcClientTypeProvider(machine.uuid)) : ClientType.local;
  if (machine != null) {
    return switch (clientType) {
      ClientType.octo => machine.octoEverywhere?.uri,
      ClientType.manual => machine.remoteInterface?.remoteUri,
      ClientType.local || _ => machine.httpUri,
    };
  }
  return null;
}

@riverpod
Map<String, String> previewImageHttpHeader(PreviewImageHttpHeaderRef ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;

  var clientType = (machine != null) ? ref.watch(jrpcClientTypeProvider(machine.uuid)) : ClientType.local;
  if (machine != null) {
    return switch (clientType) {
      ClientType.manual => {
          if (machine.apiKey?.isNotEmpty == true) 'X-Api-Key': machine.apiKey!,
          ...machine.remoteInterface!.httpHeaders,
        },
      ClientType.octo => {
          ...machine.headerWithApiKey,
          HttpHeaders.authorizationHeader: machine.octoEverywhere!.basicAuthorizationHeader,
        },
      _ => machine.headerWithApiKey,
    };
  }
  return {};
}

@riverpod
FileService _fileServicee(_FileServiceeRef ref, String machineUUID, ClientType type) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrNull;

  if (machine == null) {
    throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
  }

  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  switch (type) {
    case ClientType.octo:
      var octoEverywhere = machine.octoEverywhere;
      if (octoEverywhere == null) {
        throw ArgumentError('The provided machine,$machineUUID does not offer OctoEverywhere');
      }
      return FileService(
        ref,
        jsonRpcClient,
        octoEverywhere.uri
            .replace(userInfo: '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}'),
        machine.headerWithApiKey,
      );
    case ClientType.manual:
      var remoteInterface = machine.remoteInterface!;

      return FileService(
        ref,
        jsonRpcClient,
        remoteInterface.remoteUri.replace(path: machine.httpUri.path, query: machine.httpUri.query),
        {
          if (machine.apiKey?.isNotEmpty == true) 'X-Api-Key': machine.apiKey!,
          ...remoteInterface.httpHeaders,
        },
      );

    case ClientType.local:
    default:
      return FileService(ref, jsonRpcClient, machine.httpUri, machine.headerWithApiKey);
  }
}

@riverpod
FileService fileService(FileServiceRef ref, String machineUUID) {
  var clientType = ref.watch(jrpcClientTypeProvider(machineUUID));

  return ref.watch(_fileServiceeProvider(machineUUID, clientType));
}

@riverpod
Stream<FileActionResponse> fileNotifications(FileNotificationsRef ref, String machineUUID) {
  return ref.watch(fileServiceProvider(machineUUID)).fileNotificationStream;
}

@riverpod
FileService fileServiceSelected(FileServiceSelectedRef ref) {
  return ref.watch(fileServiceProvider(ref.watch(selectedMachineProvider).valueOrNull!.uuid));
}

@riverpod
Stream<FileActionResponse> fileNotificationsSelected(FileNotificationsSelectedRef ref) async* {
  try {
    var machine = await ref.watch(selectedMachineProvider.future);
    if (machine == null) return;
    yield* ref.watchAsSubject(fileNotificationsProvider(machine.uuid));
  } on StateError catch (_) {
// Just catch it. It is expected that the future/where might not complete!
  }
}

/// The FileService handles all file changes of the different roots of moonraker
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#file-operations
/// 2. https://moonraker.readthedocs.io/en/latest/web_api/#file-list-changed
class FileService {
  FileService(AutoDisposeRef ref, this._jRpcClient, this.httpUri, this.headers)
      : _downloadReceiverPortName = 'downloadFilePort-${httpUri.hashCode}' {
    // var downloadManager = DownloadManager.instance;

    // We need an mobileraker HTTP client
    // downloadManager.init();

    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(_onFileListChanged, "notify_filelist_changed");
  }

  final String _downloadReceiverPortName;

  final Uri httpUri;
  final Map<String, String> headers;

  final StreamController<FileActionResponse> _fileActionStreamCtrler = StreamController();

  Stream<FileActionResponse> get fileNotificationStream => _fileActionStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  Future<List<FileRoot>> fetchRoots() async {
    logger.i('Fetching roots');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod('server.files.roots');

      List<dynamic> rootsResponse = blockingResp.result as List;
      return List.generate(rootsResponse.length, (index) {
        var element = rootsResponse[index];
        return FileRoot.fromJson(element);
      });
    } on JRpcError catch (e) {
      logger.w('Error while fetching roots', e);
      throw FileFetchException(e.toString());
    }
  }

  Future<FolderContentWrapper> fetchDirectoryInfo(String path, [bool extended = false]) async {
    logger.i('Fetching for `$path` [extended:$extended]');

    try {
      RpcResponse blockingResp =
          await _jRpcClient.sendJRpcMethod('server.files.get_directory', params: {'path': path, 'extended': extended});

      Set<String>? allowedFileType;

      if (path.startsWith('gcodes')) {
        allowedFileType = {
          '.gcode',
          '.g',
          '.gc',
          '.gco',
        };
      } else if (path.startsWith('config')) {
        allowedFileType = {'.conf', '.cfg', '.md', '.bak', '.txt'};
      } else if (path.startsWith('timelapse')) {
        allowedFileType = {'.mp4'};
      }

      return _parseDirectory(blockingResp, path, allowedFileType);
    } on JRpcError catch (e) {
      throw FileFetchException(e.toString(), reqPath: path);
    }
  }

  Future<GCodeFile> getGCodeMetadata(String filename) async {
    logger.i('Getting meta for file: `$filename`');

    try {
      RpcResponse blockingResp =
          await _jRpcClient.sendJRpcMethod('server.files.metadata', params: {'filename': filename});

      return _parseFileMeta(blockingResp, filename);
    } on JRpcError catch (e) {
      throw FileFetchException(e.toString(), reqPath: filename);
    }
  }

  Future<FileActionResponse> createDir(String filePath) async {
    logger.i('Creating Folder "$filePath"');

    var rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.post_directory', params: {'path': filePath});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  Future<FileActionResponse> deleteFile(String filePath) async {
    logger.i('Deleting File "$filePath"');

    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.files.delete_file', params: {'path': filePath});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  Future<FileActionResponse> deleteDirForced(String filePath) async {
    logger.i('Deleting Folder-Forced "$filePath"');

    RpcResponse rpcResponse =
        await _jRpcClient.sendJRpcMethod('server.files.delete_directory', params: {'path': filePath, 'force': true});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  Future<FileActionResponse> moveFile(String origin, String destination) async {
    logger.i('Moving file from $origin to $destination');

    RpcResponse rpcResponse =
        await _jRpcClient.sendJRpcMethod('server.files.move', params: {'source': origin, 'dest': destination});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  // Throws TimeOut exception, if file download took to long!
  ///TODO: Migrate this code to a approach based off isolates to ensure the UI does not flicker/studders
  Stream<FileDownload> downloadFile(String filePath, [Duration? timeout]) async* {
    final downloadUri = httpUri.replace(path: 'server/files/$filePath');
    final tmpDir = await getTemporaryDirectory();
    final File file = File('${tmpDir.path}/$filePath');
    final Map<String, String> isolateSafeHeaders = Map.from(headers);
    final String isolateSafePortName = _downloadReceiverPortName;
    logger.i('Will try to download $filePath to file $file from uri ${downloadUri.obfuscate()}');

    final ReceivePort receiverPort = ReceivePort();
    IsolateNameServer.registerPortWithName(receiverPort.sendPort, isolateSafePortName);

    var download = workerManager.execute<FileDownload>(() async {
      await setupIsolateLogger();
      logger.i('Hello from worker ${file.path} - my port will be: $isolateSafePortName');
      var port = IsolateNameServer.lookupPortByName(isolateSafePortName)!;

      return await isolateDownloadFile(
          port: port, targetUri: downloadUri, downloadPath: file.path, headers: isolateSafeHeaders, timeout: timeout);
    });
    download.whenComplete(() {
      logger.i('File download done, cleaning up port');
      IsolateNameServer.removePortNameMapping(isolateSafePortName);
    });

    yield* receiverPort
        .takeUntil(download.asStream()).cast<FileDownload>();
    receiverPort.close();
    logger.i('Closed the port');
    yield await download;
  }

  Future<FileActionResponse> uploadAsFile(String filePath, String content) async {
    assert(!filePath.startsWith('(gcodes|config)'), 'filePath needs to contain root folder config or gcodes!');
    List<String> fileSplit = filePath.split('/');
    String root = fileSplit.removeAt(0);

    Uri uri = httpUri.replace(path: 'server/files/upload');
    ;
    logger.i('Trying upload of $filePath');
    http.MultipartRequest multipartRequest = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromString('file', content, filename: fileSplit.join('/')))
      ..fields['root'] = root;
    http.StreamedResponse streamedResponse = await multipartRequest.send();
    http.Response response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      throw HttpException('Error while uploading file $filePath.', uri: uri);
    }
    return FileActionResponse.fromJson(jsonDecode(response.body));
  }

  _onFileListChanged(Map<String, dynamic> rawMessage) {
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

  GCodeFile _parseFileMeta(RpcResponse blockingResponse, String forFile) {
    Map<String, dynamic> response = blockingResponse.result;

    var split = forFile.split('/');
    split.removeLast();
    split.insert(0, 'gcodes'); // we need to add the gcodes here since the getMetaInfo omits gcodes path.

    return GCodeFile.fromJson(response, split.join('/'));
  }

  Uri composeFileUriForDownload(RemoteFile file) {
    return httpUri.replace(path: 'server/files/${file.absolutPath}');
  }

  dispose() {
    _jRpcClient.removeMethodListener(_onFileListChanged, "notify_filelist_changed");
    _fileActionStreamCtrler.close();
  }
}

Future<FileDownload> isolateDownloadFile({
  required SendPort port,
  required Uri targetUri,
  required String downloadPath,
  Map<String, String> headers = const {},
  Duration? timeout,
}) async {
  logger.i('Got headers: $headers and timeout: $timeout');
  var file = File(downloadPath);
  timeout ??= const Duration(seconds: 10);

  if (await file.exists()) {
    logger.i('File already exists, skipping download');
    return FileDownloadComplete(file);
  }
  port.send(FileDownloadProgress(0));
  await file.create(recursive: true);

  HttpClientRequest clientRequest = await HttpClient().getUrl(targetUri).timeout(timeout);
  headers.forEach(clientRequest.headers.add);
  HttpClientResponse clientResponse = await clientRequest.close().timeout(timeout);

  IOSink writer = file.openWrite();
  var totalLen = clientResponse.contentLength;
  var received = 0;
  await clientResponse.map((s) {
    received += s.length;
    port.send(FileDownloadProgress(received / totalLen));
    return s;
  }).pipe(writer);
  await writer.close();
  logger.i('Download completed!');
  return FileDownloadComplete(file);
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
