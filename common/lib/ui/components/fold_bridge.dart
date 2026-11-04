/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:duo_kit/duo_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:foldable/foldable.dart';

export 'package:duo_kit/duo_kit.dart' show FoldStrip, FoldStripSide;

/// Publishes the fold geometry of foldables (iPhone Duo) to [MediaQueryData.displayFeatures], so it can be read via
/// [FoldBuildContextExtension]. Place it once above the app.
///
/// Android fills the display features itself; on iOS the `foldable` plugin bridges the reserved regions of the
/// window. On all other devices this is a no-op.
class FoldBridge extends StatelessWidget {
  const FoldBridge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FoldableProvider(
      bridgeMode: DisplayFeatureBridgeMode.full,
      child: _ClosedFoldOcclusions(child: child),
    );
  }
}

/// The `foldable` bridge publishes nothing while the device is closed. Publishes the occlusions (camera and status
/// cluster of the cover display) in that case, so the strip of the cover display knows where its free part starts.
class _ClosedFoldOcclusions extends StatefulWidget {
  const _ClosedFoldOcclusions({required this.child});

  final Widget child;

  @override
  State<_ClosedFoldOcclusions> createState() => _ClosedFoldOcclusionsState();
}

class _ClosedFoldOcclusionsState extends State<_ClosedFoldOcclusions> {
  (HingeStatus, List<ReservedRegion>, List<DisplayFeature>)? _inputs;
  List<DisplayFeature> _features = const [];

  // MediaQuery notifies its dependents about display features by identity, so the list is only rebuilt when its
  // inputs change.
  List<DisplayFeature> _featuresFor(HingeStatus status, List<ReservedRegion> regions, List<DisplayFeature> ambient) {
    final inputs = (status, regions, ambient);
    if (inputs == _inputs) return _features;
    _inputs = inputs;

    if (status != HingeStatus.closed) return _features = ambient;
    return _features = List.unmodifiable([
      ...ambient,
      for (final region in regions)
        if (region.kind == ReservedRegionKind.occlusion && region.isActive && !region.bounds.isEmpty)
          DisplayFeature(bounds: region.bounds, type: DisplayFeatureType.cutout, state: DisplayFeatureState.unknown),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final features = _featuresFor(
      DuoMediaQuery.statusOf(context),
      DuoMediaQuery.regionsOf(context),
      mediaQuery.displayFeatures,
    );

    // Always a MediaQuery, so folding/unfolding keeps the state below.
    return MediaQuery(
      data: mediaQuery.copyWith(displayFeatures: features),
      child: widget.child,
    );
  }
}

extension FoldBuildContextExtension on BuildContext {
  /// The strip at a side edge of the window the system keeps for its controls (iPhone Duo: cover display, and inner
  /// display in landscape), if any. Per Apple's guidelines, the app's navigation goes there.
  ///
  /// Derived from the view padding of the nearest [MediaQuery], hence must be read above any widget removing that
  /// padding.
  FoldStrip? get foldStrip => FoldGeometry.of(this).strip;
}
