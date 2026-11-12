/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';
import 'dart:io';

import 'package:common/data/dto/update_manager/update_status.dart';
import 'package:common/data/dto/update_manager/updater_info.dart';
import 'package:common/util/extensions/updater_info_extension.dart';
import 'package:flutter_test/flutter_test.dart';

// The example of https://moonraker.readthedocs.io/en/latest/external_api/update_manager/#get-update-status
const _docsExample = r'''
{
    "busy": false,
    "github_rate_limit": 60,
    "github_requests_remaining": 57,
    "github_limit_reset_time": 1615836932,
    "version_info": {
        "system": {
            "name": "system",
            "configured_type": "system",
            "package_count": 4,
            "package_list": ["libtiff5", "raspberrypi-sys-mods", "rpi-eeprom-images", "rpi-eeprom"]
        },
        "moonraker": {
            "channel": "dev",
            "debug_enabled": true,
            "is_valid": true,
            "configured_type": "git_repo",
            "corrupt": false,
            "info_tags": [],
            "detected_type": "git_repo",
            "name": "moonraker",
            "remote_alias": "arksine",
            "branch": "master",
            "owner": "arksine",
            "repo_name": "moonraker",
            "version": "v0.7.1-364",
            "remote_version": "v0.7.1-364",
            "rollback_version": "v0.7.1-360",
            "current_hash": "ecfad5cff15fff1d82cb9bdc64d6b548ed53dfaf",
            "remote_hash": "ecfad5cff15fff1d82cb9bdc64d6b548ed53dfaf",
            "repo_detected": true,
            "is_dirty": false,
            "detached": true,
            "commits_behind": [],
            "git_messages": [],
            "full_version_string": "v0.7.1-364-gecfad5c",
            "pristine": true,
            "recovery_url": "https://github.com/Arksine/moonraker.git",
            "remote_url": "https://github.com/Arksine/moonraker.git",
            "warnings": [],
            "anomalies": ["Detached HEAD detected"]
        },
        "mainsail": {
            "name": "mainsail",
            "owner": "mainsail-crew",
            "version": "v2.1.1",
            "remote_version": "v2.1.1",
            "rollback_version": "v2.0.0",
            "configured_type": "web",
            "channel": "stable",
            "info_tags": ["desc=Mainsail Web Client", "action=some_action"],
            "warnings": [],
            "anomalies": [],
            "is_valid": true
        },
        "klipper": {
            "channel": "dev",
            "debug_enabled": true,
            "is_valid": true,
            "configured_type": "git_repo",
            "corrupt": false,
            "info_tags": [],
            "detected_type": "git_repo",
            "name": "klipper",
            "remote_alias": "origin",
            "branch": "master",
            "owner": "Klipper3d",
            "repo_name": "klipper",
            "version": "v0.10.0-1",
            "remote_version": "v0.10.0-41",
            "rollback_version": "v0.9.1-340",
            "current_hash": "4c8d24ae03eadf3fc5a28efb1209ce810251d02d",
            "remote_hash": "e3cbe7ea3663a8cd10207a9aecc4e5458aeb1f1f",
            "repo_detected": true,
            "is_dirty": false,
            "detached": false,
            "commits_behind": [
                {
                    "sha": "e3cbe7ea3663a8cd10207a9aecc4e5458aeb1f1f",
                    "author": "Kevin O'Connor",
                    "date": "1644534721",
                    "subject": "stm32: Clear SPE flag on a change to SPI CR1 register",
                    "message": "The stm32 specs indicate that the SPE bit must be cleared.",
                    "tag": null
                },
                {
                    "sha": "99d55185a21703611b862f6ce4b80bba70a9c4b5",
                    "author": "Kevin O'Connor",
                    "date": "1644532075",
                    "subject": "stm32: Wait for transmission to complete before returning from spi_transfer()",
                    "message": "",
                    "tag": "v0.10.0"
                }
            ],
            "commits_behind_count": 40,
            "git_messages": [],
            "full_version_string": "v0.10.0-1-g4c8d24ae-shallow",
            "pristine": true,
            "recovery_url": "https://github.com/Klipper3d/klipper.git",
            "remote_url": "https://github.com/Klipper3d/klipper.git",
            "warnings": [],
            "anomalies": []
        }
    }
}
''';

