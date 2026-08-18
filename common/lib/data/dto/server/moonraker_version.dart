/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'moonraker_version.freezed.dart';

@freezed
sealed class MoonrakerVersion with _$MoonrakerVersion {
  const MoonrakerVersion._();

  const factory MoonrakerVersion({
    required int major,
    required int minor,
    required int patch,
    required int commits,
    required String commitHash,
  }) = _MoonrakerVersion;

  factory MoonrakerVersion.fallback() =>
      const _MoonrakerVersion(major: 0, minor: 0, patch: 0, commits: 0, commitHash: '');

  factory MoonrakerVersion.fromString(String versionString) {
    // Standard moonraker/git-describe format, e.g. "v0.8.0-456-g1234567"
    final parts = versionString.split('-');
    if (parts.length >= 3) {
      // Parse the version part (e.g., "v0.8.0")
      final versionPart = parts[0].substring(1); // Remove the 'v' prefix
      final versionNumbers = versionPart.split('.');
      if (versionNumbers.length != 3) {
        return MoonrakerVersion.fallback();
      }

      final major = int.tryParse(versionNumbers[0]) ?? 0;
      final minor = int.tryParse(versionNumbers[1]) ?? 0;
      final patch = int.tryParse(versionNumbers[2]) ?? 0;

      final commits = int.tryParse(parts[1]) ?? 0; // Use 0 if not present or invalid
      final commitHash = parts[2];

      return MoonrakerVersion(
        major: major,
        minor: minor,
        patch: patch,
        commits: commits,
        commitHash: commitHash,
      );
    }

    // Some moonraker derivatives/forks (e.g. on U1 based boards) report a plain,
    // dot-separated semver instead, e.g. "1.5.2" (optionally prefixed with 'v').
    final plainVersion = versionString.startsWith('v') ? versionString.substring(1) : versionString;
    final versionNumbers = plainVersion.split('.');
    if (versionNumbers.length != 3) {
      return MoonrakerVersion.fallback();
    }

    final major = int.tryParse(versionNumbers[0]);
    final minor = int.tryParse(versionNumbers[1]);
    final patch = int.tryParse(versionNumbers[2]);
    if (major == null || minor == null || patch == null) {
      return MoonrakerVersion.fallback();
    }

    return MoonrakerVersion(
      major: major,
      minor: minor,
      patch: patch,
      commits: 0,
      commitHash: '',
    );
  }

  bool get isFallback => major == 0 && minor == 0 && patch == 0 && commits == 0 && commitHash.isEmpty;

  String toVersionString() {
    return 'v$major.$minor.$patch-$commits-$commitHash';
  }

  // Compare two MoonrakerVersion objects based on major, minor, and patch.
  int compareTo(int major, int minor, int patch, int commits) {
    if (this.major != major) {
      return this.major.compareTo(major);
    } else if (this.minor != minor) {
      return this.minor.compareTo(minor);
    } else if (this.patch != patch) {
      return this.patch.compareTo(patch);
    } else {
      return this.commits.compareTo(commits);
    }
  }
}
