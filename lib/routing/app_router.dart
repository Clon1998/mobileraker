import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_view.dart';
import 'package:mobileraker/ui/screens/printers/add/printers_add_page.dart';
import 'package:mobileraker/ui/screens/printers/edit/printers_edit_view.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';

enum AppRoute {
  dashBoard,
  printerEdit,
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
        path: '/printer/edit',
        name: AppRoute.printerEdit.name,
        builder: (context, state) =>
            // TestPage(),
            PrinterEdit(machine: state.extra! as Machine),
      ),
      GoRoute(
        path: '/printer/add',
        name: AppRoute.printerAdd.name,
        builder: (context, state) =>
            // TestPage(),
            const PrinterAddPage(),
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
