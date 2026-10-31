/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../service/ui/dialog_service_interface.dart';

/// Controls how the webcam status views are laid out by the screen hosting the webcam.
enum WebcamStatusStyle {
  /// Small single-row tile, used inside cards.
  compact,

  /// Centered layout, used if the webcam takes up the entire screen.
  fullscreen,
}

/// Shared loading presentation for all webcam implementations (MJPEG, WebRTC, ...).
/// Uses the same footprint as [WebcamErrorView] so retrying does not cause layout jumps.
class WebcamLoadingView extends StatelessWidget {
  const WebcamLoadingView({super.key, this.style = WebcamStatusStyle.compact});

  final WebcamStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullscreen = style == WebcamStatusStyle.fullscreen;
    final size = fullscreen ? 64.0 : 40.0;

    return _StatusLayout(
      style: style,
      avatar: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(strokeWidth: fullscreen ? 3 : 2.5, color: colorScheme.primary),
            Icon(Icons.videocam_outlined, size: size / 2, color: colorScheme.primary),
          ],
        ),
      ),
      title: tr('components.connection_watcher.trying_connect'),
    );
  }
}

/// Shared error presentation for all webcam implementations (MJPEG, WebRTC, ...).
///
/// The implementations stay responsible for detecting errors and retrying, this widget
/// only renders them. Technical details (configured URIs + error) are shown in the stacktrace dialog
/// so they can be copied for bug reports without taking up space in the UI.
class WebcamErrorView extends ConsumerWidget {
  const WebcamErrorView({
    super.key,
    this.error,
    this.details,
    this.onRetry,
    this.style = WebcamStatusStyle.compact,
  });

  final Object? error;

  /// Additional technical information (e.g. the configured URIs) shown in the details dialog.
  final String? details;

  final VoidCallback? onRetry;

  final WebcamStatusStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullscreen = style == WebcamStatusStyle.fullscreen;

    void showDetails() {
      ref
          .read(dialogServiceProvider)
          .show(
            DialogRequest(
              type: CommonDialogs.stacktrace,
              title: tr('pages.dashboard.general.cam_card.error_title'),
              body: [
                if (details != null) details,
                if (error != null) 'Error:\n$error',
              ].join('\n\n'),
            ),
          );
    }

    return _StatusLayout(
      style: style,
      avatar: CircleAvatar(
        radius: fullscreen ? 32 : 20,
        backgroundColor: colorScheme.errorContainer,
        foregroundColor: colorScheme.onErrorContainer,
        child: Icon(Icons.videocam_off_outlined, size: fullscreen ? 32 : 20),
      ),
      title: tr('pages.dashboard.general.cam_card.error_title'),
      subtitle: shortReason(error) ?? tr('pages.dashboard.general.cam_card.error_hint'),
      actions: fullscreen
          ? [
              TextButton(onPressed: showDetails, child: const Text('general.details').tr()),
              if (onRetry != null)
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('components.connection_watcher.reconnect').tr(),
                ),
            ]
          : [
              IconButton(icon: const Icon(Icons.info_outline), tooltip: tr('general.details'), onPressed: showDetails),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: tr('components.connection_watcher.reconnect'),
                  onPressed: onRetry,
                ),
            ],
    );
  }

  /// Extracts a short, human readable reason from common network errors.
  /// Returns null if no meaningful short form is available; the full error is still part of the details.
  static String? shortReason(Object? error) {
    return switch (error) {
      DioException(type: DioExceptionType.badResponse, response: Response(statusCode: final int code)) =>
        tr('pages.dashboard.general.cam_card.reason_http', args: [code.toString()]),
      DioException(
        type: DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout,
      ) =>
        tr('pages.dashboard.general.cam_card.reason_timeout'),
      DioException(type: DioExceptionType.connectionError) ||
      DioException(error: SocketException()) ||
      SocketException() =>
        tr('pages.dashboard.general.cam_card.reason_unreachable'),
      _ => null,
    };
  }
}

/// Common layout of the webcam status views, either as compact tile or centered fullscreen content.
class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    required this.style,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final WebcamStatusStyle style;
  final Widget avatar;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;

    if (style == WebcamStatusStyle.fullscreen) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: themeData.textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: themeData.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, alignment: WrapAlignment.center, children: actions),
              ],
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: ConstrainedBox(
          // Matches the height of the tile with actions, so loading <-> error does not jump
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: themeData.textTheme.titleSmall),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: themeData.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
