/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/service/payment_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/misc.dart';
import 'package:common/util/svg/gray_scale_color_mapper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page_controller.dart';
import 'package:progress_indicators/progress_indicators.dart';

import 'components/supporter_benefits.dart';
import 'components/supporter_offerings.dart';
import 'components/supporter_tipping.dart';

class PaywallPage extends HookConsumerWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSupporter = ref.watch(isSupporterProvider);
    Widget body = CustomScrollView(
      physics: const ClampingScrollPhysics().only(context.isCompact),
      slivers: [
        if (context.isCompact)
          SliverAppBar(
            expandedHeight: 210,
            floating: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: SvgPicture.asset(alignment: Alignment.topCenter, 'assets/vector/mr_logo.svg', colorMapper: GrayScaleColorMapper().unless(isSupporter),),
            ),
          ),
        if (context.isLargerThanCompact)
          SliverToBoxAdapter(child: SvgPicture.asset(height: 210, 'assets/vector/mr_logo.svg', colorMapper: GrayScaleColorMapper().unless(isSupporter),)),
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            sliver: const SliverFillRemaining(hasScrollBody: false, child: ResponsiveLimit(child: _PaywallPage())),
          ),
        ),
      ],
    );
    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('pages.paywall.title'))).unless(context.isCompact),
      drawer: const NavigationDrawerWidget(),
      body: LoaderOverlay(
        overlayWidgetBuilder: (_) => Center(
          child: Column(
            key: UniqueKey(),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCube(color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 30),
              FadingText(tr('pages.paywall.calling_store')),
            ],
          ),
        ),
        child: body,
      ),
    );
  }
}

class _PaywallPage extends ConsumerWidget {
  const _PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(paywallPageControllerProvider.selectAs((value) => value.makingPurchase), (previous, next) {
      if (next.valueOrNull == true) {
        context.loaderOverlay.show();
      } else {
        context.loaderOverlay.hide();
      }
    });

    return ref
        .watch(paywallPageControllerProvider)
        .when(
          data: (data) => _PaywallOfferingsContainer(model: data),
          error: (e, s) {
            if (e is PlatformException && e.code == '3') {
              return _ServicesUnavailableWidget();
            }
            return _FetchErrorWidget();
          },
          loading: () => Column(
            spacing: 20,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SpinKitPumpingHeart(color: Theme.of(context).colorScheme.primary, size: 66),
              FadingText('pages.paywall.loading.title'.tr()),
            ],
          ),
        );
  }
}

class _ServicesUnavailableWidget extends ConsumerWidget {
  const _ServicesUnavailableWidget({super.key});

  String _getStoreDisplayName() {
    return tr(Platform.isAndroid ? 'general.google_play' : 'general.ios_store');
  }

  String _getServicesName() {
    return tr(Platform.isAndroid ? 'general.google_play_services' : 'general.apple_services');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final textTheme = themeData.textTheme;
    final controller = ref.read(paywallPageControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'pages.paywall.services_unavailable.title',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ).tr(args: [_getStoreDisplayName()]),
          const Gap(12),
          Text(
            'pages.paywall.services_unavailable.description',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ).tr(args: [_getServicesName()]),
          Gap(32),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'pages.paywall.services_unavailable.solutions_title',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ).tr(),
                const SizedBox(height: 16),

                // Step 1
                _buildTroubleshootStep(
                  context,
                  1,
                  'pages.paywall.services_unavailable.install_services',
                  args: [_getServicesName()],
                ),

                // Step 2
                _buildTroubleshootStep(
                  context,
                  2,
                  'pages.paywall.services_unavailable.update_services',
                  args: [_getServicesName()],
                ),

