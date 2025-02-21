/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-unnecessary-reassignment

// ignore_for_file: avoid-passing-async-when-sync-expected

// ignore_for_file: prefer-single-widget-per-file

import 'dart:io';

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/consent_service.dart';
// import 'package:common/service/firebase/admobs.dart';
import 'package:common/service/live_activity_service.dart';
import 'package:common/service/live_activity_service_v2.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
// import 'package:common/ui/components/ad_banner.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:gap/gap.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:iabtcf_consent_info/iabtcf_consent_info.dart';
import 'package:live_activities/live_activities.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker_pro/ads/ad_block_unit.dart';
import 'package:mobileraker_pro/ads/admobs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dev_page.g.dart';

class DevPage extends HookConsumerWidget {
  DevPage({
    super.key,
  });

  String? _bla;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('REBUILIDNG DEV PAGE!');
    var selMachine = ref.watch(selectedMachineProvider).value;

    Widget body = ListView(
      children: [
        // GCodePreviewCard.preview(),
        // const _StlPreview(),
        const _Consent(),
        _IabTCTSTATUS(),

        // ControlExtruderCard(machineUUID: selMachine.uuid),
        // ControlExtruderLoading(),
        // PowerApiCardLoading(),

        // BedMeshCard(machineUUID: selMachine!.uuid),
        // FirmwareRetractionCard(machineUUID: selMachine!.uuid),
        // MachineStatusCardLoading(),
        // BedMeshCard(machineUUID: selMachine!.uuid),
        // SpoolmanCardLoading(),

        // FansCard(machineUUID: selMachine.uuid),
        // FansCard.loading(),
        // PinsCard(machineUUID: selMachine.uuid),
        // PinsCard.loading(),
        // PowerApiCard(machineUUID: selMachine.uuid),
        // PowerApiCard.loading(),
        // const AdBanner(
        //   constraints: const BoxConstraints(maxHeight: 60),
        //   adSize: AdSize.fluid,
        // ),
        // const _TestAd(),
        // PrinterCard(selMachine),

        OutlinedButton(onPressed: () => v2Activity(ref), child: const Text('V2 activity')),
        OutlinedButton(onPressed: () => startLiveActivity(ref), child: const Text('start activity')),
        OutlinedButton(onPressed: () => updateLiveActivity(ref), child: const Text('update activity')),
        OutlinedButton(
            onPressed: () => ref
                .read(bottomSheetServiceProvider)
                .show(BottomSheetConfig(type: SheetType.userManagement, isScrollControlled: true)),
            child: const Text('UserMngnt')),
        ElevatedButton(
            onPressed: () {
              ref.read(snackBarServiceProvider).show(SnackBarConfig(
                  type: SnackbarType.info,
                  title: 'Purchases restored',
                  message: 'Managed to restore Supporter-Status!'));
            },
            child: const Text('SNACKBAR')),

        // TextButton(onPressed: () => test(ref), child: const Text('Copy Chart OPTIONS')),
        // OutlinedButton(onPressed: () => dummyDownload(), child: const Text('Download file!')),
        // // Expanded(child: WebRtcCam()),
        // AsyncValueWidget(
        //   value: ref.watch(printerSelectedProvider.selectAs((p) => p.bedMesh)),
        //   data: (data) => getMeshChart(data),
        // ),
      ],
    );


    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev'),
      ),
      drawer: const NavigationDrawerWidget(),
      body: body,
    );
  }

  Package anualDummy() {
    final poC = PresentedOfferingContext('default_v2', null, null);

    // Create the Period object for billing

    final defaultPricing = PricingPhase(
        Period(PeriodUnit.year, 1, 'P1Y'), RecurrenceMode.infiniteRecurring, 0, Price('€21.99', 21990000, 'EUR'), null);
    final freePhase = PricingPhase(Period(PeriodUnit.day, 7, 'P7D'), RecurrenceMode.nonRecurring, 1,
        Price('€0', 0, 'EUR'), OfferPaymentMode.freeTrial);
    final discountedPhase = PricingPhase(Period(PeriodUnit.month, 1, 'P1M'), RecurrenceMode.finiteRecurring, 3,
        Price('€0.50', 500000, 'EUR'), OfferPaymentMode.discountedRecurringPayment);

// Create the PricingPhase object

// Create the main SubscriptionOption object
    final subscriptionOption = SubscriptionOption(
      '2199-1y',
      'mobileraker_supporter_v2:2199-1y',
      'mobileraker_supporter_v2',
      [freePhase, discountedPhase, defaultPricing],
      [],
      false,
      Period(PeriodUnit.year, 1, 'P1Y'),
      false,
      defaultPricing,
      freePhase,
      discountedPhase,
      poC,
      null,
    );

    var storeProduct = StoreProduct(
      'STORE_ID',
      'Yes a description givne by the store API',
      'The title ANUAL',
      21.99,
      '€21.99',
      '€',
      productCategory: ProductCategory.subscription,
      defaultOption: subscriptionOption,
    );
    return Package(r'$rc_annual', PackageType.annual, storeProduct, poC);
  }

  Package normalMonthly() {
    final poC = PresentedOfferingContext('default_v2', null, null);

    // Create the Period object for billing

    final defaultPricing = PricingPhase(
        Period(PeriodUnit.month, 1, 'P1M'), RecurrenceMode.infiniteRecurring, 0, Price('€1.99', 1990000, 'EUR'), null);
// Create the PricingPhase object

// Create the main SubscriptionOption object
    final subscriptionOption = SubscriptionOption(
      '200-1m',
      'mobileraker_supporter_v2:2199-1m',
      'mobileraker_supporter_v2',
      [defaultPricing],
      [],
      false,
      Period(PeriodUnit.month, 1, 'P1M'),
      false,
      defaultPricing,
      null,
      null,
      poC,
      null,
    );

    var storeProduct = StoreProduct(
      'STORE_ID',
      'Yes a description givne by the store API',
      'The title ANUAL',
      1.99,
      '€1.99',
      '€',
      productCategory: ProductCategory.subscription,
      defaultOption: subscriptionOption,
    );
    return Package(r'$rc_monthly', PackageType.monthly, storeProduct, poC);
  }

  stateActivity() async {
    final liveActivitiesPlugin = LiveActivities();
    logger.i('#1');
    await liveActivitiesPlugin.init(appGroupId: 'group.mobileraker.liveactivity');
    logger.i('#2');
    var activityState = await liveActivitiesPlugin.getActivityState('123123');
    logger.i('Got state message: $activityState');
  }

  v2Activity(WidgetRef ref) async {
    ref.read(v2LiveActivityProvider).initialize();
  }

  final customID = "338e8845-0cc9-42fa-810f-b09bba7469cc";

  startLiveActivity(WidgetRef ref) async {
    ref.read(liveActivityServiceProvider).disableClearing();
    var liveActivities = ref.read(liveActivityProvider);

    // _liveActivitiesPlugin.activityUpdateStream.listen((event) {
    //   logger.wtf('xxxLiveActivityUpdate: $event');
    // });

    Map<String, dynamic> data = {
      'progress': 0.2,
      'state': 'printing',
      'file': 'Benchy.gcode' ?? 'Unknown',
      'eta': DateTime.now().add(const Duration(seconds: 60 * 200)).secondsSinceEpoch ?? -1,

      // Not sure yet if I want to use this
      'printStartTime': DateTime.now().secondsSinceEpoch ?? -1,

      // Labels
      'primary_color_dark': Colors.yellow.value,
      'primary_color_light': Colors.pinkAccent.value,
      'machine_name': 'Voronator',
      'eta_label': tr('pages.dashboard.general.print_card.eta'),
      'elapsed_label': tr('pages.dashboard.general.print_card.elapsed'),
      'remaining_label': tr('pages.dashboard.general.print_card.remaining'),
      for (var state in PrintState.values) '${state.name}_label': state.displayName,
    };

    var activityId = await liveActivities.createOrUpdateActivity(
      "ff8e8845-0cc9-42fa-810f-b09bba7469ff",
      data,
      removeWhenAppIsKilled: true,
    );
    logger.i('Created activity with id: $activityId');
    _bla = activityId;
    var pushToken = await liveActivities.getPushToken(activityId!);
    logger.i('LiveActivity PushToken: $pushToken');
  }

  updateLiveActivity(WidgetRef ref) async {
    var liveActivities = ref.read(liveActivityProvider);
    // _liveActivitiesPlugin.activityUpdateStream.listen((event) {
    //   logger.wtf('xxxLiveActivityUpdate: $event');
    // });

    Map<String, dynamic> data = {
      'progress': 1,
      'state': 'printing',
      'file':
          'Some/more/more/more/more/long/er/Very-Long/Folder-Strct/here/now/even/miore../asd/12--222--2m-22Benchy.gcode' ??
              'Unknown',
      // 'file': 'Benchy.gcode' ?? 'Unknown',
      'eta': DateTime.now().add(const Duration(seconds: 60 * 20)).secondsSinceEpoch ?? -1,

      // Not sure yet if I want to use this
      'printStartTime': DateTime.now().secondsSinceEpoch ?? -1,

      // Labels
      'primary_color_dark': Colors.lightBlueAccent.value,
      'primary_color_light': Colors.blueGrey.value,
      'machine_name': 'Voronator',
      'eta_label': tr('pages.dashboard.general.print_card.eta'),
      'elapsed_label': tr('pages.dashboard.general.print_card.elapsed'),
      'remaining_label': tr('pages.dashboard.general.print_card.remaining'),
      'completed_label': tr('general.completed'),
    };
    // if (_bla == null) return;
    // var activityId = await liveActivities.updateActivity(
    //   _bla!,
    //   data,
    // );

    await liveActivities.createOrUpdateActivity(
      customID,
      data,
    );
    logger.i('UPDATED activity with customID: $customID');
    // logger.i('UPDATED activity with id: $_bla -> $activityId');
  }

