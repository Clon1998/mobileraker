/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:pem/pem.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ssl_settings.freezed.dart';
part 'ssl_settings.g.dart';

class SslSettings extends HookConsumerWidget {
  const SslSettings({super.key, this.initialCertificateDER, this.initialTrustSelfSigned = false});

  final String? initialCertificateDER;
  final bool initialTrustSelfSigned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = sslSettingsControllerProvider(initialCertificateDER, initialTrustSelfSigned);
    var model = ref.watch(provider);
    var controller = ref.watch(provider.notifier);

    var textController = useTextEditingController(text: model.certificateDER);
    useEffect(
      () {
        if (model.fingerprintSHA256 == null) {
          textController.clear();
        } else {
          textController.text = model.fingerprintSHA256!.toUpperCase();
        }
        return null;
      },
      [model.fingerprintSHA256],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: tr('pages.printer_edit.ssl.title')),
        InputDecorator(
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(0),
          ),
          child: SwitchListTile(
            dense: true,
            isThreeLine: false,
            contentPadding: EdgeInsets.zero,
            title: const Text('pages.printer_edit.ssl.self_signed').tr(),
            value: model.trustSelfSigned || model.fingerprintSHA256 != null,
            onChanged: model.fingerprintSHA256 == null ? (_) => controller.toggleTrustSelfSigned() : null,
            controlAffinity: ListTileControlAffinity.trailing,
          ),
        ),
        Flexible(
          child: TextField(
            canRequestFocus: false,
            controller: textController,
            decoration: InputDecoration(
              labelText: tr('pages.printer_edit.ssl.pin_certificate_label'),
              helperText: tr('pages.printer_edit.ssl.pin_certificate_helper'),
              hintText: 'DER-Encoded Certificate',
              helperMaxLines: 100,
              suffix: model.fingerprintSHA256?.isNotEmpty == true
                  ? DecoratorSuffixIconButton(
                      icon: Icons.close,
                      onPressed: controller.clearCertificate,
                    )
                  : null,
            ),
            readOnly: true,
            onTap: controller.pickCertificate,
          ),
        ),
      ],
    );
  }
}

@riverpod
class SslSettingsController extends _$SslSettingsController {
  @override
  SslSettingsModel build(String? initialCertificateDER, bool initialTrustSelfSigned) {
    bool trustSelfSigned = initialTrustSelfSigned;

    if (initialCertificateDER == null) {
      return SslSettingsModel(certificateDER: null, fingerprintSHA256: null, trustSelfSigned: trustSelfSigned);
    }

    return SslSettingsModel(
      certificateDER: initialCertificateDER,
      fingerprintSHA256: _fingerPrint(initialCertificateDER),
      trustSelfSigned: trustSelfSigned,
    );
  }

  void pickCertificate() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pem', 'crt', 'cer'],
      withReadStream: true,
      withData: false,
    );

    if (result != null) {
      var file = result.files.first;
      var content = await utf8.decodeStream(file.readStream!);

      PemCodec pemCodec = PemCodec(PemLabel.certificate);
      var derBytes = pemCodec.decode(content);
      var base64 = toBase64(derBytes);

      state = SslSettingsModel(
        certificateDER: base64,
        fingerprintSHA256: _fingerPrint(base64),
        trustSelfSigned: state.trustSelfSigned,
      );
    } else {
      // User canceled the picker
      logger.i('User canceled certificate picker');
    }
  }

  void clearCertificate() {
    state = SslSettingsModel(certificateDER: null, fingerprintSHA256: null, trustSelfSigned: state.trustSelfSigned);
  }

  void toggleTrustSelfSigned() {
    state = SslSettingsModel(
      certificateDER: state.certificateDER,
      fingerprintSHA256: state.fingerprintSHA256,
      trustSelfSigned: !state.trustSelfSigned,
    );
  }

  String _fingerPrint(String derB64) {
    var b64 = fromBase64(derB64);

    String hex = sha256.convert(b64).hex();

    return [for (int i = 0; i < hex.length; i += 2) hex.substring(i, i + 2)].join(':');
  }
}

@freezed
class SslSettingsModel with _$SslSettingsModel {
  const factory SslSettingsModel({
    required String? certificateDER,
    required String? fingerprintSHA256,
    @Default(false) bool trustSelfSigned,
  }) = _SslSettingsModel;
}
