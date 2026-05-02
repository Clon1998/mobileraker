/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/announcement/announcement_entry.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'announcement_service.g.dart';

@riverpod
class Announcement extends _$Announcement {
  JsonRpcClient get _jrpcClient => ref.read(jrpcClientProvider(machineUUID));

  @override
  Future<List<AnnouncementEntry>> build(String machineUUID) async {
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_announcement_update'), (_, next) {
      if (!next.hasValue) return;
      final raw = List<Map<String, dynamic>>.from(next.value!['params'] as List);
      state = AsyncData(_parseList(raw));
    });
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_announcement_dismissed'), (_, next) {
      if (next.isLoading || next.hasError) return;
      ref.invalidateSelf();
    });
    ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_announcement_wake'), (_, next) {
      if (next.isLoading || next.hasError) return;
      ref.invalidateSelf();
    });

    return _fetchList();
  }

  Future<List<AnnouncementEntry>> _fetchList([bool includeDismissed = false]) async {
    talker.info('[AnnouncementNotifier($machineUUID)] Fetching announcements...');
    try {
      final resp = await _jrpcClient.sendJRpcMethod(
        'server.announcements.list',
        params: {'include_dismissed': includeDismissed},
      );
      return _parseList(List<Map<String, dynamic>>.from(resp.result['entries'] as List));
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to fetch announcement list: $e');
    }
  }

  Future<String> dismissAnnouncement(String entryId, [int? wakeTime]) async {
    talker.info('[AnnouncementNotifier($machineUUID)] Dismissing announcement $entryId...');
    try {
      final resp = await _jrpcClient.sendJRpcMethod(
        'server.announcements.dismiss',
        params: {
          'entry_id': entryId,
          if (wakeTime != null) 'wake_time': wakeTime,
        },
      );
      return resp.result['entry_id'] as String;
    } on JRpcError catch (e) {
      throw MobilerakerException('Unable to dismiss announcement $entryId. Err: $e');
    }
  }

  List<AnnouncementEntry> _parseList(List<Map<String, dynamic>> entries) =>
      entries.map((e) => AnnouncementEntry.parse(e)).toList();
}