                // Step 3
                _buildTroubleshootStep(context, 3, 'pages.paywall.services_unavailable.manual_signin'),
              ],
            ),
          ),
          Gap(32),
          ElevatedButton(
            onPressed: controller.userSignIn,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text('pages.paywall.services_unavailable.signin_btn').tr(),
          ),
          Gap(12),
          OutlinedButton(
            onPressed: () => ref.invalidate(paywallPageControllerProvider),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text('pages.paywall.services_unavailable.retry_btn').tr(),
          ),
          Gap(12),
          TextButton.icon(
            onPressed: controller.openGithub,
            icon: const Icon(FlutterIcons.github_faw5d),
            label: Text('pages.paywall.services_unavailable.github_btn').tr(),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootStep(BuildContext context, int stepNumber, String stepTextKey, {List<String>? args}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Text(
                stepTextKey,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
              ).tr(args: args),
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchErrorWidget extends ConsumerWidget {
  const _FetchErrorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final colorScheme = themeData.colorScheme;
    final textTheme = themeData.textTheme;
    final controller = ref.read(paywallPageControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_off, size: 55, color: colorScheme.error),
          Gap(24),
          Text(
            'pages.paywall.fetch_error.title',
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ).tr(),
          Gap(12),

          Text(
            'pages.paywall.fetch_error.description',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ).tr(),
          Gap(32),
          if (ref.watch(isSupporterProvider))
            _SubscriptionManagementNotice(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'pages.paywall.fetch_error.what_to_try',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ).tr(),
                const SizedBox(height: 12),

                _buildSuggestion(context, '📶', 'pages.paywall.fetch_error.check_connection'),

                _buildSuggestion(context, '🔄', 'pages.paywall.fetch_error.wait_retry'),

                _buildSuggestion(context, '⏰', 'pages.paywall.fetch_error.try_later'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(paywallPageControllerProvider),
            icon: const Icon(Icons.refresh),
            label: Text('pages.paywall.fetch_error.try_again_btn').tr(),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          Gap(12),
          OutlinedButton(
            onPressed: controller.userSignIn,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text('pages.paywall.services_unavailable.signin_btn').tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestion(BuildContext context, String emoji, String textKey) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        spacing: 12,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(textKey, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)).tr(),
          ),
        ],
      ),
    );
  }
}

class _PaywallOfferingsContainer extends ConsumerWidget {
  const _PaywallOfferingsContainer({super.key, required this.model});

  final PaywallPageState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isSupporterProvider) ? _ManagementView(model: model) : _SubscriptionView(model: model);
  }
}

class _SubscriptionView extends ConsumerWidget {
  const _SubscriptionView({super.key, required this.model});

  final PaywallPageState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(paywallPageControllerProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(),
        const SupporterBenefits(),
        Gap(16),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            'pages.paywall.subscribe_view.offering_title',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ).tr(),
        ),
        Gap(8),
        SupporterOfferings(
          packets: model.paywallOfferings,
          iapPromos: model.iapPromos,
          purchasePackage: controller.makePurchase,
        ),
        Gap(16),
        if (model.tipAvailable)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 8,
                children: <Widget>[
                  Expanded(child: Divider(thickness: 1)),
                  Text('pages.paywall.tipping.divider', style: textTheme.bodySmall).tr(),
                  Expanded(child: Divider(thickness: 1)),
                ],
              ),
              Gap(16),
              TippingCard(
                tipOffering: model.tipsOffering!,
                onTipSelected: controller.makePurchase,
                onMoreTipOptionsSelected: controller.onTippingPressed,
              ),
            ],
          ),
        _Footer(),
      ],
    );
  }
}

class _ManagementView extends ConsumerWidget {
  const _ManagementView({super.key, required this.model});

  final PaywallPageState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supOrigin = ref.watch(supportBoughtOnThisPlatformProvider);
    final hasSubAndLifetime = ref.watch(hasSubscriptionAndLifetimeProvider);

