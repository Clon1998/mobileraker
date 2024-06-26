/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'moonraker_version.freezed.dart';

@freezed
class MoonrakerVersion with _$MoonrakerVersion {
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
    // Split the version string by '-' to separate version, commits, and commitHash
    final parts = versionString.split('-');

    // Check if there are at least three parts (major.minor.patch required)
    if (parts.length < 3) {
      return MoonrakerVersion.fallback();
    }

    // Parse the version part (e.g., "v0.8.0")
    final versionPart = parts[0].substring(1); // Remove the 'v' prefix
    final versionNumbers = versionPart.split('.');
    if (versionNumbers.length != 3) {
      return MoonrakerVersion.fallback();
    }

    final major = int.tryParse(versionNumbers[0]) ?? 0;
    final minor = int.tryParse(versionNumbers[1]) ?? 0;
    final patch = int.tryParse(versionNumbers[2]) ?? 0;

    // Parse the commits and commitHash parts
    int commits = 0;
    String commitHash = '';

    commits = int.tryParse(parts[1]) ?? 0; // Use 0 if not present or invalid
    if (parts.length > 2) {
      commitHash = parts[2];
    }

    return MoonrakerVersion(
      major: major,
      minor: minor,
      patch: patch,
      commits: commits,
      commitHash: commitHash,
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
