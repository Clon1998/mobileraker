/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/firebase/auth.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/ui/components/async_button_.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:purchases_flutter/errors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

part 'user_bottom_sheet.freezed.dart';
part 'user_bottom_sheet.g.dart';

enum _LoginAction { signIn, signUp, forgotPassword }

class UserBottomSheet extends StatelessWidget {
  const UserBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SheetContentScaffold(
      body: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: [
          Flexible(child: SingleChildScrollView(child: _CardBody())),
          // Info box for status messages AKA a snackbar alternative...
          _InfoText(),
          Gap(MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<fba.User?> user = ref.watch(_userBottomSheetControllerProvider.selectAs((d) => d.user));

    final Widget widget = switch (user) {
      AsyncError() => const ErrorCard(
          title: Text('Error loading User management'),
          body: Text(
            'An unexpected error occured while loading the User management. Please try again later.',
          ),
        ),
      AsyncValue(hasValue: true, value: fba.User(isAnonymous: false)) => const _Profile(key: Key('profile')),
      _ => const _Login(key: Key('Login')),
    };

    return AnimatedSizeAndFade(
      alignment: Alignment.topCenter,
      child: widget,
    );
  }
}

class _Login extends HookConsumerWidget {
  const _Login({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = useState(_LoginAction.signIn);
    final stillLoading = ref.watch(_userBottomSheetControllerProvider.select((d) => d.isLoading));
    final controller = ref.watch(_userBottomSheetControllerProvider.notifier);
    final errorText = ref.watch(_userBottomSheetControllerProvider.selectAs((d) => d.errorText)).valueOrNull;

    final String title;
    final String hint;
    final String switchActionText;

    switch (mode.value) {
      case _LoginAction.signIn:
        title = 'bottom_sheets.signIn.action.sign_in';
        hint = 'bottom_sheets.signIn.hint.sign_in';
        switchActionText = 'bottom_sheets.signIn.action.sign_up';
      case _LoginAction.signUp:
        title = 'bottom_sheets.signIn.action.sign_up';
        hint = 'bottom_sheets.signIn.hint.sign_up';
        switchActionText = 'bottom_sheets.signIn.action.sign_in';
      case _LoginAction.forgotPassword:
        title = 'bottom_sheets.signIn.action.reset_password';
        hint = 'bottom_sheets.signIn.hint.reset_password';
        switchActionText = '';
    }

    switchMode(_LoginAction newMode) {
      mode.value = newMode;
      controller.clearErrorText();
    }

    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER
          Text(tr(title), style: themeData.textTheme.headlineSmall),
          const Text('bottom_sheets.signIn.subtitle').tr(),
          if (mode.value != _LoginAction.forgotPassword)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${tr(hint)} ', style: themeData.textTheme.bodySmall),
                  TextSpan(
                    text: tr(switchActionText),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: themeData.colorScheme.primary,
                        ),
                    mouseCursor: SystemMouseCursors.click,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        switch (mode.value) {
                          case _LoginAction.signIn:
                            switchMode(_LoginAction.signUp);
                            break;
                          case _LoginAction.signUp:
                            switchMode(_LoginAction.signIn);
                            break;
                          case _LoginAction.forgotPassword:
                          // Do nothing. We never are in that mode...
                        }
                      },
                  ),
                ],
              ),
            ),
          // BODY
          const SizedBox(height: 8),
          _EmailForm(
            mode: mode.value,
            onSubmit: stillLoading
                ? null
                : (mail, password) {
                    switch (mode.value) {
                      case _LoginAction.signIn:
                        return controller.signIn(mail, password);
                      case _LoginAction.signUp:
                        return controller.signUp(mail, password);
                      case _LoginAction.forgotPassword:
                        return controller.forgotPassword(mail);
                    }
                  },
            onForgotPassword: () {
              switchMode(_LoginAction.forgotPassword);
            },
          ),
          if (errorText != null)
            Text(
              errorText,
              textAlign: TextAlign.center,
              style: TextStyle(color: themeData.colorScheme.error),
            ),
          if (mode.value == _LoginAction.forgotPassword)
            TextButton(
              onPressed: () {
                switchMode(_LoginAction.signIn);
              },
              child: Text(MaterialLocalizations.of(context).backButtonTooltip).tr(),
            ),
          if (mode.value != _LoginAction.forgotPassword) const _RestoreButton(),
        ],
      ),
    );
  }
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
          // const Align(child: EditableUserDisplayName()), !!TODO
          Align(child: Text(model.user?.email ?? '', style: themeData.textTheme.bodySmall)),
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
} //

