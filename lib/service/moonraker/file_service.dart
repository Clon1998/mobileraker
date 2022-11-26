import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/files/folder.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_api_response.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:mobileraker/util/ref_extension.dart';

enum FileRoot { gcodes, config, config_examples, docs }

enum FileAction {
  create_file, // ignore: constant_identifier_names
  create_dir, // ignore: constant_identifier_names
  delete_file, // ignore: constant_identifier_names
  delete_dir, // ignore: constant_identifier_names
  move_file, // ignore: constant_identifier_names
  move_dir, // ignore: constant_identifier_names
  modify_file, // ignore: constant_identifier_names
  root_update // ignore: constant_identifier_names
}

typedef FileListChangedListener = Function(
    Map<String, dynamic> item, Map<String, dynamic>? srcItem);

class FolderContentWrapper {
  FolderContentWrapper(this.folderPath, this.folders, this.files);

  final String folderPath;
  final List<Folder> folders;
  final List<RemoteFile> files;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderContentWrapper &&
          runtimeType == other.runtimeType &&
          folderPath == other.folderPath &&
          listEquals(folders, other.folders) &&
          listEquals(files, other.files);

  @override
  int get hashCode =>
      folderPath.hashCode ^ folders.hashIterable ^ files.hashIterable;
}

final fileServiceProvider =
    Provider.autoDispose.family<FileService, String>((ref, machineUUID) {
  ref.keepAlive();
  var jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));
  var machine = Hive.box<Machine>('printers').get(machineUUID);
  if (machine == null) {
    throw MobilerakerException(
        'Machine with UUID "$machineUUID" was not found!');
  }
  return FileService(ref, jsonRpcClient, machine.httpUrl);
});

final fileNotificationsProvider = StreamProvider.autoDispose
    .family<FileApiResponse, String>((ref, machineUUID) {
  ref.keepAlive();
  return ref.watch(fileServiceProvider(machineUUID)).fileNotificationStream;
});

final fileServiceSelectedProvider = Provider.autoDispose((ref) {
  return ref.watch(fileServiceProvider(
      ref.watch(selectedMachineProvider).valueOrNull!.uuid));
});

final fileNotificationsSelectedProvider =
    StreamProvider.autoDispose<FileApiResponse>((ref) async* {
  try {
    var machine = await ref.watchWhereNotNull(selectedMachineProvider);

    // ToDo: Remove woraround once StreamProvider.stream is fixed!
    yield await ref.read(fileNotificationsProvider(machine.uuid).future);
    yield* ref.watch(fileNotificationsProvider(machine.uuid).stream);
  } on StateError catch (e, s) {
// Just catch it. It is expected that the future/where might not complete!
  }
});

/// The FileService handles all file changes of the different roots of moonraker
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#file-operations
/// 2. https://moonraker.readthedocs.io/en/latest/web_api/#file-list-changed
class FileService {
  FileService(AutoDisposeRef ref, this._jRpcClient, this.httpUrl) {
    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(
        _onFileListChanged, "notify_filelist_changed");
  }

  final String httpUrl;
  final MemoryFileSystem _fileSystem = MemoryFileSystem();

  final StreamController<FileApiResponse> _fileActionStreamCtrler =
      StreamController();

  Stream<FileApiResponse> get fileNotificationStream =>
      _fileActionStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  Future<FolderContentWrapper> fetchDirectoryInfo(String path,
      [bool extended = false]) async {
    logger.i('Fetching for `$path` [extended:$extended]');

    try {
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod(
          'server.files.get_directory',
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
      RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod(
          'server.files.metadata',
          params: {'filename': filename});

      return _parseFileMeta(blockingResp, filename);
    } on JRpcError catch (e) {
      throw FileFetchException(e.toString(), reqPath: filename);
    }
  }

  Future<FileApiResponse> createDir(String filePath) async {
    logger.i('Creating Folder "$filePath"');

    var rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.files.post_directory',
        params: {'path': filePath});
    return FileApiResponse.fromJson(rpcResponse.response['result']);
  }

