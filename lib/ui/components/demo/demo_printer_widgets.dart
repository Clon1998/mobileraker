/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math' as math;

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/service/demo/demo_printer.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';

/// Adds the demo printer and selects it. Selects it if it already exists.
Future<void> addDemoPrinter(WidgetRef ref) async {
  final machineService = ref.read(machineServiceProvider);
  final existing = await machineService.fetchMachine(demoMachineUuid);
  if (existing != null) {
    await ref.read(selectedMachineServiceProvider).selectMachine(existing);
    return;
  }
  talker.info('Adding the demo printer');
  await machineService.addMachine(
    demoMachine(tr('components.demo_printer.name')),
  );
}

/// Tells that the selected printer is the simulated demo printer, and how to leave it.
class DemoPrinterBanner extends ConsumerWidget {
  const DemoPrinterBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoSelectedProvider);
    final themeData = Theme.of(context);

    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: !isDemo
          ? const SizedBox.shrink()
          : Card(
              color: themeData.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: themeData.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('components.demo_printer.banner_title'),
                                style: themeData.textTheme.titleSmall?.copyWith(
                                  color: themeData
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('components.demo_printer.banner_body'),
                                style: themeData.textTheme.bodySmall?.copyWith(
                                  color: themeData
                                      .colorScheme
                                      .onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => _removeDemo(ref),
                          child: Text(tr('components.demo_printer.remove')),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.pushNamed(AppRoute.printerAdd.name),
                          child: Text(tr('components.demo_printer.add_own')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _removeDemo(WidgetRef ref) async {
    final machineService = ref.read(machineServiceProvider);
    final demo = await machineService.fetchMachine(demoMachineUuid);
    if (demo != null) await machineService.removeMachine(demo);
  }
}

/// Stands in for the webcam of the demo printer: a drawn top-down view of the
/// bed that follows the simulated toolhead and the objects of the print.
class DemoWebcamPlaceholder extends ConsumerWidget {
  const DemoWebcamPlaceholder({
    super.key,
    required this.machineUUID,
    this.stackContent = const [],
  });

  final String machineUUID;
  final List<Widget> stackContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = printerProvider(machineUUID);
    // Records of doubles and freezed DTOs keep the selects comparable.
    final nozzle = ref
        .watch(
          provider.selectAs(
            (p) => (p.toolhead.position[0], p.toolhead.position[1]),
          ),
        )
        .value;
    final objects = ref.watch(provider.selectAs((p) => p.excludeObject)).value;
    final themeData = Theme.of(context);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2B2F36), Color(0xFF15171B)],
                ),
              ),
              child: CustomPaint(
                painter: _DemoBedPainter(
                  nozzle: nozzle,
                  objects: objects,
                  accent: themeData.colorScheme.primary,
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('components.demo_printer.webcam'),
                      style: themeData.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...stackContent,
        ],
      ),
    );
  }
}

class _DemoBedPainter extends CustomPainter {
  _DemoBedPainter({
    required this.nozzle,
    required this.objects,
    required this.accent,
  });

  final (double, double)? nozzle;
  final ExcludeObject? objects;
  final Color accent;

  static const _bedSize = 250.0;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.84;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final scale = side / _bedSize;
    // Klipper's Y grows to the back, the canvas' Y grows down.
    Offset toCanvas(double x, double y) =>
        origin + Offset(x * scale, (_bedSize - y) * scale);

    final bed = origin & Size.square(side);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bed, const Radius.circular(6)),
      Paint()..color = const Color(0xFF3A3F47),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final d = side * i / 10;
      canvas
        ..drawLine(
          bed.topLeft + Offset(d, 0),
          bed.bottomLeft + Offset(d, 0),
          grid,
        )
        ..drawLine(
          bed.topLeft + Offset(0, d),
          bed.topRight + Offset(0, d),
          grid,
        );
    }

    for (final object in objects?.objects ?? const <ParsedObject>[]) {
      if (object.polygons.length < 3) continue;
      final excluded = objects!.excludedObjects.contains(object.name);
      final path = Path()
        ..addPolygon([
          for (final p in object.polygons) toCanvas(p.x, p.y),
        ], true);
      canvas
        ..drawPath(
          path,
          Paint()
            ..color = (excluded ? Colors.white : accent).withValues(
              alpha: excluded ? 0.05 : 0.35,
            ),
        )
        ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = (excluded ? Colors.white24 : accent),
        );
    }

    if (nozzle case (final x, final y)) {
      final c = toCanvas(x.clamp(0, _bedSize), y.clamp(0, _bedSize));
      final gantry = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 6;
      canvas
        ..drawLine(Offset(bed.left, c.dy), Offset(bed.right, c.dy), gantry)
        ..drawCircle(c, 9, Paint()..color = const Color(0xFFE0E0E0))
        ..drawCircle(c, 3, Paint()..color = const Color(0xFFFF7043));
    }
  }

  @override
  bool shouldRepaint(_DemoBedPainter oldDelegate) =>
      oldDelegate.nozzle != nozzle ||
      oldDelegate.objects != objects ||
      oldDelegate.accent != accent;
}