class _EmailVerification extends HookConsumerWidget {
  const _EmailVerification({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var controller = ref.watch(_userBottomSheetControllerProvider.notifier);

    final isVerified = ref.watch(firebaseUserProvider.selectAs((data) => data?.emailVerified == true));

    final pending = useState(false);

    return WarningCard(
      show: isVerified.hasValue && isVerified.value != true,
      leadingIcon: Icon(pending.value ? Icons.mark_email_unread_outlined : Icons.email_outlined),
      title: Text(
        'bottom_sheets.profile.email_verification.title',
        style: Theme.of(context).textTheme.titleMedium,
      ).tr(gender: pending.value ? 'pending' : 'not_verified'),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('bottom_sheets.profile.email_verification.description').tr(),
          Align(
            alignment: Alignment.centerRight,
            child: AsyncElevatedButton(
              onPressed: () async {
                await controller.verifyMail();
                pending.value = true;
              },
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

    var themeData = Theme.of(context);

    var child = model == null
        ? const SizedBox.shrink()
        : ListTile(
            tileColor: themeData.colorScheme.tertiaryContainer,
            textColor: themeData.colorScheme.onTertiaryContainer,
            iconColor: themeData.colorScheme.onTertiaryContainer,
            title: Text(model),
            // subtitle: Text(model),
          );

    return AnimatedSize(duration: kThemeAnimationDuration, child: child);
  }
}

class _EmailForm extends StatefulWidget {
  const _EmailForm({super.key, required this.mode, this.onSubmit, this.onForgotPassword});

  final _LoginAction mode;

  final FutureOr<void>? Function(String mail, String password)? onSubmit;

  final Function()? onForgotPassword;

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  final _formKey = GlobalKey<FormBuilderState>();

  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();
  final confirmPasswordFocusNode = FocusNode();

  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final String actionText = switch (widget.mode) {
      _LoginAction.signIn => 'bottom_sheets.signIn.action.sign_in',
      _LoginAction.signUp => 'bottom_sheets.signIn.action.sign_up',
      _LoginAction.forgotPassword => 'bottom_sheets.signIn.action.reset_password',
    };

    return AutofillGroup(
      child: FormBuilder(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FormBuilderTextField(
              name: 'email',
              enabled: !_submitting,
              focusNode: emailFocusNode,
              decoration: InputDecoration(
                  labelText: tr('bottom_sheets.signIn.email.label'), hintText: tr('bottom_sheets.signIn.email.hint')),
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
                FormBuilderValidators.email(),
              ]),
              // onSubmitted: (v) {
              //   formKey.currentState?.validate();
              //   FocusScope.of(context).requestFocus(passwordFocusNode);
              // },
              onSubmitted: (v) {
                if (_formKey.currentState?.fields['email']?.validate() == true) {
                  FocusScope.of(context).requestFocus(passwordFocusNode);
                } else {
                  FocusScope.of(context).requestFocus(emailFocusNode);
                }
              },
            ),
            if (widget.mode != _LoginAction.forgotPassword) ...[
              const SizedBox(height: 8),
              FormBuilderTextField(
                name: 'password',
                enabled: !_submitting,
                focusNode: passwordFocusNode,
                decoration: InputDecoration(
                    labelText: tr('bottom_sheets.signIn.password.label'),
                    hintText: tr('bottom_sheets.signIn.password.hint')),
                autofillHints: const [AutofillHints.password],
                obscureText: true,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                ]),
                onSubmitted: (v) {
                  if (_formKey.currentState?.fields['password']?.validate() == true) {
                    if (widget.mode == _LoginAction.signIn) {
                      _action();
                      return;
                    }
                    FocusScope.of(context).requestFocus(confirmPasswordFocusNode);
                  } else {
                    FocusScope.of(context).requestFocus(passwordFocusNode);
                  }
                },
              ),
              if (widget.mode == _LoginAction.signIn)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: widget.onForgotPassword,
                      child: const Text('bottom_sheets.signIn.forgot_password').tr()),
                ),
              if (widget.mode == _LoginAction.signUp) ...[
                const SizedBox(height: 8),
                FormBuilderTextField(
                  name: 'confirmPassword',
                  enabled: !_submitting,
                  focusNode: confirmPasswordFocusNode,
                  decoration: InputDecoration(
                      labelText: tr('bottom_sheets.signIn.confirm_password.label'),
                      hintText: tr('bottom_sheets.signIn.confirm_password.hint')),
                  autofillHints: const [AutofillHints.password],
                  obscureText: true,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    (val) {
                      if (_formKey.currentState?.fields['password']?.validate(focusOnInvalid: false) != true ||
                          val != _formKey.currentState?.fields['password']?.value) {
                        return tr('bottom_sheets.signIn.confirm_password.error');
                      }
                      return null;
                    },
                  ]),
                  onSubmitted: (v) {
                    if (_formKey.currentState?.fields['confirmPassword']?.validate() != true) {
                      FocusScope.of(context).requestFocus(confirmPasswordFocusNode);
                    } else {
                      _action();
                    }
                  },
                ),
              ],
            ],
            const SizedBox(height: 8),
            AsyncOutlinedButton(onPressed: _action.only(widget.onSubmit != null), child: Text(actionText).tr()),
          ],
        ),
      ),
    );
  }

  Future<void> _action() async {
    setState(() {
      _submitting = true;
    });
    try {
      if (_formKey.currentState?.saveAndValidate() != true) return;

      var values = _formKey.currentState?.value;
      if (values == null) return;
      var email = values['email'] as String;

      if (widget.mode == _LoginAction.forgotPassword) {
        if (widget.onSubmit != null) {
          await widget.onSubmit!(email, '');
        }
        return;
      }

      var password = values['password'] as String;

      if (widget.onSubmit != null) {
        await widget.onSubmit!(email, password);
      }
    } finally {
      setState(() {
        _submitting = false;
      });
    }
    // await _action(email, password, isSignUp);
  }

  @override
  void dispose() {
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    confirmPasswordFocusNode.dispose();
    super.dispose();
  }
}

