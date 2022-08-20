import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/ui/screens/console/console_page.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_page.dart';
import 'package:mobileraker/ui/screens/files/files_page.dart';
import 'package:mobileraker/ui/screens/fullcam/full_cam_view.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:mobileraker/ui/screens/printers/edit/printers_edit_page.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/ui/screens/setting/imprint/imprint_view.dart';
import 'package:mobileraker/ui/screens/setting/setting_page.dart';

enum AppRoute {
  dashBoard,
  printerEdit,
  fullCam,
  printerAdd,
  qrScanner,
  console,
  files,
  settings,
  imprint
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
        builder: (context, state) => const DashboardView(),
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
          return FullCamView(b['machine'], b['selectedCam']);
        },
      ),
      GoRoute(
        path: '/printer',
        builder: (_, __) => const SizedBox(),
        routes: [
          GoRoute(
            path: 'edit',
            name: AppRoute.printerEdit.name,
            builder: (context, state) =>
                // TestPage(),
                PrinterEdit(machine: state.extra! as Machine),
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
        builder: (context, state) => const FilesView(),
      ),
      GoRoute(
        path: '/setting',
        name: AppRoute.settings.name,
        builder: (context, state) => const SettingView(),
      ),
      GoRoute(
        path: '/imprint',
        name: AppRoute.imprint.name,
        builder: (context, state) => const ImprintPage(),
      ),
      GoRoute(
        path: '/console',
        name: AppRoute.console.name,
        builder: (context, state) => const ConsoleView(),
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
});
