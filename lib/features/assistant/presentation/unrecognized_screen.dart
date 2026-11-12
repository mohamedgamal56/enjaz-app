import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/app_database.dart';
import '../../../l10n/app_localizations.dart';

class UnrecognizedScreen extends ConsumerWidget {
  const UnrecognizedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.assistantUnrecognizedTitle ?? (isAr ? 'الجمل غير المفهومة' : 'Unrecognized Phrases')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n?.assistantClearUnrecognized ?? (isAr ? 'مسح السجل' : 'Clear History'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(l10n?.assistantClearUnrecognizedConfirmTitle ?? (isAr ? 'مسح الجمل المحفوظة؟' : 'Clear saved phrases?')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l10n?.assistantCancel ?? (isAr ? 'إلغاء' : 'Cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l10n?.assistantClearConfirm ?? (isAr ? 'مسح' : 'Clear')),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await db.delete(db.unrecognizedPhrases).go();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<UnrecognizedPhrase>>(
        stream: db.select(db.unrecognizedPhrases).watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(l10n?.assistantNoUnrecognized ?? (isAr ? 'لا توجد جمل محفوظة' : 'No saved phrases')),
            );
          }
          return ListView(
            children: items.reversed
                .map((item) => ListTile(
                      title: Text(item.phrase),
                      subtitle: Text(
                        DateTime.fromMillisecondsSinceEpoch(item.at).toLocal().toString(),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}
