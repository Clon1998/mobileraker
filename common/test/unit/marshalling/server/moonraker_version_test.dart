/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/moonraker_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoonrakerVersion.fromString()', () {
    test('parses the standard git-describe format (dash-separated)', () {
      final version = MoonrakerVersion.fromString('v0.8.0-456-g1234567');

      expect(version.major, 0);
      expect(version.minor, 8);
      expect(version.patch, 0);
      expect(version.commits, 456);
      expect(version.commitHash, 'g1234567');
      expect(version.isFallback, isFalse);
    });

    test('parses a plain dot-separated semver (e.g. U1 derivatives)', () {
      final version = MoonrakerVersion.fromString('1.5.2');

      expect(version.major, 1);
      expect(version.minor, 5);
      expect(version.patch, 2);
      expect(version.commits, 0);
      expect(version.commitHash, '');
      expect(version.isFallback, isFalse);
    });

    test('parses a plain dot-separated semver with a "v" prefix', () {
      final version = MoonrakerVersion.fromString('v1.5.2');

      expect(version.major, 1);
      expect(version.minor, 5);
      expect(version.patch, 2);
      expect(version.commits, 0);
      expect(version.commitHash, '');
    });

    test('returns fallback for an empty string', () {
      final version = MoonrakerVersion.fromString('');

      expect(version.isFallback, isTrue);
    });

    test('returns fallback for a malformed dot-separated version', () {
      final version = MoonrakerVersion.fromString('1.5');

      expect(version.isFallback, isTrue);
    });

    test('returns fallback for a non-numeric dot-separated version', () {
      final version = MoonrakerVersion.fromString('a.b.c');

      expect(version.isFallback, isTrue);
    });
  });
}