//   var test = 44.4;
//   var dowloadUri = Uri.parse('http://192.168.178.135/server/files/timelapse/file_example_MP4_1920_18MG.mp4');
//   final tmpDir = await getTemporaryDirectory();
//   final tmpFile = File('${tmpDir.path}/$filess');
//
//   workerManager.executeWithPort<File, double>((port) async {
//     await setupIsolateLogger();
//     return isolateDownloadFile(port: port, targetUri: dowloadUri, downloadPath: tmpFile.path);
//   }, onMessage: (message) {
//     logger.i('Got new message from port: $message');
//   }).then((value) => logger.i('Execute done: ${value}'));
// }
}

void dummyDownload() async {
  final tmpDir = await getTemporaryDirectory();
  final File file = File('${tmpDir.path}/dummy.zip');

  var dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // Some file that is rather "large" and takes longer to download
  var uri = 'https://github.com/cfug/flutter.cn/archive/refs/heads/main.zip';

  var response = await dio.download(
    uri,
    file.path,
    onReceiveProgress: (received, total) {
      logger.i('Received: $received, Total: $total');
    },
  );
  print('Download is done: ${response.statusCode}');
}

@riverpod
Stream<(int, int)> caseA(CaseARef ref) {
  logger.i('Creating caseA stream');
  return Stream.periodic(const Duration(seconds: 1), (x) => (x, x * 2));
}

