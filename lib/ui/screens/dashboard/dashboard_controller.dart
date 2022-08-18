import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/selected_machine_service.dart';

final dashBoardViewControllerProvider =
    StateNotifierProvider.autoDispose<DashBoardViewController, int>((ref) {
  return DashBoardViewController(ref);
});

final pageControllerProvider =
    Provider.autoDispose<PageController>((ref) {
      ref.onDispose(() {logger.e('PG dispoed');});
      logger.e('Creaaa');
      return PageController();
    });

class DashBoardViewController extends StateNotifier<int> {
  DashBoardViewController(this.ref)
      : pageController = ref.watch(pageControllerProvider),
        super(0);

  final AutoDisposeRef ref;

  final PageController pageController;

  onHorizontalDragEnd(DragEndDetails endDetails) {
    double primaryVelocity = endDetails.primaryVelocity ?? 0;
    var selectedMachineService = ref.read(selectedMachineServiceProvider);

    if (primaryVelocity < 0) {
      // Page forwards
      selectedMachineService.selectPreviousMachine();
    } else if (primaryVelocity > 0) {
      // Page backwards
      selectedMachineService.selectNextMachine();
    }
  }

  onBottomNavTapped(int value) {
    pageController.animateToPage(value,
        duration: kThemeChangeDuration, curve: Curves.easeOutCubic);
  }

  onPageChanged(int index) {
    state = index;
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }
}
