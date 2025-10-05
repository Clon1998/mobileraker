/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/console/command.dart';
import 'package:common/data/dto/console/gcode_store_entry.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CommandSuggestions extends HookConsumerWidget {
  static List<String> additionalCmds = ['ABORT', 'ACCEPT', 'ADJUSTED', 'GET_POSITION', 'SET_RETRACTION', 'TESTZ'];

  const CommandSuggestions({super.key, required this.machineUUID, this.onSuggestionTap, required this.textNotifier, this.verticalLayout = false});

  final String machineUUID;
  final ValueChanged<String>? onSuggestionTap;
  final ValueNotifier<TextEditingValue> textNotifier;
  final bool verticalLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termValue = useValueListenable(textNotifier);
    final debouncedTermValue = useDebounced(termValue, const Duration(milliseconds: 100));

    final availableCommands = ref.watch(printerAvailableCommandsProvider(machineUUID)).value ?? [];
    final consoleEntries = ref.watch(printerGCodeStoreProvider(machineUUID)).value ?? [];

    final suggestedMacros = _calculateSuggestedMacros(
      debouncedTermValue?.text,
      consoleEntries.reversed,
      availableCommands,
    );

    final themeData = Theme.of(context);
    final enabled = onSuggestionTap != null;

    if (verticalLayout) {
      if (suggestedMacros.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SvgPicture.asset('assets/vector/undraw_void_-3-ggu.svg'),
                ),
              ),
              Text('pages.console.no_suggestions', style: themeData.textTheme.labelLarge).tr(),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            alignment: WrapAlignment.spaceEvenly,
            children: [...suggestedMacros.map((cmd) => _buildChip(cmd, themeData, enabled))],
          ),
        ),
      );
    }

    if (suggestedMacros.isEmpty) {
      return SizedBox(
        height: 33,
        child: Center(child: Text('pages.console.no_suggestions', style: themeData.textTheme.labelLarge).tr()),
      );
    }

    return SizedBox(
      height: 33,
      child: ChipTheme(
        data: ChipThemeData(
          labelStyle: TextStyle(color: themeData.colorScheme.onPrimary),
          deleteIconColor: themeData.colorScheme.onPrimary,
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          scrollDirection: Axis.horizontal,
          itemCount: suggestedMacros.length,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildChip(suggestedMacros.elementAt(index), themeData, enabled),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChip(String cmd, ThemeData themeData, bool enabled) {
    return ActionChip(
      label: Text(cmd),
      onPressed: enabled ? () => onSuggestionTap!(cmd) : null,
      backgroundColor: enabled ? themeData.colorScheme.primary : themeData.disabledColor,
      labelStyle: TextStyle(color: enabled ? themeData.colorScheme.onPrimary : themeData.disabledColor),
    );
  }

  /// This function calculates the suggested macros based on the user's input.
  /// It takes three parameters: `currentInput`, `history`, and `available`.
  /// The `currentInput` is the text entered by the user, `history` is a list of previously entered commands,
  /// and `available` is a list of available commands.
  ///
  /// The function first adds all the commands from the `history` to the `potential` list and `seen` set.
  /// Then it adds all the available commands that are not starting with an underscore and are not already in the `seen` set to the `potential` list.
  ///
  /// The function then calculates a score for each command in the `potential` list based on how well it matches the `currentInput`.
  /// The scoring system is as follows: an exact match gets a score of 100, a command that starts with the `currentInput` gets a score of 50,
  /// a command that contains the `currentInput` gets a score of 25, and a command that contains any term in the `currentInput` gets a score of 10.
  /// The score is then reduced by the Levenshtein distance between the command and the `currentInput`.
  ///
  /// Finally, the function returns the commands in the `potential` list sorted by their scores in descending order.

  List<String> _calculateSuggestedMacros(
    String? currentInput,
    Iterable<GCodeStoreEntry> history,
    List<Command> available,
  ) {
    Set<String> potential = {
      ...history.where((e) => e.type == ConsoleEntryType.command && !e.isInternal).take(10).map((e) => e.message),
      ...available.where((e) => !e.isInternal).map((e) => e.cmd),
      ...additionalCmds,
    };

    if (currentInput == null || currentInput.isEmpty) {
      return potential.toList();
    }

    String text = currentInput.toLowerCase();
    List<String> terms = text.split(RegExp(r'\W+'));

    // Create a map to score the suggestions
    Map<String, int> scoredSuggestions = {};

    for (var suggestion in potential) {
      int score = 0;
      String lowerSuggestion = suggestion.toLowerCase();

      // Exact match
      if (lowerSuggestion == text) {
        score += 100;
      }

      // Partial matches
      if (lowerSuggestion.startsWith(text)) {
        score += 50;
      } else if (lowerSuggestion.contains(text)) {
        score += 25;
      }

      // Check each term in the split input
      for (var term in terms) {
        if (lowerSuggestion.contains(term)) {
          score += 10;
        }
      }

      // Apply Levenshtein distance for additional similarity check
      int levenshteinScore = lowerSuggestion.levenshteinDistance(text);
      score -= levenshteinScore;

      // Assign score to the suggestion
      if (score > 0) {
        scoredSuggestions[suggestion] = score;
      }
    }

    // Sort by score descending and return the keys
    List<String> sortedSuggestions = scoredSuggestions.keys.toList().sorted(
      (a, b) => scoredSuggestions[b]!.compareTo(scoredSuggestions[a]!),
    );

    return sortedSuggestions;
  }
}
