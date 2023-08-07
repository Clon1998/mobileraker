/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/generic_file.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_action_enum.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_action_response.dart';
import 'package:mobileraker/data/dto/files/remote_file_mixin.dart';
import 'package:mobileraker/data/dto/jrpc/rpc_response.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/extensions/ref_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_service.freezed.dart';
part 'file_service.g.dart';

typedef FileListChangedListener = Function(
    Map<String, dynamic> item, Map<String, dynamic>? srcItem);

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
  var clientType =
      (machine != null) ? ref.watch(jrpcClientTypeProvider(machine.uuid)) : ClientType.local;
  if (machine != null) {
    if (clientType == ClientType.local) {
      return machine.httpUri;
    } else {
      var octoEverywhere = machine.octoEverywhere;
      return octoEverywhere!.uri;
    }
  }
  return null;
}

@riverpod
Map<String, String> previewImageHttpHeader(PreviewImageHttpHeaderRef ref) {
  var machine = ref.watch(selectedMachineProvider).valueOrFullNull;
  Map<String, String> headers = machine?.headerWithApiKey ?? {};
  var clientType =
      (machine != null) ? ref.watch(jrpcClientTypeProvider(machine.uuid)) : ClientType.local;
  if (machine != null) {
    if (clientType == ClientType.octo) {
      headers[HttpHeaders.authorizationHeader] = machine.octoEverywhere!.basicAuthorizationHeader;
    }
  }
  return headers;
}

@riverpod
FileService _fileServicee(_FileServiceeRef ref, String machineUUID, ClientType type) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrNull;

  if (machine == null) {
    throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
  }

  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));
  if (type == ClientType.local) {
    return FileService(ref, jsonRpcClient, machine.httpUri, machine.headerWithApiKey);
  } else if (type == ClientType.octo) {
    var octoEverywhere = machine.octoEverywhere;
    if (octoEverywhere == null) {
      throw ArgumentError('The provided machine,$machineUUID does not offer OctoEverywhere');
    }
    return FileService(
      ref,
      jsonRpcClient,
      octoEverywhere.uri.replace(
          userInfo: '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}'),
      machine.headerWithApiKey,
    );
  } else {
    throw ArgumentError('Unknown Client type $type');
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
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);
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
  FileService(AutoDisposeRef ref, this._jRpcClient, this.httpUri, this.headers) {
    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(_onFileListChanged, "notify_filelist_changed");
  }

  final Uri httpUri;
  final Map<String, String> headers;
  final MemoryFileSystem _fileSystem = MemoryFileSystem();

  final StreamController<FileActionResponse> _fileActionStreamCtrler = StreamController();

  Stream<FileActionResponse> get fileNotificationStream => _fileActionStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  Future<FolderContentWrapper> fetchDirectoryInfo(String path, [bool extended = false]) async {
    logger.i('Fetching for `$path` [extended:$extended]');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod('server.files.get_directory',
          params: {'path': path, 'extended': extended});

      Set<String> allowedFileType = {
        '.gcode',
        '.g',
        '.gc',
        '.gco',
      };

      if (path.startsWith('config')) allowedFileType = {'.conf', '.cfg', '.md'};

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

    var rpcResponse =
        await _jRpcClient.sendJRpcMethod('server.files.post_directory', params: {'path': filePath});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  Future<FileActionResponse> deleteFile(String filePath) async {
    logger.i('Deleting File "$filePath"');

    RpcResponse rpcResponse =
        await _jRpcClient.sendJRpcMethod('server.files.delete_file', params: {'path': filePath});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  Future<FileActionResponse> deleteDirForced(String filePath) async {
    logger.i('Deleting Folder-Forced "$filePath"');

    RpcResponse rpcResponse = await _jRpcClient
        .sendJRpcMethod('server.files.delete_directory', params: {'path': filePath, 'force': true});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  Future<FileActionResponse> moveFile(String origin, String destination) async {
    logger.i('Moving file from $origin to $destination');

    RpcResponse rpcResponse = await _jRpcClient
        .sendJRpcMethod('server.files.move', params: {'source': origin, 'dest': destination});
    return FileActionResponse.fromJson(rpcResponse.result);
  }

  // Throws TimeOut exception, if file download took to long!
  Future<File> downloadFile(String filePath, [Duration? timeout]) async {
    timeout ??= const Duration(seconds: 15);
    Uri uri = httpUri.replace(path: 'server/files/$filePath');
    logger.i('Trying download of $uri');
    try {
      HttpClientRequest clientRequest = await HttpClient().getUrl(uri).timeout(timeout);
      HttpClientResponse clientResponse = await clientRequest.close().timeout(timeout);

      final File file = _fileSystem.file(filePath)..createSync(recursive: true);
      IOSink writer = file.openWrite();
      await clientResponse.pipe(writer);
      // clientResponse.contentLength;
      // await clientResponse.map((s) {
      //   received += s.length;
      //   print("${(received / length) * 100} %");
      //   return s;
      // }).pipe(sink);
      await writer.close();
      return file;
    } on TimeoutException catch (e) {
      logger.w('Timeout reached while trying to download file: $filePath', e);
      throw const MobilerakerException('Timeout while trying to download File');
    }
  }

  Future<FileActionResponse> uploadAsFile(String filePath, String content) async {
    assert(!filePath.startsWith('(gcodes|config)'),
        'filePath needs to contain root folder config or gcodes!');
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
    FileAction? fileAction = EnumToString.fromString(FileAction.values, params['action']);

    if (fileAction != null) {
      _fileActionStreamCtrler.add(FileActionResponse.fromJson(params));
    }
  }

  FolderContentWrapper _parseDirectory(RpcResponse blockingResponse, String forPath,
      [Set<String> allowedFileType = const {'.gcode'}]) {
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

    filesResponse.removeWhere((element) {
      String name = element['filename'];
      var regExp =
          RegExp('^.*(${allowedFileType.join('|')})\$', multiLine: true, caseSensitive: false);
      return !regExp.hasMatch(name);
    });

    List<RemoteFile> listOfFiles = List.generate(filesResponse.length, (index) {
      var element = filesResponse[index];
      String name = element['filename'];
      if (RegExp(r'^.*\.(gcode|g|gc|gco)$').hasMatch(name)) {
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
    split.insert(
        0, 'gcodes'); // we need to add the gcodes here since the getMetaInfo omits gcodes path.

    return GCodeFile.fromJson(response, split.join('/'));
  }

  dispose() {
    _jRpcClient.removeMethodListener(_onFileListChanged, "notify_filelist_changed");
    _fileActionStreamCtrler.close();
  }
}
