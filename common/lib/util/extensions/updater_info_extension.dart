/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import '../../data/dto/update_manager/update_status.dart';
import '../../data/dto/update_manager/updater_info.dart';

/// Why an updater needs the user's attention, most severe first.
enum UpdaterIssue {
  /// The local repo is broken, only a hard recover helps.
  corrupt,

  /// Files of the repo were modified, a soft recover resets them.
  dirty,

  /// Moonraker refuses to update it, see [UpdaterInfo.warnings].
  invalid,

  /// The last update or check failed, see [UpdaterInfo.lastError].
  error,
}

extension UpdaterInfoExtension on UpdaterInfo {
  bool get isSystem => configuredType == UpdaterType.system;

  bool get isGitRepo => configuredType == UpdaterType.gitRepo;

  /// The amount of commits a git repo is behind. Moonraker only lists some of them in [UpdaterInfo.commitsBehind].
  int get commitsBehindTotal => max(commitsBehindCount, commitsBehind.length);

  /// Whether a newer version is available.
  bool get updateAvailable {
    switch (configuredType) {
      case UpdaterType.system:
        return packageCount > 0;
      case UpdaterType.gitRepo:
        if (_known(currentHash) && _known(remoteHash)) return currentHash != remoteHash;
        return commitsBehindTotal > 0;
      default:
        // `update-available` is the placeholder of python packages whose remote does not provide a hash.
        if (remoteHash == 'update-available') return true;
        return _known(version) && _known(remoteVersion) && version != remoteVersion;
    }
  }

  /// The reason why this updater needs attention, null if it is fine.
  UpdaterIssue? get issue {
    if (isSystem) return null;
    if (corrupt) return UpdaterIssue.corrupt;
    if (isDirty) return UpdaterIssue.dirty;
    if (!isValid || warnings.isNotEmpty) return UpdaterIssue.invalid;
    if (lastError.isNotEmpty) return UpdaterIssue.error;
    return null;
  }

  /// Whether Moonraker accepts an update of it: it refuses invalid (which includes dirty) and corrupt ones.
  bool get canUpdate => updateAvailable && (isSystem || (isValid && !corrupt));

  /// Only git repos can be recovered.
  bool get canRecover => isGitRepo;

  /// Whether there is a version prior to the last update to go back to.
  bool get canRollback => !isSystem && _known(rollbackVersion) && rollbackVersion != version;

  /// The URL of the GitHub repo, if Moonraker detected it.
  Uri? get repoUri {
    if (!_known(owner ?? '') || !_known(repoName ?? '')) return null;
    return Uri.https('github.com', '/$owner/$repoName');
  }

  /// The commit hash as shown by git, e.g. `4c8d24a`.
  static String shortHash(String hash) => hash.length > 7 ? hash.substring(0, 7) : hash;
}

extension UpdateStatusExtension on UpdateStatus {
  UpdaterInfo? updater(String name) {
    for (final it in updaters) {
      if (it.name == name) return it;
    }
    return null;
  }

  /// The updaters in the order they are shown: Klipper and Moonraker, the other software by name, the system
  /// packages last.
  List<UpdaterInfo> get sortedUpdaters => updaters.toList()
    ..sort((a, b) {
      final byRank = _rank(a).compareTo(_rank(b));
      return byRank != 0 ? byRank : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  /// What `Update all` updates, in the order Moonraker updates it: the system packages, the other software, Klipper
  /// and Moonraker last.
  List<UpdaterInfo> get updateAllPlan {
    int order(UpdaterInfo it) => switch (it.name) {
      _ when it.isSystem => 0,
      'klipper' => 2,
      'moonraker' => 3,
      _ => 1,
    };

    // The sort is stable, the other software keeps Moonraker's order.
    final plan = updaters.where((it) => it.canUpdate).indexed.toList()
      ..sort((a, b) {
        final byOrder = order(a.$2).compareTo(order(b.$2));
        return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
      });
    return [for (final (_, it) in plan) it];
  }

  static int _rank(UpdaterInfo it) => switch (it.name) {
    'klipper' => 0,
    'moonraker' => 1,
    _ when it.isSystem => 3,
    _ => 2,
  };
}

/// Moonraker reports `?` for values it could not detect.
bool _known(String value) => value.isNotEmpty && value != '?';
