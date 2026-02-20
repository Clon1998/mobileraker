/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:pem/pem.dart';

part 'ssl_settings_form_field.freezed.dart';

class SslSettingsFormField extends StatelessWidget {
  const SslSettingsFormField({
    super.key,
    required this.name,
    this.initialCertificateDER,
    this.initialTrustSelfSigned = false,
  });

  final String name;
  final String? initialCertificateDER;
  final bool initialTrustSelfSigned;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<SslSettings>(
      name: name,
      initialValue: SslSettings(
        certificateDER: initialCertificateDER,
        fingerprintSHA256: initialCertificateDER?.let(_fingerPrint),
        trustSelfSigned: false,
      ),
      builder: (FormFieldState<SslSettings> field) {
        final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled?? true);

        final SslSettings model =
            field.value ??
                SslSettings();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionHeader(title: tr('pages.printer_edit.ssl.title')),
            InputDecorator(
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(0)),
              child: SwitchListTile(
                dense: true,
                isThreeLine: false,
                contentPadding: EdgeInsets.zero,
                title: const Text('pages.printer_edit.ssl.self_signed').tr(),
                // If we have a pinned cert, we always trust it!
                value: model.trustSelfSigned || model.fingerprintSHA256 != null,
                onChanged: ((v) =>
                    field.didChange(
                      model.copyWith(trustSelfSigned: v),
                    )).only(model.fingerprintSHA256 == null && enabled),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ),
            Flexible(
              child: GestureDetector(
                onTap: (() =>
                    FilePicker.platform
                        .pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pem', 'crt', 'cer'],
                      withReadStream: true,
                      withData: false,
                    )
                        .then((result) async {
                      if (result != null) {
                        final file = result.files.first;
                        final content = await utf8.decodeStream(file.readStream!);
                        if (!field.mounted) return;

                        PemCodec pemCodec = PemCodec(PemLabel.certificate);
                        final derBytes = pemCodec.decode(content);
                        final certDER = toBase64(derBytes);
                        final certFP = _fingerPrint(certDER);

                        field.didChange(model.copyWith(certificateDER: certDER, fingerprintSHA256: certFP));
                      }
                    })).only(enabled),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: tr('pages.printer_edit.ssl.pin_certificate_label'),
                    helperText: tr('pages.printer_edit.ssl.pin_certificate_helper'),
                    hintText: 'DER-Encoded Certificate',
                    helperMaxLines: 100,
                    suffix: model.fingerprintSHA256?.isNotEmpty == true
                        ? DecoratorSuffixIconButton(
                      icon: Icons.close,
                      onPressed: (() =>
                          field.didChange(
                            model.copyWith(
                              certificateDER: null,
                              fingerprintSHA256: null,
                              trustSelfSigned: model.trustSelfSigned,
                            ),
                          )).only(enabled),
                    )
                        : null,
                  ),
                  child: Text(model.certificateDER ?? ''),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _fingerPrint(String derB64) {
    var b64 = fromBase64(derB64);

    String hex = sha256.convert(b64).hex();

    return [for (int i = 0; i < hex.length; i += 2) hex.substring(i, i + 2)].join(':');
  }
}

@freezed
sealed class SslSettings with _$SslSettings {
  const factory SslSettings({
    String? certificateDER,
    String? fingerprintSHA256,
    @Default(false) bool trustSelfSigned,
  }) = _SslSettings;
}
