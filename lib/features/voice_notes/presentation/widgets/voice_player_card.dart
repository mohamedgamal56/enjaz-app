import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../domain/voice_note_service.dart';

class VoicePlayerCard extends ConsumerStatefulWidget {
  final VoiceNote voiceNote;

  const VoicePlayerCard({
    super.key,
    required this.voiceNote,
  });

  @override
  ConsumerState<VoicePlayerCard> createState() => _VoicePlayerCardState();
}

class _VoicePlayerCardState extends ConsumerState<VoicePlayerCard> {
  late final AudioPlayer _player;
  bool _fileExists = true;
  String? _absolutePath;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _resolveFile();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _resolveFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final fullPath = p.join(docs.path, widget.voiceNote.fileName);
    final exists = await File(fullPath).exists();

    if (!mounted) return;
    setState(() {
      _absolutePath = fullPath;
      _fileExists = exists;
    });

    if (exists) {
      try {
        await _player.setFilePath(fullPath);
      } catch (_) {
        setState(() => _fileExists = false);
      }
    }
  }

  void _toggleSpeed() {
    double nextSpeed = 1.0;
    if (_speed == 1.0) {
      nextSpeed = 1.5;
    } else if (_speed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    _player.setSpeed(nextSpeed);
    setState(() => _speed = nextSpeed);
  }

  Future<void> _showRenameDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: widget.voiceNote.label ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameVoiceNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.voiceNoteLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null) {
      final db = ref.read(databaseProvider);
      await db.updateVoiceNoteLabel(widget.voiceNote.id, result);
    }
  }

  Future<void> _deleteVoiceNote() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteVoiceNote),
        content: Text(l10n.deleteVoiceNoteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.deleteTask),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseProvider);
      await db.softDeleteVoiceNote(widget.voiceNote.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // If audio file is missing on disk (Spec 14.4)
    if (!_fileExists) {
      return Card(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.broken_image_outlined, color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.voiceFileMissing,
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                onPressed: _deleteVoiceNote,
              ),
            ],
          ),
        ),
      );
    }

    final displayTitle = (widget.voiceNote.label != null && widget.voiceNote.label!.isNotEmpty)
        ? widget.voiceNote.label!
        : '${l10n.voiceNotes} • ${VoiceNoteService.formatDuration(widget.voiceNote.durationMs)}';

    final sizeStr = VoiceNoteService.formatFileSize(widget.voiceNote.sizeBytes);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Title, Rename, Speed, Delete
            Row(
              children: [
                Icon(Icons.mic_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: l10n.renameVoiceNote,
                  visualDensity: VisualDensity.compact,
                  onPressed: _showRenameDialog,
                ),
                // Playback speed button (1x / 1.5x / 2x)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _toggleSpeed,
                  child: Text(
                    '${_speed}x',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  tooltip: l10n.deleteVoiceNote,
                  visualDensity: VisualDensity.compact,
                  onPressed: _deleteVoiceNote,
                ),
              ],
            ),

            // Middle Row: Play/Pause button + Seek Slider + Time/Size
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, stateSnapshot) {
                final state = stateSnapshot.data;
                final isPlaying = state?.playing ?? false;
                final processingState = state?.processingState;

                return StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, posSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final totalDuration = _player.duration ?? Duration(milliseconds: widget.voiceNote.durationMs);

                    final posMs = position.inMilliseconds;
                    final totalMs = totalDuration.inMilliseconds > 0
                        ? totalDuration.inMilliseconds
                        : (widget.voiceNote.durationMs > 0 ? widget.voiceNote.durationMs : 1);

                    return Column(
                      children: [
                        Row(
                          children: [
                            // Play / Pause Button
                            IconButton.filledTonal(
                              icon: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 24,
                              ),
                              onPressed: () {
                                if (isPlaying) {
                                  _player.pause();
                                } else {
                                  if (processingState == ProcessingState.completed) {
                                    _player.seek(Duration.zero);
                                  }
                                  _player.play();
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // Seek Slider
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: posMs.clamp(0, totalMs).toDouble(),
                                  max: totalMs.toDouble(),
                                  onChanged: (val) {
                                    _player.seek(Duration(milliseconds: val.toInt()));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Time progress & Size info row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${VoiceNoteService.formatDuration(posMs)} / ${VoiceNoteService.formatDuration(totalMs)}',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                              Text(
                                sizeStr,
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