    var textTheme = Theme.of(context).textTheme;
    final controller = ref.read(paywallPageControllerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(),
        if (supOrigin == false) ...[const _SubscriptionManagementNotice(), Gap(8)],
        const SupporterBenefits(),
        if (hasSubAndLifetime) ...[Gap(8), const _SubLifetimeWarning()],
        Gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'pages.paywall.manage_view.offering_title',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ).tr(),
        ),
        Gap(8),
        SupporterOfferings(
          packets: model.paywallOfferings,
          iapPromos: model.iapPromos,
          purchasePackage: controller.makePurchase,
        ),
        Gap(16),
        if (model.tipAvailable)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 8,
                children: <Widget>[
                  Expanded(child: Divider(thickness: 1)),
                  Text('pages.paywall.tipping.divider', style: textTheme.bodySmall).tr(),
                  Expanded(child: Divider(thickness: 1)),
                ],
              ),
              Gap(16),
              TippingCard(
                tipOffering: model.tipsOffering!,
                onTipSelected: controller.makePurchase,
                onMoreTipOptionsSelected: controller.onTippingPressed,
              ),
            ],
          ),
        _Footer(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({super.key});

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String translationKey,
    List<String>? args,
    double iconSize = 15,
  }) {
    final themeData = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: themeData.textTheme.bodySmall?.color),
        const Gap(4),
        Text(translationKey, style: themeData.textTheme.bodySmall).tr(args: args),
      ],
    );
  }

  Widget _buildHeader({required BuildContext context, required String titleKey, required String subtitleKey}) {
    final themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titleKey, style: themeData.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)).tr(),
          const Gap(4),
          Text(subtitleKey, style: themeData.textTheme.bodySmall).tr(),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(BuildContext context) {
    final themeData = Theme.of(context);
    final name = storeName();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.yellow[700], size: 20),
          const SizedBox(width: 6),
          Text(
            'pages.paywall.header.rating',
            style: themeData.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ).tr(args: ['4.8/5', name]),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            context: context,
            icon: FlutterIcons.github_alt_faw5d,
            translationKey: 'pages.paywall.header.open_core',
          ),
          _buildStatItem(
            context: context,
            icon: Icons.group_outlined,
            translationKey: 'pages.paywall.header.amnt_users',
            args: ['20k+'],
          ),
          _buildStatItem(
            context: context,
            icon: FlutterIcons.console_line_mco,
            translationKey: 'pages.paywall.header.active_dev',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSup = ref.watch(isSupporterProvider);
    final key = isSup ? 'manage_view' : 'subscribe_view';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHeader(
          context: context,
          titleKey: 'pages.paywall.$key.title',
          subtitleKey: 'pages.paywall.$key.subtitle',
        ),
        _buildRatingBadge(context),
        _buildStatsRow(context),
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(paywallPageControllerProvider.notifier);
    final isSupporter = ref.watch(isSupporterProvider);
    final canCancel =
        (ref.watch(customerInfoProvider.selectAs((data) => data.managementURL != null)).valueOrNull == true);

    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.bodySmall, iconSize: 10),
        ),
      ),
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceEvenly,
        overflowAlignment: OverflowBarAlignment.center,
        children: [
          TextButton(
            onPressed: controller.userSignIn,
            onLongPress: controller.copyRCatIdToClipboard,
            child: Text('pages.paywall.restore_sign_in').tr(),
          ),
          if (isSupporter)
            TextButton(
              onPressed: controller.openDevContact,
              child: const Text('pages.paywall.contact_dialog.title').tr(),
            ),
          if (canCancel)
            TextButton(onPressed: controller.openManagement, child: Text('pages.paywall.manage_view.cancel_btn').tr()),
        ],
      ),
    );
  }
}

/// Card to show to let the user know that the supporter status was bought on a differnt platform
class _SubscriptionManagementNotice extends StatelessWidget {
  const _SubscriptionManagementNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final isDarkMode = themeData.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDarkMode
          ? themeData.colorScheme.errorContainer.withValues(alpha: 0.4)
          : themeData.colorScheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: themeData.colorScheme.error, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: DefaultTextStyle(
          style: themeData.textTheme.bodySmall!,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 20, color: themeData.colorScheme.error),
                  const Gap(4),
                  Text(
                    'pages.paywall.sup_origin_warning.title',
                    style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ).tr(),
                ],
              ),
              const Gap(8),
              Text('pages.paywall.sup_origin_warning.subtitle').tr(),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card to show when the user has a subscription + lifetime supporter status to warn them
class _SubLifetimeWarning extends StatelessWidget {
  const _SubLifetimeWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Card(
      elevation: 0,
      color: themeData.colorScheme.errorContainer.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: themeData.colorScheme.error, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: DefaultTextStyle(
          style: themeData.textTheme.bodySmall!,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.volunteer_activism_outlined, size: 20, color: themeData.colorScheme.error),
                  const Gap(4),
                  Text(
                    'pages.paywall.sup_lifetime_warning.title',
                    style: themeData.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ).tr(),
                ],
              ),
              const Gap(8),
              Text('pages.paywall.sup_lifetime_warning.subtitle').tr(),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}

