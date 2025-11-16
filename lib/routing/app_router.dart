/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:go_transitions/go_transitions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/app_version_text.dart';
import 'package:mobileraker/ui/screens/console/console_page.dart';
import 'package:mobileraker/ui/screens/dev/dev_page.dart';
import 'package:mobileraker/ui/screens/files/details/config_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/gcode_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/image_file_page.dart';
import 'package:mobileraker/ui/screens/files/file_manager_page.dart';
import 'package:mobileraker/ui/screens/files/file_manager_search_page.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_page.dart';
import 'package:mobileraker/ui/screens/gcode_preview/gcode_preview_page.dart';
import 'package:mobileraker/ui/screens/graph/graph_page.dart';
import 'package:mobileraker/ui/screens/markdown/mark_down_page.dart';
import 'package:mobileraker/ui/screens/overview/overview_page.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page.dart';
import 'package:mobileraker/ui/screens/paywall/perks/supporter_benefits_page.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:mobileraker/ui/screens/printers/edit/printers_edit_page.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/ui/screens/setting/data/data_settings_page.dart';
import 'package:mobileraker/ui/screens/setting/imprint/imprint_view.dart';
import 'package:mobileraker/ui/screens/setting/log/log_page.dart';
import 'package:mobileraker/ui/screens/setting/notification/notification_settings_page.dart';
import 'package:mobileraker/ui/screens/setting/setting_page.dart';
import 'package:mobileraker/ui/screens/spoolman/filament_detail_page.dart';
import 'package:mobileraker/ui/screens/spoolman/spool_detail_page.dart';
import 'package:mobileraker/ui/screens/spoolman/spoolman_page.dart';
import 'package:mobileraker/ui/screens/spoolman/vendor_detail_page.dart';
import 'package:mobileraker/ui/screens/tools/components/belt_tuner.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../ui/screens/dashboard/customizable_dashboard_page.dart';
import '../ui/screens/files/details/video_player_page.dart';
import '../ui/screens/files/move_file_destination_page.dart';
import '../ui/screens/setting/notification/machine_notification_settings_page.dart';
import '../ui/screens/spoolman/filament_form_page.dart';
import '../ui/screens/spoolman/spool_form_page.dart';
import '../ui/screens/spoolman/vendor_form_page.dart';
import '../ui/screens/tools/bedMesh/bed_mesh_page.dart';
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
  settings_notification,
  settings_notification_device,
  settings_data,
  imprint,
  dev,
  faq,
  changelog,
  talker_logscreen,
  supportDev,
  supportDev_benefits,
  tool,
  tool_beltTuner,
  tool_bedMesh,
  graph,
  fileManager_explorer,
  fileManager_exlorer_search,
  fileManager_exlorer_move,
  fileManager_exlorer_gcodeDetail,
  fileManager_exlorer_editor,
  fileManager_exlorer_videoPlayer,
  fileManager_exlorer_imageViewer,
}

