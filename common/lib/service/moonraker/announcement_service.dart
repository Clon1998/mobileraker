/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/logger.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/announcement/announcement_entry.dart';
import '../../network/jrpc_client_provider.dart';

part 'announcement_service.g.dart';

@riverpod
AnnouncementService announcementService(AnnouncementServiceRef ref, String machineUUID) {
  return AnnouncementService(ref, machineUUID);
}

@riverpod
Stream<List<AnnouncementEntry>> announcement(AnnouncementRef ref, String machineUUID) {
  return ref.watch(announcementServiceProvider(machineUUID)).announcementNotificationStream;
}

/// The AnnouncementService handles different notifications/announcements from feed api.
/// For more information check out
/// 1. https://moonraker.readthedocs.io/en/latest/web_api/#announcement-apis
class AnnouncementService {
  AnnouncementService(AutoDisposeRef ref, String machineUUID)
      : _jRpcClient = ref.watch(jrpcClientProvider(machineUUID)) {
    ref.onDispose(dispose);
    _jRpcClient.addMethodListener(_onNotifyAnnouncementUpdate, 'notify_announcement_update');
    _jRpcClient.addMethodListener(_onNotifyAnnouncementDismissed, 'notify_announcement_dismissed');
    _jRpcClient.addMethodListener(_onNotifyAnnouncementWake, 'notify_announcement_wake');
  }

  final StreamController<List<AnnouncementEntry>> _announcementsStreamCtrler = StreamController();

  Stream<List<AnnouncementEntry>> get announcementNotificationStream =>
      _announcementsStreamCtrler.stream;

  final JsonRpcClient _jRpcClient;

  Future<List<AnnouncementEntry>> listAnnouncements([bool includeDismissed = false]) async {
    logger.i('List Announcements request...');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.announcements.list',
          params: {'include_dismissed': includeDismissed});

      List<Map<String, dynamic>> entries = rpcResponse.result['entries'];

      return _parseAnnouncementsList(entries);
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to fetch announcement list: $e');
    }
  }

  Future<String> dismissAnnouncement(String entryId, [int? wakeTime]) async {
    logger.i('Trying to dismiss announcement `$entryId`');

    try {
      RpcResponse rpcResponse = await _jRpcClient.sendJRpcMethod('server.announcements.list',
          params: {'entry_id': entryId, 'wake_time': wakeTime});

      String respEntryId = rpcResponse.result['entry_id'];
      return respEntryId;
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to dismiss announcement $entryId. Err: $e');
    }
  }

  _onNotifyAnnouncementUpdate(Map<String, dynamic> rawMessage) {
    List<Map<String, dynamic>> rawEntries = rawMessage['params'];
    List<AnnouncementEntry> entries = _parseAnnouncementsList(rawEntries);
    _announcementsStreamCtrler.add(entries);
  }

  _onNotifyAnnouncementDismissed(Map<String, dynamic> rawMessage) {
    logger.i('Announcement dismissed event!!!');
    listAnnouncements().then(_announcementsStreamCtrler.add);
  }

  _onNotifyAnnouncementWake(Map<String, dynamic> rawMessage) {
    logger.i('Announcement wake event!!!');
    listAnnouncements().then(_announcementsStreamCtrler.add);
  }

  List<AnnouncementEntry> _parseAnnouncementsList(List<Map<String, dynamic>> entries) {
    return entries.map((e) => AnnouncementEntry.parse(e)).toList();
  }

  dispose() {
    _jRpcClient.removeMethodListener(_onNotifyAnnouncementUpdate, 'notify_announcement_update');
    _jRpcClient.removeMethodListener(_onNotifyAnnouncementDismissed, 'notify_announcement_dismissed');
    _jRpcClient.removeMethodListener(_onNotifyAnnouncementWake, 'notify_announcement_wake');

    _announcementsStreamCtrler.close();
  }
}
