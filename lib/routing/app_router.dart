/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
// ignore_for_file: prefer-match-file-name

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/ui/components/app_version_text.dart';
import 'package:mobileraker/ui/components/info_card.dart';
import 'package:mobileraker/ui/screens/console/console_page.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_page.dart';
import 'package:mobileraker/ui/screens/dev/dev_page.dart';
import 'package:mobileraker/ui/screens/files/details/config_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/gcode_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/image_file_page.dart';
import 'package:mobileraker/ui/screens/files/files_page.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_page.dart';
import 'package:mobileraker/ui/screens/markdown/mark_down_page.dart';
import 'package:mobileraker/ui/screens/overview/overview_page.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:mobileraker/ui/screens/printers/edit/printers_edit_page.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/ui/screens/setting/imprint/imprint_view.dart';
import 'package:mobileraker/ui/screens/setting/setting_page.dart';
import 'package:mobileraker/ui/screens/tools/components/belt_tuner.dart';
import 'package:mobileraker_pro/pro_routes.dart';
import 'package:mobileraker_pro/ui/screens/spoolman/spoolman_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ui/screens/files/details/video_player_page.dart';
import '../ui/screens/tools/tool_page.dart';

part 'app_router.g.dart';

enum AppRoute {
  dashBoard,
  overview,
  printerEdit,
  fullCam,
  printerAdd,
  qrScanner,
  console,
  files,
  settings,
  imprint,
  gcodeDetail,
  configDetail,
  imageViewer,
  dev,
  faq,
  changelog,
  supportDev,
  videoPlayer,
  tool,
  beltTuner,
}

@riverpod
Future<String> initialRoute(InitialRouteRef ref) async {
  ref.keepAlive();
  SettingService settingService = ref.watch(settingServiceProvider);

  if (!settingService.readBool(AppSettingKeys.overviewIsHomescreen)) {
    return '/';
  }
  int printerCnt = await ref.watch(allMachinesProvider.selectAsync((data) => data.length));

  if (printerCnt > 1) {
    return '/overview';
  }
  return '/';
}

GoRouter goRouterImpl(GoRouterRef ref) {
  return GoRouter(
    initialLocation: ref.watch(initialRouteProvider).requireValue,
    debugLogDiagnostics: false,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    // redirect: (state) {
    //
    //   return null;
    // },
    // refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges()),
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.dashBoard.name,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/overview',
        name: AppRoute.overview.name,
        builder: (context, state) => const OverviewPage(),
      ),
      GoRoute(
        path: '/qrScanner',
        name: AppRoute.qrScanner.name,
        builder: (context, state) => const QrScannerPage(),
      ),
      GoRoute(
        path: '/fullcam',
        name: AppRoute.fullCam.name,
        builder: (context, state) {
          Map<String, dynamic> b = state.extra as Map<String, dynamic>;
          return FullCamPage(b['machine'], b['selectedCam']);
        },
      ),
      GoRoute(
        path: '/printer',
        builder: (_, __) => const SizedBox(),
        routes: [
          GoRoute(
            path: 'edit',
            name: AppRoute.printerEdit.name,
            builder: (context, state) {
              return PrinterEditPage(machine: state.extra! as Machine);
            },
          ),
          GoRoute(
            path: 'add',
            name: AppRoute.printerAdd.name,
            builder: (context, state) =>
                // TestPage(),
                const PrinterAddPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/files',
        name: AppRoute.files.name,
        builder: (context, state) => const FilesPage(),
        routes: [
          GoRoute(
            path: 'gcode-details',
            name: AppRoute.gcodeDetail.name,
            builder: (context, state) => GCodeFileDetailPage(gcodeFile: state.extra! as GCodeFile),
          ),
          GoRoute(
            path: 'config-details',
            name: AppRoute.configDetail.name,
            builder: (context, state) => ConfigFileDetailPage(file: state.extra! as GenericFile),
          ),
          GoRoute(
            path: 'video-player',
            name: AppRoute.videoPlayer.name,
            builder: (context, state) => VideoPlayerPage(state.extra! as GenericFile),
          ),
          GoRoute(
            path: 'image-viewer',
            name: AppRoute.imageViewer.name,
            builder: (context, state) => ImageFilePage(state.extra! as GenericFile),
          ),
        ],
      ),
      GoRoute(
        path: '/setting',
        name: AppRoute.settings.name,
        builder: (context, state) => const SettingPage(),
      ),
      GoRoute(
        path: '/imprint',
        name: AppRoute.imprint.name,
        builder: (context, state) => const ImprintPage(),
      ),
      GoRoute(
        path: '/console',
        name: AppRoute.console.name,
        builder: (context, state) => const ConsolePage(),
      ),
      GoRoute(
        path: '/faq',
        name: AppRoute.faq.name,
        builder: (context, state) => MarkDownPage(
          title: tr('pages.faq.title'),
          mdRoot: Uri.parse(
            'https://raw.githubusercontent.com/Clon1998/mobileraker/master/docs/faq.md',
          ),
          mdHuman: Uri.parse(
            'https://github.com/Clon1998/mobileraker/blob/master/docs/faq.md',
          ),
        ),
      ),
      GoRoute(
        path: '/changelog',
        name: AppRoute.changelog.name,
        builder: (context, state) => MarkDownPage(
          title: tr('pages.changelog.title'),
          mdRoot: Uri.parse(
            'https://raw.githubusercontent.com/Clon1998/mobileraker/master/docs/changelog.md',
          ),
          mdHuman: Uri.parse(
            'https://github.com/Clon1998/mobileraker/blob/master/docs/changelog.md',
          ),
          topWidget: InfoCard(
            leading: const Icon(FlutterIcons.code_fork_faw),
            title: const Text('components.app_version_display.installed_version').tr(),
            body: const AppVersionText(prefix: 'Mobileraker'),
          ),
        ),
      ),
      GoRoute(
        path: '/paywall',
        name: AppRoute.supportDev.name,
        builder: (context, state) => const PaywallPage(),
      ),
      GoRoute(
        path: '/dev',
        name: AppRoute.dev.name,
        builder: (context, state) => DevPage(),
      ),
      GoRoute(
        path: '/tool',
        name: AppRoute.tool.name,
        builder: (context, state) => ToolPage(),
        routes: [
          GoRoute(
            path: 'belt-tuner',
            name: AppRoute.beltTuner.name,
            builder: (context, state) => const BeltTuner(),
          ),
        ],
      ),
      GoRoute(
        path: '/spoolman',
        name: ProRoutes.spoolman.name,
        builder: (context, state) => const SpoolmanPage(),
      ),
    ],
    // errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
