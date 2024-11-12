/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/dto/config/config_file_object_identifiers_enum.dart';

extension MobilerakerString on String {
  /// We use splitting a lot since klipper configs can be identified like that.
  /// To cover all edge cases we want the key to be trimmed and also split via x whitespacess
  /// E.g. 'temperature_sensor sensor_name'
  /// Note that it returns (ObjectIdentifier, ObjectName),
  /// The ObjectIdentifier is always lowercase and
  (ConfigFileObjectIdentifiers?, String?) toKlipperObjectIdentifierNEW() {
    final trimmed = trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    final cIdentifier = ConfigFileObjectIdentifiers.tryParse(parts[0].toLowerCase());

    if (cIdentifier == null) return (null, null);

    if (parts.length == 1) return (cIdentifier, null);

    return (cIdentifier, trimmed.substring(parts[0].length).trim());
  }

  String obfuscate([int nonObfuscated = 4]) {
    if (isEmpty) return this;
    if (kDebugMode) return 'Obfuscated($this)';
    return replaceRange((length >= nonObfuscated * 1.5) ? nonObfuscated : 0, null, '********');
  }

  /// This function calculates the Levenshtein distance between two strings.
  /// The Levenshtein distance is a measure of the difference between two strings,
  /// defined as the minimum number of single-character edits (insertions, deletions, or substitutions) required to change one string into the other.
  int levenshteinDistance(String other) {
    var dp = List.generate(length + 1, (_) => List<int>.filled(other.length + 1, 0), growable: false);

    for (var i = 0; i <= length; i++) dp[i][0] = i;
    for (var j = 0; j <= other.length; j++) dp[0][j] = j;

    for (var i = 1; i <= length; i++) {
      for (var j = 1; j <= other.length; j++) {
        var cost = (this[i - 1] == other[j - 1]) ? 0 : 1;
        dp[i][j] = [dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[length][other.length];
  }

  double jaroWinkler(String other) {
    if (this == other) return 1.0;

    int len1 = length;
    int len2 = other.length;

    int maxDist = (len1 > len2 ? len1 : len2) ~/ 2 - 1;

    List<int> s1Matches = List.filled(len1, 0);
    List<int> s2Matches = List.filled(len2, 0);

    int matches = 0;
    double transpositions = 0;

    for (int i = 0; i < len1; i++) {
      int start = max(0, i - maxDist);
      int end = min(len2, i + maxDist + 1);

      for (int j = start; j < end; j++) {
        if (s2Matches[j] != 0) continue;
        if (this[i] != other[j]) continue;
        s1Matches[i] = 1;
        s2Matches[j] = 1;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (s1Matches[i] == 0) continue;
      while (s2Matches[k] == 0) k++;
      if (this[i] != other[k]) transpositions += 0.5;
      k++;
    }

    double jaro = (matches / len1 + matches / len2 + (matches - transpositions) / matches) / 3;

    const double scalingFactor = 0.1;
    int maxPrefixLength = min(4, min(len1, len2));

    int prefix = 0;
    for (int i = 0; i < maxPrefixLength; i++) {
      if (this[i] == other[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + (prefix * scalingFactor * (1 - jaro));
  }

  double trigramSimilarity(String other) {
    Set<String> trigrams(String s) {
      final trigrams = <String>{};
      for (int i = 0; i < s.length - 2; i++) {
        trigrams.add(s.substring(i, i + 3));
      }
      return trigrams;
    }

    final trigrams1 = trigrams(this);
    final trigrams2 = trigrams(other);

    final intersection = trigrams1.intersection(trigrams2).length;
    final union = trigrams1.union(trigrams2).length;

    return union == 0 ? 0 : intersection / union;
  }

  /// This function calculates a search score for a given search term.
  /// The search score is a measure of how well a string matches a search term.
  ///
  /// The search score is calculated as follows:
  /// - Exact match: 1000
  /// - Full token match: 500
  /// - Prefix match: 200
  /// - Token matching: 150
  /// - Jaro-Winkler similarity: 100
  /// - Trigram similarity for longer search terms: 50
  ///
  /// The search score is a double value between 0 and 1000.
  /// A higher score indicates a better match.
  ///
  /// Note: For now the search is case-insensitive.
  double searchScore(String searchTerm, Iterable<String> searchTokens) {
    searchTerm = searchTerm.toLowerCase();
    // We dont want duplicates
    searchTokens = searchTokens.map((token) => token.toLowerCase()).toSet();
    final normalized = toLowerCase();
    // Exact match
    if (normalized == searchTerm) return 1000; // Highest possible score

    double score = 0;

    // Full token match
    if (searchTokens.length > 1 && searchTokens.every((token) => normalized.contains(token))) {
      score += 500; // High score, but less than exact match
    }

    // Prefix match
    if (normalized.startsWith(searchTerm)) score += 200;

    // Token matching
    var fileTokens = normalized.split(RegExp(r'[(),.\s_-]+'));
    for (var searchToken in searchTokens) {
      if (fileTokens.any((fileToken) => fileToken == searchToken)) score += 150;
      if (fileTokens.any((fileToken) => fileToken.startsWith(searchToken))) score += 130;
      if (fileTokens.any((fileToken) => fileToken.endsWith(searchToken))) score += 110;
    }

    // Jaro-Winkler similarity
    score += normalized.jaroWinkler(searchTerm) * 100;

    // Trigram similarity for longer search terms
    if (searchTerm.length > 3) {
      score += normalized.trigramSimilarity(searchTerm) * 50;
    }

    return score;
  }
}