@riverpod
class CaseB extends _$CaseB {
  @override
  int build() {
    logger.i('Building caseB');
    var v = ref.watch(caseAProvider.select((d) => d.valueOrNull?.$1));

    return v ?? -1;
  }
}

class _TestAd extends ConsumerWidget {
  const _TestAd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var ad = ref.watch(bannerAdProvider(AdSize.banner, AdBlockUnit.homeBanner));

    if (ad case AsyncData(value: AdWithView() && final banner)) {
      logger.i('Got ad: ${banner.responseInfo}');
      return SizedBox(
        height: AdSize.banner.height.toDouble(),
        width: AdSize.banner.width.toDouble(),
        child: AdWidget(ad: banner),
      );
    }

    logger.i('No ad available');
    return const SizedBox.shrink();
  }
}

class _IabTCTSTATUS extends ConsumerWidget {
  const _IabTCTSTATUS({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(onPressed: onPressed, child: Text('IAB TCT STATUS'));
  }

  void onPressed() async {
    logger.i('Trying to get IATCFT status');
    ConsentInfo? currentConsentInfo = (await IabtcfConsentInfo.instance.currentConsentInfo()) as ConsentInfo?;
    logger.i('Got IABTCT status: $currentConsentInfo');

    logger.i('PurposeConsents:');
    currentConsentInfo?.purposeConsents.forEach((v) => logger.i('\t\t- ${v}'));

    logger.i('PurposeLegitimateInterests:');
    currentConsentInfo?.purposeLegitimateInterests.forEach((v) => logger.i('\t\t- ${v}'));

    logger.i('publisherConsents:');
    currentConsentInfo?.publisherConsents.forEach((v) => logger.i('\t\t- ${v}'));

    logger.i('publisherLegitimateInterests:');
    currentConsentInfo?.publisherLegitimateInterests.forEach((v) => logger.i('\t\t- ${v}'));
  }
}

class _Consent extends ConsumerWidget {
  const _Consent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: onPressed,
      child: const Text('Consent'),
      onLongPress: () {
        var read = ref.read(consentServiceProvider);

        read.resetUser();

        onLong();
      },
    );
  }

  void onLong() {
    logger.i('Resetting consent');
    ConsentInformation.instance.reset();
  }

  void onPressed() {
    final params = ConsentRequestParameters(consentDebugSettings: ConsentDebugSettings());

    logger.i('ConsentFormAvailable: ${ConsentInformation.instance.isConsentFormAvailable()}');
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        final canShowAd = await ConsentInformation.instance.canRequestAds();
        logger.i('CanShowAd: $canShowAd');

        logger.i('ConsentStatusSuccess');
        final status = await ConsentInformation.instance.getConsentStatus();
        logger.i('ConsentStatus: $status');

        // ConsentForm.loadConsentForm((_) {
        //   logger.i('ConsentForm success: $_');
        // }, (FormError error) {
        //   logger.e('ConsentFormError: ${error.message}');
        // },);

        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) => logger.w('ConsentFormDismissed: ${_?.message}'));
        }

        // ConsentForm.showPrivacyOptionsForm((_) => null);

        var privacyOptionsRequirementStatus = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();

        logger.i('isPrivacyOptionsRequired-(PrivacyOptionsRequirementStatus): $privacyOptionsRequirementStatus');
      },
      (FormError error) {
        logger.e('ConsentStatusError: $error');
        // Handle the error.
      },
    );
  }
}

