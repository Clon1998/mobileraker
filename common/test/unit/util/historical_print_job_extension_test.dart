/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/history/history_totals.dart';
import 'package:common/util/extensions/historical_print_job_extension.dart';
import 'package:flutter_test/flutter_test.dart';

HistoricalPrintJob _job({
  String id = '1',
  String filename = 'cube.gcode',
  String status = 'completed',
  double start = 1762761600, // 2025-11-10T08:00:00Z
  double? end = 1762765200,
  bool exists = true,
  Map<String, dynamic>? metadata,
}) => HistoricalPrintJob.fromJson({
  'job_id': id,
  'user': '_TRUSTED_USER_',
  'filename': filename,
  'status': status,
  'start_time': start,
  'end_time': end,
  'print_duration': 100.0,
  'total_duration': 120.0,
  'filament_used': 1000.0,
  'metadata': metadata ?? {'size': 1, 'modified': 1.0, 'filament_type': 'PLA'},
  'auxiliary_data': [],
  'exists': exists,
});

void main() {
  group('HistoricalPrintJob parsing', () {
    test('a job in progress has no end time', () {
      final job = _job(status: 'in_progress', end: null);
      expect(job.endTime, isNull);
      expect(job.outcome, JobOutcome.inProgress);
    });

    test('a job without metadata is parsed', () {
      final job = _job(filename: 'sub/folder/cube.gcode', metadata: {});
      expect(job.metadata.name, 'cube.gcode');
      expect(job.metadata.parentPath, 'gcodes/sub/folder');
      expect(job.metadata.pathForPrint, 'sub/folder/cube.gcode');
      expect(job.materials, isNull);
    });
  });

  group('outcome', () {
    test('maps the moonraker status', () {
      expect(_job(status: 'completed').outcome, JobOutcome.completed);
      expect(_job(status: 'cancelled').outcome, JobOutcome.cancelled);
      expect(_job(status: 'klippy_shutdown').outcome, JobOutcome.failed);
      expect(_job(status: 'error').outcome, JobOutcome.failed);
      expect(_job(status: 'something_new').outcome, JobOutcome.failed);
    });
  });

  group('displayName', () {
    test('strips folders and the gcode extension', () {
      expect(_job(filename: 'folder/Voron_cube_PLA.gcode').displayName, 'Voron_cube_PLA');
      expect(_job(filename: 'benchy_0.2mm.GCODE').displayName, 'benchy_0.2mm');
      expect(_job(filename: 'benchy_0.2mm').displayName, 'benchy_0.2mm');
    });
  });

  group('materials', () {
    HistoricalPrintJob withType(Object? type) =>
        _job(metadata: {'size': 1, 'modified': 1.0, 'filament_type': type});

    test('single material', () => expect(withType('PLA').materials, 'PLA'));

    test('semicolon separated materials are unique', () => expect(withType('PLA;PETG;PLA').materials, 'PLA, PETG'));

    test('materials reported as stringified list', () {
      expect(withType('["PLA", "PLA"]').materials, 'PLA');
      expect(withType('["PETG", "PLA"]').materials, 'PETG, PLA');
    });

    test('materials reported as an actual list', () {
      expect(withType(['PLA', 'PLA']).materials, 'PLA');
      expect(withType(['PETG', 'PLA']).materials, 'PETG, PLA');
      expect(withType(['PETG', 'PLA']).metadata.filamentTypes, ['PETG', 'PLA']);
    });

    test('the parsed types keep one entry per filament', () {
      expect(withType('PLA').metadata.filamentTypes, ['PLA']);
      expect(withType('PLA;PETG;PLA').metadata.filamentTypes, ['PLA', 'PETG', 'PLA']);
      expect(withType('["PLA", "PLA"]').metadata.filamentTypes, ['PLA', 'PLA']);
      expect(withType('[broken').metadata.filamentTypes, ['[broken']);
    });

    test('no material', () {
      expect(withType(null).materials, isNull);
      expect(withType('').materials, isNull);
    });
  });

  group('recentDistinct', () {
    test('skips deleted files and duplicates and respects max', () {
      final jobs = [
        _job(id: '5', filename: 'a.gcode'),
        _job(id: '4', filename: 'deleted.gcode', exists: false),
        _job(id: '3', filename: 'a.gcode'),
        _job(id: '2', filename: 'b.gcode'),
        _job(id: '1', filename: 'c.gcode'),
      ];
      expect(jobs.recentDistinct(max: 2).map((j) => j.jobId), ['5', '2']);
      expect(jobs.recentDistinct(max: 5).map((j) => j.jobId), ['5', '2', '1']);
      expect(jobs.recentDistinct(max: 0), isEmpty);
    });
  });

  group('groupedByDay', () {
    test('groups by the local day the job started on', () {
      final day1 = DateTime(2025, 11, 10, 8).millisecondsSinceEpoch / 1000;
      final day1Late = DateTime(2025, 11, 10, 23, 59).millisecondsSinceEpoch / 1000;
      final day0 = DateTime(2025, 11, 9, 23, 59).millisecondsSinceEpoch / 1000;
      final groups = [
        _job(id: '3', start: day1Late),
        _job(id: '2', start: day1),
        _job(id: '1', start: day0),
      ].groupedByDay();

      expect(groups.map((g) => g.$1), [DateTime(2025, 11, 10), DateTime(2025, 11, 9)]);
      expect(groups.map((g) => g.$2.map((j) => j.jobId).toList()), [
        ['3', '2'],
        ['1'],
      ]);
    });
  });

  group('groupedByFile', () {
    test('folds the attempts of a file into its most recent job', () {
      final groups = [
        _job(id: '4', filename: 'a.gcode', start: 400),
        _job(id: '3', filename: 'b.gcode', start: 300),
        _job(id: '2', filename: 'a.gcode', start: 200),
        _job(id: '1', filename: 'a.gcode', start: 100),
      ].reversed.groupedByFile();

      expect(groups.map((g) => g.$1.jobId), ['4', '3']);
      expect(groups.first.$2.map((j) => j.jobId), ['2', '1']);
      expect(groups.last.$2, isEmpty);
    });
  });

  group('successPercent', () {
    test('ignores jobs in progress', () {
      final jobs = [
        _job(status: 'in_progress', end: null),
        _job(status: 'completed'),
        _job(status: 'cancelled'),
        _job(status: 'klippy_shutdown'),
      ];
      expect(jobs.successPercent, 33);
      expect([_job(status: 'in_progress', end: null)].successPercent, isNull);
      expect(<HistoricalPrintJob>[].successPercent, isNull);
    });
  });

  group('HistoryTotals', () {
    test('parses moonrakers job_totals', () {
      final totals = HistoryTotals.fromJson({
        'total_jobs': 279.0,
        'total_time': 362144.6,
        'total_print_time': 311178.4,
        'total_filament_used': 528074.5,
        'longest_job': 10952.2,
        'longest_print': 10839.1,
      });
      expect(totals.totalJobs, 279);
      expect(totals.totalPrintTime, 311178.4);
      expect(totals.totalFilamentUsed, 528074.5);
      expect(HistoryTotals.fromJson({}).totalJobs, 0);
    });
  });
}
