/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:persistent_header_adaptive/persistent_header_adaptive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

class LogPage extends HookWidget {
  const LogPage({super.key, this.talkerTheme = const TalkerScreenTheme()});

  final TalkerScreenTheme talkerTheme;

  @override
  Widget build(BuildContext context) {
    var focusNode = useFocusNode();
    var textEditingController = useTextEditingController();
    var term = useListenable(textEditingController);
    var debouncedTerm = useDebounced(term.text, Duration(milliseconds: 200));

    var keyFilter = useState(<String?>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () async {
              var logDir = await logFileDirectory();
              var logFiles = logDir.listSync().map((e) => XFile(e.path, mimeType: 'text/plain')).toList();

              final box = context.findRenderObject() as RenderBox?;
              final pos = box!.localToGlobal(Offset.zero) & box.size;

              SharePlus.instance.share(
                ShareParams(files: logFiles, subject: 'Mobileraker Logs', sharePositionOrigin: pos),
              );
            },
          ),
        ],
      ),
      body: TalkerBuilder(
        talker: talker,
        builder: (context, data) {
          final filteredElements = _getFilteredLogs(debouncedTerm, keyFilter.value, data);
          final keys = data.map((e) => e.key).toList();
          final uniqKeys = keys.toSet().toList();

          final theme = Theme.of(context);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              AdaptiveHeightSliverPersistentHeader(
                floating: true,
                initialHeight: 140,
                needRepaint: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (var key in uniqKeys)
                          Builder(
                            builder: (context) {
                              final count = keys.where((e) => e == key).length;
                              final title = key != null ? talker.settings.getTitleByKey(key) : 'undefined';
                              return FilterChip(
                                label: Text('$count $title'),
                                selected: keyFilter.value.contains(key),
                                onSelected: (selected) {
                                  if (selected) {
                                    keyFilter.value = [...keyFilter.value, key];
                                  } else {
                                    keyFilter.value = keyFilter.value.where((element) => element != key).toList();
                                  }
                                },
                              );
                            },
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: textEditingController,
                        autofocus: true,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          fillColor: theme.colorScheme.primary,
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: theme.colorScheme.secondary),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: Icon(Icons.search, color: talkerTheme.textColor, size: 20),
                          hintText: 'Search…',
                          // hintStyle: themeData.textTheme.titleLarge?.copyWith(color: onBackground.withOpacity(0.4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverGap(8),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final data = filteredElements[filteredElements.length - 1 - i];

                  return TalkerDataCard(
                    data: data,
                    onCopyTap: () {
                      final text = data.generateTextMessage(timeFormat: talker.settings.timeFormat);
                      Clipboard.setData(ClipboardData(text: text));
                      HapticFeedback.lightImpact();
                    },
                    // expanded: _controller.expandedLogs,
                    expanded: true,
                    color: data.getFlutterColor(talkerTheme),
                  );
                }, childCount: filteredElements.length),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TalkerData> _getFilteredLogs(String? searchTerm, List<String?> keys, List<TalkerData> data) {
    final term = searchTerm?.toLowerCase().trim();
    return data.where((e) {
      return (keys.isEmpty || keys.contains(e.key)) &&
          (term?.isEmpty != false || e.generateTextMessage().toLowerCase().contains(term!));
    }).toList();
  }
}