void main() {
  test('parses the status of the Moonraker docs', () {
    final status = UpdateStatus.fromJson(jsonDecode(_docsExample));

    expect(status.busy, isFalse);
    expect(status.githubRateLimit, 60);
    expect(status.githubRequestsRemaining, 57);
    expect(status.githubLimitResetTime, DateTime.fromMillisecondsSinceEpoch(1615836932 * 1000));
    expect(status.updaters.map((e) => e.name), ['system', 'moonraker', 'mainsail', 'klipper']);

    final system = status.updater('system')!;
    expect(system.configuredType, UpdaterType.system);
    expect(system.packageCount, 4);
    expect(system.packageList, hasLength(4));

    final klipper = status.updater('klipper')!;
    expect(klipper.configuredType, UpdaterType.gitRepo);
    expect(klipper.channel, 'dev');
    expect(klipper.version, 'v0.10.0-1');
    expect(klipper.remoteVersion, 'v0.10.0-41');
    expect(klipper.rollbackVersion, 'v0.9.1-340');
    expect(klipper.owner, 'Klipper3d');
    expect(klipper.commitsBehind, hasLength(2));
    expect(klipper.commitsBehindCount, 40);
    expect(klipper.commitsBehind.first.author, "Kevin O'Connor");
    expect(klipper.commitsBehind.first.date, DateTime.fromMillisecondsSinceEpoch(1644534721 * 1000));
    expect(klipper.commitsBehind.first.tag, isNull);
    expect(klipper.commitsBehind.last.tag, 'v0.10.0');

    final moonraker = status.updater('moonraker')!;
    expect(moonraker.detached, isTrue);
    expect(moonraker.anomalies, ['Detached HEAD detected']);

    final mainsail = status.updater('mainsail')!;
    expect(mainsail.configuredType, UpdaterType.web);
    expect(mainsail.channel, 'stable');
  });

  // machine.update.status of a real machine (Moonraker v0.11), package list and commits shortened.
  test('parses the status of a real machine', () {
    final json = jsonDecode(File('test_resources/marshalling/update_manager_status.json').readAsStringSync());
    final status = UpdateStatus.fromJson(json);

    expect(status.busy, isFalse);
    expect(status.githubRequestsRemaining, 56);
    expect(status.githubLimitResetTime, isNotNull, reason: 'sent as a float');
    expect(status.updaters, hasLength(10));

    final system = status.updater('system')!;
    expect(system.packageCount, 188);
    expect(system.updateAvailable, isTrue);

    final klipper = status.updater('klipper')!;
    expect(klipper.commitsBehindTotal, 50, reason: 'more than Moonraker lists');
    expect(klipper.anomalies.single, startsWith('Repo has untracked source files'));
    expect(klipper.issue, isNull, reason: 'anomalies do not block updates');
    expect(klipper.canUpdate, isTrue);
    expect(klipper.canRollback, isTrue);
    expect(klipper.repoUri, Uri.parse('https://github.com/Klipper3d/klipper'));

    final fluidd = status.updater('fluidd')!;
    expect(fluidd.configuredType, UpdaterType.web);
    expect(fluidd.updateAvailable, isTrue);
    expect(fluidd.issue, isNull, reason: 'an empty last_error is no error');

    expect(status.updater('crowsnest')!.updateAvailable, isFalse);
    expect(status.updater('octoeverywhere')!.commitsBehind.first.tag, '5.4.1');
    expect(status.updateAllPlan.map((e) => e.name), [
      'system',
      'fluidd',
      'octoeverywhere',
      'Klippain-ShakeTune',
      'klipper_tmc_autotune',
      'klipper',
      'moonraker',
    ]);
  });

  test('survives a status without rate limit and with unknown or sparse updaters', () {
    final status = UpdateStatus.fromJson({
      'busy': true,
      'version_info': {
        // Older versions neither report a name nor a type for the system packages.
        'system': {'package_count': 2},
        'fancy': {'configured_type': 'something_new', 'version': '1.0'},
        'broken': 'not an object',
      },
    });

    expect(status.busy, isTrue);
    expect(status.githubRateLimit, isNull);
    expect(status.githubLimitResetTime, isNull);
    expect(status.updaters.map((e) => e.name), ['system', 'fancy']);
    expect(status.updater('system')!.configuredType, UpdaterType.system);
    expect(status.updater('fancy')!.configuredType, UpdaterType.unknown);
    expect(status.updater('fancy')!.isValid, isTrue);
  });

  test('an empty status has no updaters', () {
    expect(UpdateStatus.fromJson(const {}).updaters, isEmpty);
  });
}