@riverpod
class _UserBottomSheetController extends _$UserBottomSheetController {
  fba.FirebaseAuth get _auth => ref.read(authProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  PaymentService get _paymentService => ref.read(paymentServiceProvider);

  @override
  Future<_Model> build() async {
    talker.info('Rebuilding UserBottomSheetController');
    var user = await ref.watch(firebaseUserProvider.future);
    return _Model(user: user);
  }

  void onLinkedProviderChanged() {
    talker.info('onLinkedProviderChanged');
    ref.invalidateSelf();
  }

  Future<void> signIn(String email, String password) async {
    clearErrorText();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      talker.error('Error signing in', e);
      state = state.whenData((value) => value.copyWith(errorText: e.message));
    } catch (e) {
      talker.error('Error signing in', e);
      state = state.whenData((value) =>
          value.copyWith(errorText: 'An unexpected error occured while signing in. Please try again later.'));
    }
  }

  Future<void> signUp(String email, String password) async {
    clearErrorText();
    try {
      var user = state.value?.user;
      if (user?.isAnonymous == true) {
        var credential = EmailAuthProvider.credential(email: email, password: password);
        talker.info('Linking anonymous user to email');
        await user!.linkWithCredential(credential);
      } else if (user == null) {
        talker.info('Creating new user with email');
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      talker.error('AuthError while trying to Sign-Up', e);
      state = state.whenData((value) => value.copyWith(errorText: e.message));
    } catch (e) {
      talker.error('Unexpected error while trying to Sign-Up', e);
      state = state.whenData((value) =>
          value.copyWith(errorText: 'An unexpected error occured while registering. Please try again later.'));
    }
  }

  Future<void> signOut() {
    clearErrorText();
    return _auth.signOut().catchError((e) {
      talker.error('Error signing out', e);
      state = state.whenData((value) =>
          value.copyWith(errorText: 'An unexpected error occured while signing out. Please try again later.'));
    });
  }

  Future<void> verifyMail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      talker.error('Error sending email verification', e);
      state = state.whenData((value) => value.copyWith(errorText: e.message));
    } catch (e) {
      talker.error('Error sending email verification', e);
      state = state.whenData((value) => value.copyWith(
          errorText: 'An unexpected error occured while sending the email verification. Please try again later.'));
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      talker.info('Sending password reset email to $email');
      await _auth.sendPasswordResetEmail(email: email);
      _showInfoText(tr('bottom_sheets.signIn.forgot_password_success'));
    } on FirebaseAuthException catch (e) {
      talker.error('Error sending password reset email', e);
      state = state.whenData((value) => value.copyWith(errorText: e.message));
    } catch (e) {
      talker.error('Error sending password reset email', e);
      state = state.whenData((value) => value.copyWith(
          errorText: 'An unexpected error occured while sending the password reset email. Please try again later.'));
    }
  }

  Future<void> deleteAccount() async {
    var usr = state.valueOrNull?.user;
    if (usr == null) return;

    var result = await _dialogService.showDangerConfirm(
      title: tr('bottom_sheets.profile.delete_account_dialog.title'),
      body: tr('bottom_sheets.profile.delete_account_dialog.body'),
      actionLabel: tr('general.delete'),
    );

    if (result?.confirmed != true) return;

    try {
      usr.delete();
    } catch (e) {
      talker.error('Error deleting user account', e);
      state = state.whenData((value) => value.copyWith(
            errorText: 'An unexpected error occured while deleting your account. Please try again later.',
          ));
    }
  }

  Future<void> restorePurchases() async {
    await _paymentService.restorePurchases(passErrors: true, showSnacks: false).catchError((e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      talker.error('Error restoring purchases. Error code: $errorCode');
      state = state.whenData(
        (value) => value.copyWith(errorText: 'An unexpected error occured while restoring purchases.\n$errorCode'),
      );
    });
    _showInfoText(tr('bottom_sheets.profile.restore_success'));
  }

  _showInfoText(String text, [int seconds = 5]) async {
    state = state.whenData((value) => value.copyWith(infoText: text));
    await Future.delayed(Duration(seconds: seconds));
    state = state.whenData((value) => value.copyWith(infoText: null));
  }

  clearErrorText() {
    if (state.valueOrNull?.errorText != null) {
      state = state.whenData((value) => value.copyWith(errorText: null));
    }
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required fba.User? user,
    String? errorText,
    String? infoText,
  }) = __Model;
}
