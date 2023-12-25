/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:common/service/firebase/auth.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_auth/firebase_auth.dart' show AuthCredential;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth/firebase_ui_oauth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:mobileraker/ui/components/warning_card.dart';
import 'package:purchases_flutter/errors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_bottom_sheet.freezed.dart';
part 'user_bottom_sheet.g.dart';

class UserBottomSheet extends StatefulHookWidget {
  const UserBottomSheet({super.key});

  @override
  State<UserBottomSheet> createState() => _UserBottomSheetState();
}

class _UserBottomSheetState extends State<UserBottomSheet> {
  final DraggableScrollableController _controller = DraggableScrollableController();

  EdgeInsets _viewInsets = EdgeInsets.zero;
  double? _originalSize;
  double? _originalScrollOffset;

  @override
  Widget build(BuildContext _) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.2,
      controller: _controller,
      builder: (_, scrollController) {
        return HookBuilder(builder: (context) {
          _viewInsets = MediaQuery.viewInsetsOf(context);

          useEffect(
            () {
              var keyboardHeight = _viewInsets.bottom;
              if (keyboardHeight == 0 && _originalSize == null) return;

              double size;
              if (keyboardHeight == 0) {
                size = _originalSize!;
                _originalSize = null;
                logger.i('Restoring size to $_originalSize');
              } else {
                size = _controller.pixelsToSize(keyboardHeight) + _controller.size;
                _originalSize ??= _controller.size;
                logger.i('Bottom insets: ${keyboardHeight} => $size');
              }

              _controller.animateTo(
                min(1, size),
                duration: kThemeAnimationDuration,
                curve: Curves.easeOut,
              );

              if (FocusManager.instance.primaryFocus == null) return;

              final widgetHeight = FocusManager.instance.primaryFocus!.size.height;
              final widgetOffset = FocusManager.instance.primaryFocus!.offset.dy;
              final screenHeight = MediaQuery.sizeOf(context).height;

              final targetWidgetOffset = screenHeight - keyboardHeight - widgetHeight - 20;
              final valueToScroll = widgetOffset - targetWidgetOffset;

              double scrollOffset;
              if (keyboardHeight == 0) {
                scrollOffset = _originalScrollOffset!;
                _originalScrollOffset = null;
              } else {
                scrollOffset = scrollController.offset + valueToScroll;
                _originalScrollOffset ??= scrollController.offset;
              }

              if (valueToScroll > 0 || _originalScrollOffset == null) {
                scrollController.animateTo(
                  scrollOffset,
                  duration: kThemeAnimationDuration,
                  curve: Curves.ease,
                );
              }
            },
            [_viewInsets.bottom],
          );

          return SafeArea(
            child: Column(
              // mainAxisSize: MainAxisSize.min, // To make the card compact
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView(
                      shrinkWrap: true,
                      controller: scrollController,
                      children: [
                        Consumer(
                          builder: (BuildContext context, WidgetRef ref, Widget? child) {
                            return ref.watch(_userBottomSheetControllerProvider).when(
                                  data: (data) => _CardBody(model: data),
                                  error: (_, __) => const ErrorCard(
                                    title: Text('Error loading User management'),
                                    body: Text(
                                        'An unexpected error occured while loading the User management. Please try again later.'),
                                  ),
                                  loading: () => const CircularProgressIndicator.adaptive(),
                                );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const AnimatedSize(duration: kThemeAnimationDuration, child: _InfoText()),
                ElevatedButton.icon(
                  label: Text(MaterialLocalizations.of(context).closeButtonTooltip),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key, required this.model});

  final _Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var auth = ref.watch(authProvider);

    // return SignInScreen();

    return (model.user == null)
        ? Padding(
            padding: const EdgeInsets.all(30),
            child: LoginView(
              action: AuthAction.signIn,
              providers: model.providers,
              auth: auth,
              showAuthActionSwitch: true,
              subtitleBuilder: (context, __) => const Text('bottom_sheets.signIn.subtitle').tr(),
              footerBuilder: (context, __) => const _RestoreButton(),
            ),
          )
        : const _Profile();
  }

// void _animateToFocused(ScrollController controller) {
//   if (FocusManager.instance.primaryFocus == null || _isClosing) return;
//
//   _widgetBinding.addPostFrameCallback((_) {
//     final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
//     final widgetHeight = FocusManager.instance.primaryFocus!.size.height;
//     final widgetOffset = FocusManager.instance.primaryFocus!.offset.dy;
//     final screenHeight = MediaQuery.sizeOf(context).height;
//
//     final targetWidgetOffset =
//         screenHeight - keyboardHeight - widgetHeight - 20;
//     final valueToScroll = widgetOffset - targetWidgetOffset;
//     final currentOffset = controller.offset;
//     if (valueToScroll > 0) {
//       controller.animateTo(
//         currentOffset + valueToScroll,
//         duration: const Duration(milliseconds: 200),
//         curve: Curves.ease,
//       );
//     }
//   });
// }

// Future<void> _signInWithDifferentProvider(
//     BuildContext context,
//     DifferentSignInMethodsFound state,
//     ) async {
//   await showDifferentMethodSignInDialog(
//     availableProviders: state.methods,
//     providers: providers,
//     context: context,
//     auth: auth,
//     onSignedIn: () {
//       Navigator.of(context).pop();
//     },
//   );
//
//   await auth.currentUser!.linkWithCredential(state.credential!);
// }
}

class _Profile extends ConsumerWidget {
  const _Profile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_userBottomSheetControllerProvider.notifier);
    var model = ref.watch(_userBottomSheetControllerProvider).requireValue;

    var themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // _EmailVerificationBadge(),
          SvgPicture.asset(
            'assets/vector/mr_logo.svg',
            width: 100,
            height: 100,
          ),
          const Align(child: EditableUserDisplayName()),
          const _EmailVerification(),
          const SizedBox(height: 8),
          Text(
            'bottom_sheets.profile.title',
            style: themeData.textTheme.headlineSmall,
          ).tr(),
          Text(
            'bottom_sheets.profile.description',
            style: themeData.textTheme.bodyMedium,
          ).tr(),

          // Padding(
          //   padding: const EdgeInsets.only(top: 32),
          //   child: _AvailableProvidersRow(
          //     providers: model.availableProviders,
          //     onProviderLinked: controller.onLinkedProviderChanged,
          //   ),
          // ),
          const SizedBox(height: 16),

          if (model.errorText != null)
            Text(
              model.errorText!,
              textAlign: TextAlign.center,
              style: TextStyle(color: themeData.colorScheme.error),
            ),
          const _RestoreButton(),
          AsyncOutlinedButton.icon(
            onPressed: controller.signOut,
            label: const Text('bottom_sheets.profile.sign_out').tr(),
            icon: const Icon(Icons.logout),
          ),
          AsyncElevatedButton.icon(
            onPressed: controller.deleteAccount,
            label: const Text('bottom_sheets.profile.delete_account').tr(),
            icon: const Icon(Icons.delete_outline),
            style: ElevatedButton.styleFrom(
              foregroundColor: themeData.colorScheme.onError,
              backgroundColor: themeData.colorScheme.error,
            ),
          ),

          // onSignInRequired: () {
          //   return _reauthenticate(context);
          // },
        ],
      ),
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncOutlinedButton.icon(
      onPressed: ref.watch(_userBottomSheetControllerProvider.notifier).restorePurchases,
      label: const Text('bottom_sheets.profile.restore_purchases').tr(),
      icon: const Icon(Icons.restart_alt),
    );
  }
}

class _AvailableProvidersRow extends StatefulWidget {
  /// {@macro ui.auth.auth_controller.auth}
  final fba.FirebaseAuth? auth;
  final List<AuthProvider> providers;
  final VoidCallback onProviderLinked;

  const _AvailableProvidersRow({
    this.auth,
    required this.providers,
    required this.onProviderLinked,
  });

  @override
  State<_AvailableProvidersRow> createState() => _AvailableProvidersRowState();
}

class _AvailableProvidersRowState extends State<_AvailableProvidersRow> {
  AuthFailed? error;

  Future<void> connectProvider({
    required BuildContext context,
    required AuthProvider provider,
  }) async {
    setState(() {
      error = null;
    });

    switch (provider.providerId) {
      case 'phone':
        await startPhoneVerification(
          context: context,
          action: AuthAction.link,
          auth: widget.auth,
        );
        break;
      case 'password':
        await showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: '',
          pageBuilder: (context, _, __) {
            return EmailSignUpDialog(
              provider: provider as EmailAuthProvider,
              auth: widget.auth,
              action: AuthAction.link,
            );
          },
        );
    }

    await (widget.auth ?? fba.FirebaseAuth.instance).currentUser!.reload();
  }

  @override
  Widget build(BuildContext context) {
    final providers = widget.providers.where((provider) => provider is! EmailLinkAuthProvider).toList();

    Widget child = Row(
      children: [
        for (var provider in providers)
          if (provider is! OAuthProvider)
            IconButton(
              icon: Icon(
                providerIcon(context, provider.providerId),
              ),
              onPressed: () => connectProvider(
                context: context,
                provider: provider,
              ).then((_) => widget.onProviderLinked()),
            )
          else
            AuthStateListener<OAuthController>(
              listener: (oldState, newState, controller) {
                if (newState is CredentialLinked) {
                  widget.onProviderLinked();
                } else if (newState is AuthFailed) {
                  setState(() => error = newState);
                }
                return null;
              },
              child: OAuthProviderButton(
                provider: provider,
                auth: widget.auth,
                action: AuthAction.link,
                variant: OAuthButtonVariant.icon,
              ),
            ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('More', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ErrorText(exception: error!.exception),
          ),
      ],
    );
  }
}

class _EmailVerification extends HookConsumerWidget {
  const _EmailVerification({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var auth = ref.watch(authProvider);
    var emailVerifyController = useValueNotifier(EmailVerificationController(auth));

    EmailVerificationState state = useValueListenable(emailVerifyController.value);

    var show = state != EmailVerificationState.dismissed &&
        state != EmailVerificationState.unresolved &&
        state != EmailVerificationState.verified;

    var showPending = state == EmailVerificationState.pending || state == EmailVerificationState.sending;

    var platform = Theme.of(context).platform;

    Future<void> verifyMail() => emailVerifyController.value.sendVerificationEmail(platform, null);

    return WarningCard(
      show: show,
      leadingIcon: Icon(showPending ? Icons.mark_email_unread_outlined : Icons.email_outlined),
      title: Text(
        'bottom_sheets.profile.email_verification.title',
        style: Theme.of(context).textTheme.titleMedium,
      ).tr(gender: showPending ? 'pending' : 'not_verified'),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('bottom_sheets.profile.email_verification.description').tr(),
          Align(
            alignment: Alignment.centerRight,
            child: AsyncElevatedButton(
              onPressed: verifyMail,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(fontWeight: FontWeight.w400),
                foregroundColor: Theme.of(context).colorScheme.errorContainer,
                backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              child: const Text('bottom_sheets.profile.email_verification.send').tr(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoText extends ConsumerWidget {
  const _InfoText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_userBottomSheetControllerProvider.selectAs((d) => d.infoText)).valueOrNull;
    if (model == null) return SizedBox.shrink();

    var themeData = Theme.of(context);

    return ListTile(
      tileColor: themeData.colorScheme.tertiaryContainer,
      textColor: themeData.colorScheme.onTertiaryContainer,
      iconColor: themeData.colorScheme.onTertiaryContainer,
      title: Text(model),
      // subtitle: Text(model),
    );
  }
}

@riverpod
class _UserBottomSheetController extends _$UserBottomSheetController {
  fba.FirebaseAuth get _auth => ref.read(authProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PaymentService get _paymentService => ref.read(paymentServiceProvider);

  @override
  Stream<_Model> build() async* {
    logger.i('Rebuilding UserBottomSheetController');
    var wAuth = ref.watch(authProvider);
    var providers = FirebaseUIAuth.providersFor(wAuth.app);
    yield* ref.watchAsSubject(firebaseUserProvider).map((user) {
      return _Model(user: user, providers: providers);
    });
  }

  void onLinkedProviderChanged() {
    logger.i('onLinkedProviderChanged');
    ref.invalidateSelf();
  }

  Future<void> signOut() {
    return FirebaseUIAuth.signOut(auth: _auth).catchError((e) {
      logger.e('Error signing out', e);
      state = state.whenData((value) =>
          value.copyWith(errorText: 'An unexpected error occured while signing out. Please try again later.'));
    });
  }

  Future<void> deleteAccount() async {
    var usr = state.valueOrNull?.user;
    if (usr == null) return;

    var result = await _dialogService.showConfirm(
      title: tr('bottom_sheets.profile.delete_account_dialog.title'),
      body: tr('bottom_sheets.profile.delete_account_dialog.body'),
      confirmBtn: tr('general.delete'),
      confirmBtnColor: Colors.red,
    );

    if (result?.confirmed != true) return;

    try {
      usr.delete();
    } catch (e) {
      logger.e('Error deleting user account', e);
      state = state.whenData((value) => value.copyWith(
          errorText: 'An unexpected error occured while deleting your account. Please try again later.'));
    }
  }

  Future<void> restorePurchases() async {
    await _paymentService.restorePurchases(passErrors: true, showSnacks: false).catchError((e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      logger.e('Error restoring purchases. Error code: $errorCode');
      state = state.whenData(
          (value) => value.copyWith(errorText: 'An unexpected error occured while restoring purchases.\n$errorCode'));
    });
    _showInfoText(tr('bottom_sheets.profile.restore_success'));
  }

  _showInfoText(String text, [int seconds = 5]) async {
    state = state.whenData((value) => value.copyWith(infoText: text));
    await Future.delayed(Duration(seconds: seconds));
    state = state.whenData((value) => value.copyWith(infoText: null));
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    @Default([]) List<AuthProvider> providers,
    required fba.User? user,
    String? errorText,
    String? infoText,
  }) = __Model;

  List<AuthProvider> get linkedProviders {
    if (user == null) return [];
    return providers.where((provider) => user!.isProviderLinked(provider.providerId)).toList();
  }

  List<AuthProvider> get availableProviders {
    if (user == null) return [];

    return providers.whereNot((provider) => user!.isProviderLinked(provider.providerId)).toList();
  }
}
