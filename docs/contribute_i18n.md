# How to Translate Mobileraker 🌐

Mobileraker already supports multiple languages, but it relies on contributions to add new languages and keep existing
translations up to date. If you want to add your own language or update an existing one, please feel free to open a Pull
Request (PR). This guide provides details on the structure of translation keys and how to add a new language.

## Translation Format 📜

This section outlines the format of the translation files and keys.

### Language Files 🌍

All available language files can be found in the `assets/translations` directory. Each file adheres to the BCP 47 (IETF
language tag) standard, consisting of a language code (e.g., 'en' for English, 'de' for German) and, if necessary, a
region or country code (e.g., 'zh-CN' for Chinese in mainland China, 'zh-HK' for Chinese in Hong Kong). These language
files are in JSON format to organize the translations efficiently.

### Language Keys 🔑

Within each file, key-value pairs are used for translation. The value associated with each key can be either another
collection of key-value pairs or a string that contains the translation. To translate a file, you only need to modify
the string values.

String values can take several forms:

- Simple Text: For example, `"translation_key": "I am a text to translate."`

- Text with Arguments: For example, `"translation_key": "I am a text to translate in language {}."`

- Text with [Linked Translations](https://github.com/aissat/easy_localization#-linked-translations): For
  example, `"translation_key": "@:example.hello User! How are you?"`. This means an already defined key is used within
  this new translation. In the example, `example.hello` refers to another translation.

- Text with Linked Translations and
  a [Modifier](https://github.com/aissat/easy_localization#formatting-linked-translations): For
  example, `"translation_key": "@:example.hello:capitalize User! How are you?"`. Here, a linked translation is used, and
  a modifier (in this case, `:capitalize`) is applied to the text.

## Adding an Entirely New Language 🆕

To add a new and currently unsupported translation, please follow these steps:

1. Clone the repository.
2. Make a copy of the `en.json` file and rename it in compliance with the BCP 47 (IETF language tag) standard.
3. Remove the sections `"languages" : {...` from the copied file, as this section should not be translated and should
   only be present in the `en.json` file.
4. Translate either all or some of the values in the new language file.
5. Add the new language to the [lib/main.dart](../lib/main.dart) file in the following section.

```dart
...return EasyLocalization(
supportedLocales: const [
Locale('af'),
Locale('de'),
Locale('en'),
Locale('fr'),
Locale('hu'),
Locale('it'),
Locale('nl'),
Locale('ro'),
Locale('ru'),
Locale('uk'),
Locale('zh', 'CN'),
Locale('zh', 'HK'),
],
...
```

6. Add yourself to the contributors list in this file.
7. Create a Pull Request (PR).

## Editing an Existing Language ✏️

To edit an existing language file, follow these steps:

1. Clone the repository.
2. Make your desired changes in the language file.
3. Add yourself to the contributors list in this file.
4. Create a Pull Request (PR).

## Thanks to All the Contributors 🙏

- 🇿🇦 Afrikaans, [@DMT07](https://github.com/DMT07)
- 🇭🇰 Chinese Hong Kong, [@old-cookie](https://github.com/old-cookie)
- 🇨🇳 Chinese Mainland, [@emo64](https://github.com/emo64), [@ptsa](https://github.com/ptsa)
- 🇳🇱 Dutch, [@JSMPI](https://github.com/JSMPI)
- 🇬🇧 English, [@Clon1998](https://github.com/Clon1998)
- 🇫🇷 French, [@Jothoreptile](https://github.com/Jothoreptile), Arnaud Petetin, [@dtourde](https://github.com/dtourde)
- 🇩🇪 German, [@Clon1998](https://github.com/Clon1998)
- 🇭🇺 Hungarian, [@AntoszHUN](https://github.com/AntoszHUN)
- 🇮🇹 Italian, [@Livex97](https://github.com/Livex97)
- 🇧🇷 Portuguese Brasil, [@opastorello](https://github.com/opastorello)
- 🇷🇴 Romanian, [@vaxxi](https://github.com/vaxxi)
- 🇷🇺 Russian, [@teuchezh](https://github.com/teuchezh)
- 🇹🇷 Turkish, [@larinspub ](https://github.com/larinspub)
- 🇺🇦 Ukrainian, [@iZonex](https://github.com/iZonex)