@riverpod
Future<String> initialRoute(Ref ref) async {
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
      MobilerakerRouteObserver('Main'),
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
        path: '/graph',
        name: AppRoute.graph.name,
        builder: (context, state) => GraphPage(machineUUID: state.uri.queryParameters['machineUUID']!),
        pageBuilder: GoTransitions.fullscreenDialog,
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
            path: 'gcode-preview',
            name: ProRoutes.fileManager_exlorer_gcodePreview.name,
            builder: (context, state) => GCodePreviewPage(
              machineUUID: state.uri.queryParameters['machineUUID']!,
              file: state.extra as GCodeFile,
              live: state.uri.queryParameters['live'] == 'true',
            ),
            pageBuilder: GoTransitions.fullscreenDialog,
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
        routes: [
          GoRoute(
            path: 'notification',
            name: AppRoute.settings_notification.name,
            builder: (context, state) => NotificationSettingsPage(),
            routes: [
              GoRoute(
                path: 'device',
                name: AppRoute.settings_notification_device.name,
                pageBuilder: GoTransitions.fullscreenDialog,
                builder: (context, state) => MachineNotificationSettingsPage(machine: state.extra as Machine),
              ),
            ],
          ),
          GoRoute(
            path: 'data',
            name: AppRoute.settings_data.name,
            builder: (context, state) => const DataSettingsPage(),
          )
        ],
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
        routes: [
          GoRoute(
            path: 'benefits',
            name: AppRoute.supportDev_benefits.name,
            pageBuilder: GoTransitions.fullscreenDialog,
            builder: (context, state) => const SupporterBenefitsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/dev',
        name: AppRoute.dev.name,
        builder: (context, state) => DevPage(),
      ),
      GoRoute(
        path: '/talker',
        name: AppRoute.talker_logscreen.name,
        builder: (context, state) => LogPage(),
      ),
      GoRoute(
        path: '/tool',
        name: AppRoute.tool.name,
        builder: (context, state) => const ToolPage(),
        routes: [
          GoRoute(
            path: 'belt-tuner',
            name: AppRoute.tool_beltTuner.name,
            builder: (context, state) => const BeltTuner(),
          ),
          GoRoute(
            path: 'bed-mesh',
            name: AppRoute.tool_bedMesh.name,
            builder: (context, state) => BedMeshPage(args: state.extra as BedMeshPageArgs),
            pageBuilder: GoTransitions.zoom.withBackGesture.build(settings: const GoTransitionSettings(fullscreenDialog: true)),
          ),
        ],
      ),
      GoRoute(
        path: '/spoolman',
        name: ProRoutes.spoolman.name,
        builder: (context, state) => const SpoolmanPage(),
        routes: [
          GoRoute(
            path: 'details/spool',
            name: ProRoutes.spoolman_details_spool.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID, GetSpool spool] => SpoolDetailPage(spool: spool, machineUUID: machineUUID),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
          ),
          GoRoute(
            path: 'details/filament',
            name: ProRoutes.spoolman_details_filament.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID, GetFilament filament] =>
                FilamentDetailPage(filament: filament, machineUUID: machineUUID),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
          ),
          GoRoute(
            path: 'details/vendor',
            name: ProRoutes.spoolman_details_vendor.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID, GetVendor vendor] => VendorDetailPage(vendor: vendor, machineUUID: machineUUID),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
          ),
          GoRoute(
            path: 'create/spool',
            name: ProRoutes.spoolman_form_spool.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID] => SpoolFormPage(machineUUID: machineUUID),
              [String machineUUID, GetSpool spool] => SpoolFormPage(
                  machineUUID: machineUUID,
                  initialSpool: spool,
                  isCopy: state.uri.queryParameters['isCopy'] == 'true',
                ),
              [String machineUUID, GetFilament filament] => SpoolFormPage(
                  machineUUID: machineUUID,
                  initialFilament: filament,
                ),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
            pageBuilder: GoTransitions.fullscreenDialog,
          ),
          GoRoute(
            path: 'create/filament',
            name: ProRoutes.spoolman_form_filament.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID] => FilamentFormPage(machineUUID: machineUUID),
              [String machineUUID, GetFilament filament] => FilamentFormPage(
                  machineUUID: machineUUID,
                  initialFilament: filament,
                  isCopy: state.uri.queryParameters['isCopy'] == 'true',
                ),
              [String machineUUID, GetVendor vendor] => FilamentFormPage(
                  machineUUID: machineUUID,
                  initialVendor: vendor,
                ),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
            pageBuilder: GoTransitions.fullscreenDialog,
          ),
          GoRoute(
            path: 'create/vendor',
            name: ProRoutes.spoolman_form_vendor.name,
            builder: (context, state) => switch (state.extra) {
              [String machineUUID] => VendorFormPage(machineUUID: machineUUID),
              [String machineUUID, GetVendor vendor] => VendorFormPage(
                  machineUUID: machineUUID,
                  vendor: vendor,
                  isCopy: state.uri.queryParameters['isCopy'] == 'true',
                ),
              _ => throw ArgumentError('Invalid state.extra for spool-details route'),
            },
            pageBuilder: GoTransitions.fullscreenDialog,
          ),
        ],
      ),
      ShellRoute(
        observers: [
          MobilerakerRouteObserver('SheetShell'),
        ],
        pageBuilder: (context, state, child) {
          // Use ModalSheetPage to show a modal sheet.
          return ModalSheetPage(
            name: 'BottomSheetModalSheet',
            // transitionDuration: const Duration(milliseconds: 3000),
            swipeDismissible: true,
            viewportPadding: EdgeInsets.only(
              // Add the top padding to avoid the status bar.
              top: MediaQuery
                  .viewPaddingOf(context)
                  .top,
            ),
            child: PagedSheet(
              decoration: MaterialSheetDecoration(
                size: SheetSize.stretch,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  clipBehavior: Clip.antiAlias,
              ),
              navigator: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: child,
              ),
            ),
          );
        },
        routes: BottomSheetServiceImpl.routes,
      ),
    ],
    // errorBuilder: (context, state) => const NotFoundScreen(),
  );
}
