<!-- TOC -->

* [How to Translate Mobileraker 🌐](#how-to-translate-mobileraker-)
    * [Crowdin Translation Platform 🌍](#crowdin-translation-platform-)
        * [Steps to Contribute via Crowdin:](#steps-to-contribute-via-crowdin)
        * [Understanding Key Formats in Crowdin 🔑](#understanding-key-formats-in-crowdin-)
    * [Manual Translation Method (via GitHub) 📜](#manual-translation-method-via-github-)
        * [Translation Format](#translation-format)
            * [Language Files 🌍](#language-files-)
            * [Language Keys 🔑](#language-keys-)
        * [Adding an Entirely New Language 🆕](#adding-an-entirely-new-language-)
        * [Editing an Existing Language ✏️](#editing-an-existing-language-)
    * [Thanks to All the Contributors 🙏](#thanks-to-all-the-contributors-)
    * [Note on Translation Methods](#note-on-translation-methods)

<!-- TOC -->

[![Crowdin](https://badges.crowdin.net/mobileraker-app/localized.svg)](https://crowdin.com/project/mobileraker-app)

# How to Translate Mobileraker 🌐

Mobileraker supports multiple languages and relies on contributions to add new languages and keep existing translations
up to date. We now offer two methods for contributing translations: using the Crowdin platform or the manual method via
GitHub. This guide provides details on both approaches.

## Crowdin Translation Platform 🌍

We've moved our localization process to Crowdin, which makes it easier for contributors to add and update translations.

### Steps to Contribute via Crowdin:

1. Visit the Mobileraker Crowdin project: https://crowdin.com/project/mobileraker-app
2. Sign up for a Crowdin account if you don't have one.
3. Select the language you want to translate or update.
4. Start translating! You can suggest translations for untranslated strings or vote on existing translations.
5. Your contributions will be reviewed and, once approved, will be automatically incorporated into the project.

### Understanding Key Formats in Crowdin 🔑

When translating in Crowdin, you'll encounter various key formats. Here's how to interpret and work with them:

1. **Simple Keys**: These are straightforward text strings to translate.
   Example: `general.settings` might appear as "Settings" in English.

2. **Nested Keys**: These represent a hierarchy in the YAML structure. In Crowdin, they appear with dots separating each
   level.
   Example: `printer.state.printing` might represent "Printing" under the printer state section.

3. **Interpolation**: Keys with variables use curly braces `{}`. These should remain unchanged in your translation.
   Example: `printer.progress_message: "Printing {}, {progress}% complete"`
   Your translation should keep `{}` and `{progress}` intact.

4. **Linked Translations**: These use the `@:` syntax. In Crowdin, you'll see the full text to translate, but remember
   that part of it is linked to another translation.
   Example: `error.retry_message: "@:general.retry_button Attempt failed, please try again."`
   Here, `@:general.retry_button` will be replaced with the translation of the `general.retry_button` key.

When translating, ensure to maintain any special syntax (like `{}` for variables or `@:` for linked translations) in
your translated text. Crowdin's interface will help guide you through this process.

Using Crowdin is the preferred method for contributing translations as it provides a user-friendly interface and helps
maintain consistency across translations.

## Manual Translation Method (via GitHub) 📜

While we encourage using Crowdin, you can still contribute translations manually if you prefer. Here's how:

### Translation Format

#### Language Files 🌍

All available language files can be found in the `assets/translations` directory. Each file adheres to the BCP 47 (IETF
language tag) standard, consisting of a language code (e.g., 'en' for English, 'de' for German) and, if necessary, a
region or country code (e.g., 'zh-CN' for Chinese in mainland China, 'zh-HK' for Chinese in Hong Kong). These language
files are in the YAML format (`.yaml`) to ensure easy readability and editing.

#### Language Keys 🔑

Within each file, key-value pairs are used for translation. The value associated with each key can be either another
collection of key-value pairs or a string that contains the translation.

String values can take several forms:

- Simple Text: For example, `translation_key: "I am a text to translate."`

- Text with Arguments: For example, `translation_key: "I am a text to translate in language {}."`

- Text with [Linked Translations](https://github.com/aissat/easy_localization#-linked-translations): For
  example, `translation_key: "@:example.hello User! How are you?"`. This means an already defined key is used within
  this new translation. In the example, `example.hello` refers to another translation.

- Text with Linked Translations and
  a [Modifier](https://github.com/aissat/easy_localization#formatting-linked-translations): For
  example, `translation_key: "@:example.hello:capitalize User! How are you?"`. Here, a linked translation is used, and
  a modifier (in this case, `:capitalize`) is applied to the text.

### Adding an Entirely New Language 🆕

To add a new and currently unsupported translation manually:

1. Clone the repository.
2. Make a copy of the `en.yaml` file and rename it in compliance with the BCP 47 standard.
3. Remove the `languages:` section from the copied file, as this should only be present in the `en.yaml` file.
4. Translate either all or some of the values in the new language file.
5. Add the new language to the [lib/main.dart](../lib/main.dart) file in the `supportedLocales` section.
6. Add yourself to the contributors list in this file.
7. Create a Pull Request (PR).

### Editing an Existing Language ✏️

To edit an existing language file manually:

1. Clone the repository.
2. Make your desired changes in the language file.
3. Add yourself to the contributors list in this file.
4. Create a Pull Request (PR).

## Thanks to All the Contributors 🙏

- 🇿🇦 Afrikaans, [@DMT07](https://github.com/DMT07)
- 🇭🇰 Chinese Hong Kong, [@old-cookie](https://github.com/old-cookie)
- 🇨🇳 Chinese Mainland, [@emo64](https://github.com/emo64), [@ptsa](https://github.com/ptsa)
- 🇹🇼 Chinese Taiwan, Kayzed
- 🇳🇱 Dutch, [@JSMPI](https://github.com/JSMPI)
- 🇬🇧 English, [@Clon1998](https://github.com/Clon1998)
- 🇫🇷 French, [@Jothoreptile](https://github.com/Jothoreptile), Arnaud Petetin, [@dtourde](https://github.com/dtourde)
- 🇩🇪 German, [@Clon1998](https://github.com/Clon1998)
- 🇭🇺 Hungarian, [@AntoszHUN](https://github.com/AntoszHUN)
- 🇮🇹 Italian, [@Livex97](https://github.com/Livex97)
- 🇵🇱 Polish, solargrim
- 🇧🇷 Portuguese Brasil, [@opastorello](https://github.com/opastorello)
- 🇷🇴 Romanian, [@vaxxi](https://github.com/vaxxi)
- 🇷🇺 Russian, [@teuchezh](https://github.com/teuchezh)
- 🇹🇷 Turkish, [@larinspub ](https://github.com/larinspub)
- 🇺🇦 Ukrainian, [@iZonex](https://github.com/iZonex)

## Note on Translation Methods

While both methods (Crowdin and manual) are available, we encourage using Crowdin for a smoother translation process and
better consistency. However, we appreciate all contributions, regardless of the method used.

If you have any questions about the translation process, please feel free to open an issue on GitHub or reach out to the
project maintainers.