  Future<FileApiResponse> deleteFile(String filePath) async {
    logger.i('Deleting File "$filePath"');

    RpcResponse rpcResponse = await _jRpcClient
        .sendJRpcMethod('server.files.delete_file', params: {'path': filePath});
    return FileApiResponse.fromJson(rpcResponse.response['result']);
  }

  Future<FileApiResponse> deleteDirForced(String filePath) async {
    logger.i('Deleting Folder-Forced "$filePath"');

    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.files.delete_directory',
        params: {'path': filePath, 'force': true});
    return FileApiResponse.fromJson(rpcResponse.response['result']);
  }

  Future<FileApiResponse> moveFile(String origin, String destination) async {
    logger.i('Moving file from $origin to $destination');

    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.files.move',
        params: {'source': origin, 'dest': destination});
    return FileApiResponse.fromJson(rpcResponse.response['result']);
  }

  Future<File> downloadFile(String filePath) async {
    Uri uri = Uri.parse('$httpUrl/server/files/$filePath');
    logger.i('Trying download of $uri');
    HttpClientRequest clientRequest = await HttpClient().getUrl(uri);
    HttpClientResponse clientResponse = await clientRequest.close();

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
  }

  Future<FileApiResponse> uploadAsFile(String filePath, String content) async {
    assert(!filePath.startsWith('(gcodes|config)'),
        'filePath needs to contain root folder config or gcodes!');
    List<String> fileSplit = filePath.split('/');
    String root = fileSplit.removeAt(0);

    Uri uri = Uri.parse('$httpUrl/server/files/upload');
    logger.i('Trying upload of $filePath');
    http.MultipartRequest multipartRequest = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromString('file', content,
          filename: fileSplit.join('/')))
      ..fields['root'] = root;
    http.StreamedResponse streamedResponse = await multipartRequest.send();
    http.Response response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 201) {
      throw HttpException('Error while uploading file $filePath.', uri: uri);
    }
    return FileApiResponse.fromJson(jsonDecode(response.body));
  }

  _onFileListChanged(Map<String, dynamic> rawMessage) {
    Map<String, dynamic> params = rawMessage['params'][0];
    FileAction? fileAction =
        EnumToString.fromString(FileAction.values, params['action']);

    if (fileAction != null) {
      _fileActionStreamCtrler.add(FileApiResponse.fromJson(params));
    }
  }

  FolderContentWrapper _parseDirectory(
      RpcResponse blockingResponse, String forPath,
      [Set<String> allowedFileType = const {'.gcode'}]) {
    Map<String, dynamic> response = blockingResponse.response['result'];
    List<dynamic> filesResponse = response['files']; // Just add an type
    List<dynamic> directoriesResponse = response['dirs']; // Just add an type

    directoriesResponse.removeWhere((element) {
      String name = element['dirname'];
      return name.startsWith('.');
    });

    List<Folder> listOfFolder =
        List.generate(directoriesResponse.length, (index) {
      var element = directoriesResponse[index];
      String name = element['dirname'];
      double lastModified = element['modified'];
      int size = element['size'];

      return Folder(name: name, modified: lastModified, size: size);
    });

    filesResponse.removeWhere((element) {
      String name = element['filename'];
      var regExp = RegExp('^.*(${allowedFileType.join('|')})\$',
          multiLine: true, caseSensitive: false);
      return !regExp.hasMatch(name);
    });

    List<RemoteFile> listOfFiles = List.generate(filesResponse.length, (index) {
      var element = filesResponse[index];
      String name = element['filename'];
      if (RegExp(r'^.*(.gcode|.g|.gc|.gco)$').hasMatch(name)) {
        return GCodeFile.fromJson(element, forPath);
      } else {
        return RemoteFile.fromJson(element, forPath);
      }
    });

    return FolderContentWrapper(forPath, listOfFolder, listOfFiles);
  }

  GCodeFile _parseFileMeta(RpcResponse blockingResponse, String forFile) {
    Map<String, dynamic> response = blockingResponse.response['result'];

    var split = forFile.split('/');
    split.removeLast();
    split.insert(0,
        'gcodes'); // we need to add the gcodes here since the getMetaInfo omits gcodes path.

    return GCodeFile.fromJson(response, split.join('/'));
  }

  dispose() {
    _fileActionStreamCtrler.close();
  }
}
