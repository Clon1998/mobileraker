/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
// ignore_for_file: prefer-match-file-name

import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/info_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:mobileraker/ui/components/app_version_text.dart';
import 'package:mobileraker/ui/screens/console/console_page.dart';
import 'package:mobileraker/ui/screens/dev/dev_page.dart';
import 'package:mobileraker/ui/screens/files/details/config_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/gcode_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/image_file_page.dart';
import 'package:mobileraker/ui/screens/files/file_manager_page.dart';
import 'package:mobileraker/ui/screens/files/file_manager_search_page.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_page.dart';
import 'package:mobileraker/ui/screens/markdown/mark_down_page.dart';
import 'package:mobileraker/ui/screens/overview/overview_page.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:mobileraker/ui/screens/printers/edit/printers_edit_page.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/ui/screens/setting/imprint/imprint_view.dart';
import 'package:mobileraker/ui/screens/setting/setting_page.dart';
import 'package:mobileraker/ui/screens/spoolman/filament_detail_page.dart';
import 'package:mobileraker/ui/screens/spoolman/spool_detail_page.dart';
import 'package:mobileraker/ui/screens/spoolman/spoolman_page.dart';
import 'package:mobileraker/ui/screens/spoolman/vendor_detail_page.dart';
import 'package:mobileraker/ui/screens/tools/components/belt_tuner.dart';
import 'package:mobileraker_pro/spoolman/dto/filament.dart';
import 'package:mobileraker_pro/spoolman/dto/spool.dart';
import 'package:mobileraker_pro/spoolman/dto/vendor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ui/screens/dashboard/customizable_dashboard_page.dart';
import '../ui/screens/files/details/video_player_page.dart';
import '../ui/screens/files/move_file_destination_page.dart';
import '../ui/screens/tools/tool_page.dart';

part 'app_router.g.dart';

enum AppRoute implements RouteDefinitionMixin {
  dashBoard,
  overview,
  printerEdit,
  fullCam,
  printerAdd,
  qrScanner,
  console,
  settings,
  imprint,
  dev,
  faq,
  changelog,
  supportDev,
  tool,
  beltTuner,
  spoolman,
  spoolman_vendorDetails,
  spoolman_spoolDetails,
  spoolman_filamentDetails,
  fileManager_explorer,
  fileManager_exlorer_search,
  fileManager_exlorer_move,
  fileManager_exlorer_gcodeDetail,
  fileManager_exlorer_editor,
  fileManager_exlorer_videoPlayer,
  fileManager_exlorer_imageViewer,
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
      GoTransition.observer,
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
        builder: (context, state) => const CustomizableDashboardPage(),
        // builder: (context, state) => const DashboardPage(),
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
            builder: (context, state) => const PrinterAddPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/files/:path',
        name: AppRoute.fileManager_explorer.name,
        builder: (context, state) =>
            FileManagerPage(filePath: state.pathParameters['path']!, folder: state.extra as Folder?),
        // pageBuilder: GoTransitions.theme.withSlide.withBackGesture.build(
        //   settings: GoTransitionSettings(
        //     duration: const Duration(milliseconds: 3000),
        //     reverseDuration: const Duration(milliseconds: 3000),
        //   ),
        // ),
        routes: [
          GoRoute(
            path: 'search',
            name: AppRoute.fileManager_exlorer_search.name,
            builder: (context, state) => FileManagerSearchPage(
                machineUUID: state.uri.queryParameters['machineUUID']!, path: state.pathParameters['path']!),
            pageBuilder: GoTransitions.fullscreenDialog,
          ),
          GoRoute(
            path: 'move',
            name: AppRoute.fileManager_exlorer_move.name,
            builder: (context, state) => MoveFileDestinationPage(
              machineUUID: state.uri.queryParameters['machineUUID']!,
              path: state.pathParameters['path']!,
              submitLabel: state.uri.queryParameters['submitLabel']!,
            ),
            pageBuilder: (context, state) {
              final path = state.pathParameters['path'] as String;
              final parts = path.split('/');

              if (parts.length > 1) {
                return GoTransitions.theme(context, state);
              }

              return GoTransitions.fullscreenDialog(context, state);
            },
          ),
          GoRoute(
            path: 'gcode-details',
            name: AppRoute.fileManager_exlorer_gcodeDetail.name,
            builder: (context, state) => GCodeFileDetailPage(gcodeFile: state.extra! as GCodeFile),
          ),
          GoRoute(
            path: 'editor',
            name: AppRoute.fileManager_exlorer_editor.name,
            builder: (context, state) => ConfigFileDetailPage(file: state.extra! as GenericFile),
          ),
          GoRoute(
            path: 'video-player',
            name: AppRoute.fileManager_exlorer_videoPlayer.name,
            builder: (context, state) => VideoPlayerPage(state.extra! as GenericFile),
          ),
          GoRoute(
            path: 'image-viewer',
            name: AppRoute.fileManager_exlorer_imageViewer.name,
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
        builder: (context, state) => const ToolPage(),
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
        name: AppRoute.spoolman.name,
        builder: (context, state) => const SpoolmanPage(),
        routes: [
          GoRoute(
            path: 'spool-details',
            name: AppRoute.spoolman_spoolDetails.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID, Spool spool] => SpoolDetailPage(spool: spool, machineUUID: machineUUID),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
          ),
          GoRoute(
            path: 'filament-details',
            name: AppRoute.spoolman_filamentDetails.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID, Filament filament] =>
                FilamentDetailPage(filament: filament, machineUUID: machineUUID),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
          ),
          GoRoute(
            path: 'vendor-details',
            name: AppRoute.spoolman_vendorDetails.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID, Vendor vendor] => VendorDetailPage(vendor: vendor, machineUUID: machineUUID),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
          ),
        ],
      ),
    ],
    // errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
