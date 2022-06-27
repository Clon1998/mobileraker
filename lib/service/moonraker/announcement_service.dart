import 'dart:async';

import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/exceptions.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/data/dto/announcement/announcement_entry.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_api_response.dart';
import 'package:mobileraker/data/model/hive/machine.dart';

/// The AnnouncementService handles different notifications/announcements from feed api.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#announcement-apis
class AnnouncementService {
  AnnouncementService(this._owner) {
    _jRpcClient.addMethodListener(
        _onNotifyAnnouncementUpdate, "notify_announcement_update");
    _jRpcClient.addMethodListener(
        _onNotifyAnnouncementDismissed, "notify_announcement_dismissed");
    _jRpcClient.addMethodListener(
        _onNotifyAnnouncementWake, "notify_announcement_wake");
  }

  final _logger = getLogger('AnnouncementService');

  final Machine _owner;

  StreamController<List<AnnouncementEntry>> _announcementsStreamCtrler =
      StreamController.broadcast();

  Stream<List<AnnouncementEntry>> get announcementNotificationStream =>
      _announcementsStreamCtrler.stream;

  JsonRpcClient get _jRpcClient => _owner.jRpcClient;

  Future<List<AnnouncementEntry>> listAnnouncements(
      [bool includeDismissed = false]) async {
    _logger.i('List Announcements request...');

    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.announcements.list',
        params: {'include_dismissed': includeDismissed});

    if (rpcResponse.hasError)
      throw MobilerakerException('Unable to fetch announcement list');

    List<Map<String, dynamic>> entries =
        rpcResponse.response['result']['entries'];

    return _parseAnnouncementsList(entries);
  }

  Future<String> dismissAnnouncement(String entryId, [int? wakeTime]) async {
    _logger.i('Trying to dismiss announcement `$entryId`');

    RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod(
        'server.announcements.list',
        params: {'entry_id': entryId, 'wake_time': wakeTime});

    if (rpcResponse.hasError)
      throw MobilerakerException('Unable to dismiss announcement $entryId');

    String respEntryId = rpcResponse.response['result']['entry_id'];
    return respEntryId;
  }

  _onNotifyAnnouncementUpdate(Map<String, dynamic> rawMessage) {
    List<Map<String, dynamic>> rawEntries = rawMessage['params'];
    List<AnnouncementEntry> entries = _parseAnnouncementsList(rawEntries);
    _announcementsStreamCtrler.add(entries);
  }

  _onNotifyAnnouncementDismissed(Map<String, dynamic> rawMessage) {
    _logger.i('Announcement dismissed event!!!');
    listAnnouncements().then(_announcementsStreamCtrler.add);
  }

  _onNotifyAnnouncementWake(Map<String, dynamic> rawMessage) {
    _logger.i('Announcement wake event!!!');
    listAnnouncements().then(_announcementsStreamCtrler.add);
  }

  List<AnnouncementEntry> _parseAnnouncementsList(
      List<Map<String, dynamic>> entries) {
    return entries.map((e) => AnnouncementEntry.parse(e)).toList();
  }

  dispose() {
    _announcementsStreamCtrler.close();
  }
}
