import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stringr/stringr.dart';

part 'snackbar_service.g.dart';

enum SnackbarType { error, warning, info }

@riverpod
SnackBarService snackBarService(SnackBarServiceRef ref) => SnackBarService(ref);

class SnackBarService {
  const SnackBarService(this.ref);

  final Ref ref;

  show(SnackBarConfig config) {
    var context =
        ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext!;

    ScaffoldMessenger.of(context)
        .showSnackBar(_constructSnackbar(context, config));
  }

  SnackBar _constructSnackbar(BuildContext context, SnackBarConfig config) {
    var themeData = Theme.of(context);
    Color bgCol, txtCol, btnBg, btnOnBg;
    switch (config.type) {
      case SnackbarType.error:
        bgCol = Colors.red;
        txtCol = Colors.white70;
        btnBg = Colors.red.darken(22);
        btnOnBg = Colors.white70;
        break;
      case SnackbarType.warning:
        bgCol = Colors.deepOrange;
        txtCol = Colors.white70;
        btnBg = Colors.deepOrange.darken(11);
        btnOnBg = Colors.white70;
        break;
      default:
        bgCol = themeData.colorScheme.tertiaryContainer;
        txtCol = themeData.colorScheme.onTertiaryContainer;
        btnBg = themeData.colorScheme.primary;
        btnOnBg = themeData.colorScheme.onPrimary;
    }

    return SnackBar(
      duration: config.duration ?? const Duration(days: 365),
      backgroundColor: bgCol,
      padding: EdgeInsets.zero,
      content: InkWell(
        onTap: ScaffoldMessenger.of(context).hideCurrentSnackBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.title ?? config.type.name.titleCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: txtCol, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      config.message ?? '',
                      style: TextStyle(color: txtCol),
                    ),
                  ],
                ),
              ),
              if (config.mainButtonTitle != null)
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: btnBg, foregroundColor: btnOnBg),
                    onPressed: config.onMainButtonTapped != null
                        ? () {
                            if (config.closeOnMainButtonTapped == true) {
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                            }
                            config.onMainButtonTapped!();
                          }
                        : null,
                    child: Text(
                      config.mainButtonTitle!,
                    ))
            ],
          ),
        ),
      ),
    );
  }
}

class SnackBarConfig {
  final SnackbarType type;
  final Duration? duration;
  final String? title;
  final String? message;
  final String? mainButtonTitle;
  final VoidCallback? onMainButtonTapped;
  final bool closeOnMainButtonTapped;

  SnackBarConfig(
      {this.type = SnackbarType.info,
      this.duration = const Duration(seconds: 5),
      this.title,
      this.message,
      this.mainButtonTitle,
      this.onMainButtonTapped,
      this.closeOnMainButtonTapped = false});

  factory SnackBarConfig.stacktraceDialog({
    required DialogService dialogService,
    required Object exception,
    required StackTrace stack,
    String snackTitle = 'Error',
    String? snackMessage,
    String? dialogTitle,
    String? dialogExceptionPrefix,
  }) {
    return SnackBarConfig(
        type: SnackbarType.error,
        title: snackTitle,
        message: snackMessage ?? exception.toString(),
        duration: const Duration(seconds: 30),
        mainButtonTitle: tr('general.details'),
        closeOnMainButtonTapped: true,
        onMainButtonTapped: () {
          var prefix =
              (dialogExceptionPrefix != null) ? '$dialogExceptionPrefix\n' : '';

          dialogService.show(DialogRequest(
              type: DialogType.stacktrace,
              title: dialogTitle ?? snackTitle,
              body: '${prefix}Exception:\n $exception\n\n$stack'));
        });
  }
}
