import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/files/remote_file.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/screens/console/console_page.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_page.dart';
import 'package:mobileraker/ui/screens/files/details/config_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/details/gcode_file_details_page.dart';
import 'package:mobileraker/ui/screens/files/files_page.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_page.dart';
import 'package:mobileraker/ui/screens/overview/overview_page.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:mobileraker/ui/screens/printers/edit/printers_edit_page.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/ui/screens/setting/imprint/imprint_view.dart';
import 'package:mobileraker/ui/screens/setting/setting_page.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';

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
  configDetail
}

final initialRouteProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.keepAlive();
  SettingService settingService = ref.watch(settingServiceProvider);

  if (!settingService.readBool(startWithOverviewKey)) {
    return '/';
  }
  int printerCnt =
      await ref.watch(allMachinesProvider.selectAsync((data) => data.length));

  if (printerCnt > 1) {
    return '/overview';
  }
  return '/';
});

final goRouterProvider = Provider.autoDispose<GoRouter>((ref) {
  ref.keepAlive();
  return GoRouter(
    initialLocation: ref.watch(initialRouteProvider).valueOrFullNull!,
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
              builder: (context, state) =>
                  GCodeFileDetailPage(gcodeFile: state.extra! as GCodeFile),
            ),
            GoRoute(
              path: 'config-details',
              name: AppRoute.configDetail.name,
              builder: (context, state) =>
                  ConfigFileDetailPage(file: state.extra! as RemoteFile),
            ),
          ]),
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
      // GoRoute(
      //   path: 'cart',
      //   name: AppRoute.cart.name,
      //   pageBuilder: (context, state) => MaterialPage(
      //     key: state.pageKey,
      //     fullscreenDialog: true,
      //     child: const ShoppingCartScreen(),
      //   ),
      //   routes: [
      //     GoRoute(
      //       path: 'checkout',
      //       name: AppRoute.checkout.name,
      //       pageBuilder: (context, state) => MaterialPage(
      //         key: ValueKey(state.location),
      //         fullscreenDialog: true,
      //         child: const CheckoutScreen(),
      //       ),
      //     ),
      //   ],
      // ),
      // GoRoute(
      //   path: 'signIn',
      //   name: AppRoute.signIn.name,
      //   pageBuilder: (context, state) => MaterialPage(
      //     key: state.pageKey,
      //     fullscreenDialog: true,
      //     child: const EmailPasswordSignInScreen(
      //       formType: EmailPasswordSignInFormType.signIn,
      //     ),
      //   ),
      // ),
    ],
    // errorBuilder: (context, state) => const NotFoundScreen(),
  );
}, dependencies: [initialRouteProvider]);
