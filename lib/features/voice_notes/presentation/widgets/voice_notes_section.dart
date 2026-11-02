import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../voice_recorder_sheet.dart';
import 'voice_player_card.dart';

class VoiceNotesSection extends ConsumerWidget {
  final String parentType; // task | idea | goal
  final int parentId;

  const VoiceNotesSection({
    super.key,
    required this.parentType,
    required this.parentId,
  });

  Future<void> _recordNewVoiceNote(BuildContext context, WidgetRef ref) async {
    final result = await VoiceRecorderSheet.show(context);
    if (result != null) {
      final db = ref.read(databaseProvider);
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insertVoiceNote(
        VoiceNotesCompanion.insert(
          parentType: parentType,
          parentId: parentId,
          fileName: result.relativeFileName,
          durationMs: drift.Value(result.durationMs),
          sizeBytes: drift.Value(result.sizeBytes),
          recordedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.recordingSaved)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<VoiceNote>>(
      stream: db.watchVoiceNotes(parentType, parentId),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? [];

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mic_none_rounded, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          l10n.voiceNotes,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${notes.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.addVoiceNote),
                      onPressed: () => _recordNewVoiceNote(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: Text(
                        l10n.noIdeasYet,
                        style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notes.length,
                    itemBuilder: (ctx, index) {
                      return VoicePlayerCard(voiceNote: notes[index]);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
