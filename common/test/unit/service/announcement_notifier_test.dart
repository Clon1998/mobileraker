/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:convert';

import 'package:common/data/dto/announcement/announcement_entry.dart';
import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/announcement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../test_utils.dart';
import 'announcement_notifier_test.mocks.dart';

@GenerateMocks([JsonRpcClient])
void main() {
  setUpAll(() {
    setupTestLogger();
    provideDummy<RpcResponse>(RpcResponse.fromJson(jsonDecode('{"jsonrpc":"2.0","id":1,"result":{}}')));
  });

  const uuid = 'test-machine';

  // Keys match what AnnouncementEntry.parse actually reads (camelCase entryId,
  // AnnouncementPriority enum for priority — the parser does a direct assignment).
  Map<String, dynamic> announcementJson({String id = 'entry-1', String title = 'Test'}) => {
        'entryId': id,
        'url': 'https://example.com',
        'title': title,
        'description': 'A test announcement',
        'priority': AnnouncementPriority.normal,
        'date': 1700000000,
        'dismissed': false,
        'source': 'moonraker',
        'feed': 'moonraker',
      };

  // Build RpcResponse directly to avoid jsonEncode issues with enum values.
  RpcResponse listResponse(List<Map<String, dynamic>> entries) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {'entries': entries});

  RpcResponse dismissResponse(String entryId) =>
      RpcResponse(jsonrpc: '2.0', id: 1, result: {'entry_id': entryId});

  ProviderContainer makeContainer(
    MockJsonRpcClient mockRpc, {
    StreamController<Map<String, dynamic>>? updateCtrl,
    StreamController<Map<String, dynamic>>? dismissedCtrl,
    StreamController<Map<String, dynamic>>? wakeCtrl,
  }) {
    final container = ProviderContainer.test(overrides: [
      jrpcClientProvider(uuid).overrideWithValue(mockRpc),
      jrpcMethodEventProvider(uuid, 'notify_announcement_update')
          .overrideWith((ref) => (updateCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
      jrpcMethodEventProvider(uuid, 'notify_announcement_dismissed')
          .overrideWith((ref) => (dismissedCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
      jrpcMethodEventProvider(uuid, 'notify_announcement_wake')
          .overrideWith((ref) => (wakeCtrl ?? StreamController<Map<String, dynamic>>.broadcast()).stream),
    ]);
    return container;
  }

  test('initial build fetches announcements via JRPC', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([announcementJson()]));

    final container = makeContainer(mockRpc);
    final entries = await container.read(announcementProvider(uuid).future);

    expect(entries, hasLength(1));
    expect(entries.first.entryId, 'entry-1');
    expect(entries.first.title, 'Test');
  });

  test('initial build returns empty list when no announcements', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([]));

    final container = makeContainer(mockRpc);
    final entries = await container.read(announcementProvider(uuid).future);

    expect(entries, isEmpty);
  });

  test('notify_announcement_update sets state directly without re-fetching', () async {
    final mockRpc = MockJsonRpcClient();
    final updateCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(updateCtrl.close);

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([]));

    final container = makeContainer(mockRpc, updateCtrl: updateCtrl);
    // Keep alive so auto-dispose doesn't remove the provider between reads
    final sub = container.listen(announcementProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(announcementProvider(uuid).future);

    // Simulate a push notification with a new entry
    updateCtrl.add({
      'params': [announcementJson(id: 'entry-2', title: 'Push Update')],
    });
    await pumpEventQueue();

    final updated = container.read(announcementProvider(uuid)).value;
    expect(updated, hasLength(1));
    expect(updated!.first.entryId, 'entry-2');
    expect(updated.first.title, 'Push Update');

    // Verify JRPC fetch was only called once during build, not for the push
    verify(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false})).called(1);
  });

  test('notify_announcement_dismissed triggers a re-fetch', () async {
    final mockRpc = MockJsonRpcClient();
    final dismissedCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(dismissedCtrl.close);

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([announcementJson()]));

    final container = makeContainer(mockRpc, dismissedCtrl: dismissedCtrl);
    final sub = container.listen(announcementProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(announcementProvider(uuid).future);

    dismissedCtrl.add({'params': []});
    await pumpEventQueue();
    // Await the rebuild triggered by invalidateSelf
    await container.read(announcementProvider(uuid).future);

    verify(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false})).called(2);
  });

  test('notify_announcement_wake triggers a re-fetch', () async {
    final mockRpc = MockJsonRpcClient();
    final wakeCtrl = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(wakeCtrl.close);

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([]));

    final container = makeContainer(mockRpc, wakeCtrl: wakeCtrl);
    final sub = container.listen(announcementProvider(uuid), (_, __) {});
    addTearDown(sub.close);

    await container.read(announcementProvider(uuid).future);

    wakeCtrl.add({'params': []});
    await pumpEventQueue();
    await container.read(announcementProvider(uuid).future);

    verify(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false})).called(2);
  });

  test('dismissAnnouncement sends correct JRPC call and returns entry_id', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([]));
    when(mockRpc.sendJRpcMethod('server.announcements.dismiss', params: {'entry_id': 'entry-1'}))
        .thenAnswer((_) async => dismissResponse('entry-1'));

    final container = makeContainer(mockRpc);
    await container.read(announcementProvider(uuid).future);

    final result = await container.read(announcementProvider(uuid).notifier).dismissAnnouncement('entry-1');

    expect(result, 'entry-1');
    verify(mockRpc.sendJRpcMethod('server.announcements.dismiss', params: {'entry_id': 'entry-1'})).called(1);
  });

  test('dismissAnnouncement includes wake_time when provided', () async {
    final mockRpc = MockJsonRpcClient();

    when(mockRpc.sendJRpcMethod('server.announcements.list', params: {'include_dismissed': false}))
        .thenAnswer((_) async => listResponse([]));
    when(mockRpc.sendJRpcMethod('server.announcements.dismiss',
            params: {'entry_id': 'entry-1', 'wake_time': 3600}))
        .thenAnswer((_) async => dismissResponse('entry-1'));

    final container = makeContainer(mockRpc);
    await container.read(announcementProvider(uuid).future);

    final result =
        await container.read(announcementProvider(uuid).notifier).dismissAnnouncement('entry-1', 3600);

    expect(result, 'entry-1');
    verify(mockRpc.sendJRpcMethod('server.announcements.dismiss',
            params: {'entry_id': 'entry-1', 'wake_time': 3600}))
        .called(1);
  });
}
