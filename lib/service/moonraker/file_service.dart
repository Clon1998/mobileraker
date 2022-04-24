import 'dart:async';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/exceptions.dart';
import 'package:mobileraker/datasource/json_rpc_client.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/files/file.dart';
import 'package:mobileraker/dto/files/folder.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_item.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_notification.dart';
import 'package:mobileraker/dto/files/notification/file_list_changed_source_item.dart';

enum FileRoot { gcodes, config, config_examples, docs }

enum FileAction {
  create_file,
  create_dir,
  delete_file,
  delete_dir,
  move_file,
  move_dir,
  modify_file,
  root_update
}

typedef FileListChangedListener = Function(
    Map<String, dynamic> item, Map<String, dynamic>? srcItem);

class FolderContentWrapper {
  FolderContentWrapper(this.reqPath, this.folders, this.files);

  String reqPath;
  List<Folder> folders;
  List<File> files;
}

/// The FileService handles all file changes of the different roots of moonraker
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#file-operations
/// 2. https://moonraker.readthedocs.io/en/latest/web_api/#file-list-changed
class FileService {
  FileService(this._owner) {
    _jRpcClient.addMethodListener(
        _onFileListChanged, "notify_filelist_changed");
  }

  final _logger = getLogger('FileService');

  final Machine _owner;

  StreamController<FileListChangedNotification> _fileActionStreamCtrler =
      StreamController.broadcast();

  Stream<FileListChangedNotification> get fileNotificationStream =>
      _fileActionStreamCtrler.stream;

  JsonRpcClient get _jRpcClient => _owner.jRpcClient;

  Future<FolderContentWrapper> fetchDirectoryInfo(String path,
      [bool extended = false]) async {
    _logger.i('Fetching for `$path` [extended:$extended]');

    RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod(
        'server.files.get_directory',
        params: {'path': path, 'extended': extended});

    String fileType = '.gcode';

    if (path.startsWith('config')) fileType = '.cfg';

    return _parseDirectory(blockingResp, path, fileType);
  }

  Future<GCodeFile> getGCodeMetadata(String filename) async {
    _logger.i('Getting meta for file: `$filename`');

    RpcResponse blockingResp = await _jRpcClient.sendJRpcMethod(
        'server.files.metadata',
        params: {'filename': filename});

    return _parseFileMeta(blockingResp, filename);
  }

  Future<void> createDir(String filePath) async {
    _logger.i('Creating Folder "$filePath"');

    await _jRpcClient
        .sendJRpcMethod('server.files.post_directory', params: {'path': filePath});
  }

  Future<void> deleteFile(String filePath) async {
    _logger.i('Deleting File "$filePath"');

    await _jRpcClient
        .sendJRpcMethod('server.files.delete_file', params: {'path': filePath});
  }

  Future<void> deleteDirForced(String filePath) async {
    _logger.i('Deleting Folder-Forced "$filePath"');

    await _jRpcClient.sendJRpcMethod('server.files.delete_directory',
        params: {'path': filePath, 'force': true});
  }

  Future<void> moveFile(String origin, String destination) async {
    _logger.i('Moving file from $origin to $destination');

    await _jRpcClient.sendJRpcMethod('server.files.move',
        params: {'source': origin, 'dest': destination});
  }

  _onFileListChanged(Map<String, dynamic> rawMessage) {
    Map<String, dynamic> params = rawMessage['params'][0];
    FileAction? fileAction =
        EnumToString.fromString(FileAction.values, params['action']);

    if (fileAction != null) {
      FileListChangedItem fileListChangedItem =
          FileListChangedItem.fromJson(params['item']);
      FileListChangedSourceItem? srcItem = (params['source_item'] != null)
          ? FileListChangedSourceItem.fromJson(params['source_item'])
          : null;

      _fileActionStreamCtrler.add(FileListChangedNotification(
          fileAction, fileListChangedItem, srcItem));
    }
  }

  FolderContentWrapper _parseDirectory(
      RpcResponse blockingResponse, String forPath,
      [String fileType = '.gcode']) {
    if (blockingResponse.hasError)
      throw FileFetchException(blockingResponse.err.toString(),
          reqPath: forPath);

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
      return !name.toLowerCase().endsWith(fileType);
    });

    List<File> listOfFiles = List.generate(filesResponse.length, (index) {
      var element = filesResponse[index];
      String name = element['filename'];

      if (name.endsWith('.gcode'))
        return GCodeFile.fromJson(element, forPath);
      else
        return File.fromJson(element, forPath);
    });

    return FolderContentWrapper(forPath, listOfFolder, listOfFiles);
  }

  GCodeFile _parseFileMeta(RpcResponse blockingResponse, String forFile) {
    if (blockingResponse.hasError)
      throw FileFetchException(blockingResponse.err.toString(),
          reqPath: forFile);

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