class FeatureSectionHeader extends StatelessWidget {
  const FeatureSectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Supporter Count Badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Headline
              Text(
                "Become a Mobileraker Supporter!",
                style: themeData.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Gap(4),
              // Description

              Text(
                "Mobileraker provides a fast and reliable mobile Ul for Klipper, inspired by the maker community. While essential features remain free, premium features and an ad-free experience are available to supporters.",
                style: themeData.textTheme.bodySmall,
              ),
              // Text(
              //   "Help keep Mobileraker free for everyone while unlocking premium features for yourself",
              //   style: themeData.textTheme.bodySmall,
              // ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, color: Colors.yellow[700], size: 20),
              const SizedBox(width: 6),
              const Text(
                "4.8/5 on App Store",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(FlutterIcons.github_alt_faw5d, size: 15, color: themeData.textTheme.bodySmall?.color),
                  Gap(4),
                  Text("Open Core", style: themeData.textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 15, color: themeData.textTheme.bodySmall?.color),
                  Gap(4),
                  Text("20k+ users", style: themeData.textTheme.bodySmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(FlutterIcons.console_line_mco, size: 15, color: themeData.textTheme.bodySmall?.color),
                  Gap(4),
                  Text(
                    "Active Dev",
                    style: themeData.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Ratings & User Count Badge
      ],
    );
  }
}

class PaywallFooter extends StatelessWidget {
  const PaywallFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 4,
      children: [
        Text('Join the growing community of Mobileraker supporters', style: Theme.of(context).textTheme.bodySmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {},
              child: Text('Restore Purchase'),
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.bodySmall,
                iconSize: 10,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text('Cancel Subscription'),
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.bodySmall,
                iconSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
