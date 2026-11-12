/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/update_manager/update_commit.dart';
import 'package:common/data/dto/update_manager/update_status.dart';
import 'package:common/data/dto/update_manager/updater_info.dart';
import 'package:common/util/extensions/updater_info_extension.dart';
import 'package:flutter_test/flutter_test.dart';

UpdaterInfo _git({
  String name = 'klipper',
  String currentHash = 'aaaaaaaaaa',
  String remoteHash = 'bbbbbbbbbb',
  bool isValid = true,
  bool isDirty = false,
  bool corrupt = false,
  List<String> warnings = const [],
  String rollbackVersion = '',
  int commitsBehindCount = 0,
  List<UpdateCommit> commitsBehind = const [],
}) => UpdaterInfo(
  name: name,
  configuredType: UpdaterType.gitRepo,
  version: 'v1',
  remoteVersion: 'v2',
  currentHash: currentHash,
  remoteHash: remoteHash,
  isValid: isValid,
  isDirty: isDirty,
  corrupt: corrupt,
  warnings: warnings,
  rollbackVersion: rollbackVersion,
  commitsBehindCount: commitsBehindCount,
  commitsBehind: commitsBehind,
);

UpdaterInfo _web({String name = 'mainsail', String version = 'v2.1.1', String remoteVersion = 'v2.1.1'}) =>
    UpdaterInfo(name: name, configuredType: UpdaterType.web, version: version, remoteVersion: remoteVersion);

const _system = UpdaterInfo(name: 'system', configuredType: UpdaterType.system, packageCount: 3);

void main() {
  group('updateAvailable', () {
    test('git repo: by hash, by commits if a hash is unknown', () {
      expect(_git().updateAvailable, isTrue);
      expect(_git(remoteHash: 'aaaaaaaaaa').updateAvailable, isFalse);
      expect(_git(currentHash: '?', remoteHash: '?').updateAvailable, isFalse);
      expect(_git(currentHash: '', remoteHash: '', commitsBehindCount: 2).updateAvailable, isTrue);
    });

    test('web: by version, an undetected version is no update', () {
      expect(_web().updateAvailable, isFalse);
      expect(_web(remoteVersion: 'v2.2.0').updateAvailable, isTrue);
      expect(_web(remoteVersion: '?').updateAvailable, isFalse);
      expect(_web(version: '?', remoteVersion: 'v2.2.0').updateAvailable, isFalse);
    });

    test('python: the remote hash placeholder counts', () {
      const python = UpdaterInfo(
        name: 'katapult',
        configuredType: UpdaterType.python,
        version: '1.0',
        remoteVersion: '1.0',
        currentHash: 'not-specified',
        remoteHash: 'update-available',
      );
      expect(python.updateAvailable, isTrue);
      expect(python.copyWith(remoteHash: 'not-specified').updateAvailable, isFalse);
    });

    test('system: by package count', () {
      expect(_system.updateAvailable, isTrue);
      expect(_system.copyWith(packageCount: 0).updateAvailable, isFalse);
    });
  });

  group('issue', () {
    test('most severe first', () {
      expect(_git().issue, isNull);
      expect(_git(corrupt: true, isDirty: true, isValid: false).issue, UpdaterIssue.corrupt);
      expect(_git(isDirty: true, isValid: false, warnings: ['Repo is dirty']).issue, UpdaterIssue.dirty);
      expect(_git(isValid: false).issue, UpdaterIssue.invalid);
      expect(_git(warnings: ['Unofficial remote']).issue, UpdaterIssue.invalid);
      expect(_web().copyWith(lastError: 'Download failed').issue, UpdaterIssue.error);
      expect(_system.issue, isNull);
    });

    test('an invalid updater can not be updated, but still has an update', () {
      final dirty = _git(isDirty: true, isValid: false);
      expect(dirty.updateAvailable, isTrue);
      expect(dirty.canUpdate, isFalse);
      expect(_git().canUpdate, isTrue);
      expect(_system.canUpdate, isTrue);
    });
  });

  test('canRecover is for git repos only', () {
    expect(_git().canRecover, isTrue);
    expect(_web().canRecover, isFalse);
    expect(_system.canRecover, isFalse);
  });

  test('canRollback needs a version other than the installed one', () {
    expect(_git().canRollback, isFalse);
    expect(_git(rollbackVersion: '?').canRollback, isFalse);
    expect(_git(rollbackVersion: 'v1').canRollback, isFalse);
    expect(_git(rollbackVersion: 'v0').canRollback, isTrue);
  });

  test('commitsBehindTotal prefers the count Moonraker reports', () {
    const commits = [UpdateCommit(sha: 'a'), UpdateCommit(sha: 'b')];
    expect(_git(commitsBehind: commits).commitsBehindTotal, 2);
    expect(_git(commitsBehind: commits, commitsBehindCount: 40).commitsBehindTotal, 40);
  });

  test('repoUri needs a detected owner and repo', () {
    expect(_git().repoUri, isNull);
    expect(_git().copyWith(owner: '?', repoName: '?').repoUri, isNull);
    expect(
      _git().copyWith(owner: 'Klipper3d', repoName: 'klipper').repoUri,
      Uri.parse('https://github.com/Klipper3d/klipper'),
    );
  });

  test('shortHash', () {
    expect(UpdaterInfoExtension.shortHash('4c8d24ae03eadf3fc5a28efb1209ce810251d02d'), '4c8d24a');
    expect(UpdaterInfoExtension.shortHash('abc'), 'abc');
  });

  group('UpdateStatus', () {
    final status = UpdateStatus(
      updaters: [
        _system,
        _git(name: 'moonraker'),
        _web(name: 'mainsail', remoteVersion: 'v2.2.0'),
        _web(name: 'fluidd'),
        _git(name: 'crowsnest', isDirty: true, isValid: false),
        _git(name: 'klipper'),
      ],
    );

    test('sortedUpdaters: Klipper, Moonraker, the rest by name, system last', () {
      expect(status.sortedUpdaters.map((e) => e.name), [
        'klipper',
        'moonraker',
        'crowsnest',
        'fluidd',
        'mainsail',
        'system',
      ]);
    });

    test('updateAllPlan: what can be updated, in the order of Moonraker', () {
      expect(status.updateAllPlan.map((e) => e.name), ['system', 'mainsail', 'klipper', 'moonraker']);
    });

    test('updater looks up by name', () {
      expect(status.updater('fluidd')?.name, 'fluidd');
      expect(status.updater('nope'), isNull);
    });
  });
}
